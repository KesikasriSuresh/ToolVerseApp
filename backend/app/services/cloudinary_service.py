import asyncio
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import cloudinary
import cloudinary.uploader
from fastapi import HTTPException, UploadFile, status

from backend.app.core.config import settings
from backend.app.db.mongodb import get_collection

logger = logging.getLogger("toolverse.cloudinary")

CHUNK = 64 * 1024


def configure_cloudinary() -> None:
    if settings.cloudinary_configured:
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
            secure=True,
        )
        logger.info("Cloudinary SDK configured.")
    else:
        logger.warning("Cloudinary is NOT configured: image uploads will return 503 until it is.")


def sniff_image_type(data: bytes) -> Optional[str]:
    """Identify the real format from magic bytes; the client-supplied name/type is not trusted."""
    if data[:3] == b"\xff\xd8\xff":
        return "jpg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    # HEIC/HEIF images from mobile (appear as .jpg but have ftyp header)
    if len(data) >= 12 and data[4:8] == b"ftyp":
        return "jpg"  # Cloudinary accepts HEIC and converts
    # Fallback: trust the file — Cloudinary will reject truly invalid files
    return "jpg"


async def _read_limited(file: UploadFile, limit: int) -> bytes:
    buf = bytearray()
    while True:
        chunk = await file.read(CHUNK)
        if not chunk:
            break
        buf.extend(chunk)
        if len(buf) > limit:
            raise HTTPException(
                413,
                f"Image exceeds the {limit // (1024 * 1024)} MB limit. Please choose a smaller photo.",
            )
    return bytes(buf)


async def upload_image_file(file: UploadFile, folder: str, user_id: str) -> Dict[str, Any]:
    if not settings.cloudinary_configured:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Image storage is not configured on the server.")

    content = await _read_limited(file, settings.MAX_UPLOAD_BYTES)
    if not content:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The uploaded image file is empty.")
    fmt = sniff_image_type(content)
    if fmt is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unsupported file. Please upload a JPG, PNG or WebP image.")

    public_id = f"toolverse/{folder}/{user_id}/{uuid.uuid4().hex}"
    try:
        result = await asyncio.to_thread(
            cloudinary.uploader.upload,
            content,
            public_id=public_id,
            resource_type="image",
            overwrite=False,
            allowed_formats=["jpg", "png", "webp"],
        )
    except Exception as exc:
        logger.error("Cloudinary upload failed: %s", type(exc).__name__)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Image upload failed. Please try again.")

    record = {
        "publicId": result.get("public_id", public_id),
        "url": result.get("secure_url") or result.get("url"),
        "ownerId": user_id,
        "folder": folder,
        "format": result.get("format", fmt),
        "bytes": result.get("bytes", len(content)),
        "width": result.get("width"),
        "height": result.get("height"),
        "createdAt": datetime.now(timezone.utc),
    }
    await get_collection("uploads").insert_one(dict(record))
    return {
        "url": record["url"],
        "public_id": record["publicId"],
        "format": record["format"],
        "bytes": record["bytes"],
    }


async def delete_asset(public_id: str) -> bool:
    """Best-effort delete of a Cloudinary asset plus its ownership record."""
    ok = False
    if settings.cloudinary_configured:
        try:
            res = await asyncio.to_thread(cloudinary.uploader.destroy, public_id, resource_type="image", invalidate=True)
            ok = res.get("result") in ("ok", "not found")
        except Exception as exc:
            logger.error("Cloudinary delete failed: %s", type(exc).__name__)
    if ok:
        await get_collection("uploads").delete_one({"publicId": public_id})
    return ok


async def resolve_owned_image(url: str, user_id: str) -> Optional[Dict[str, Any]]:
    """Return the upload record for `url` only if `user_id` uploaded it. Blocks attaching
    someone else's image (or an arbitrary external URL) to your own records."""
    if not url:
        return None
    rec = await get_collection("uploads").find_one({"url": url, "ownerId": user_id})
    if not rec:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Image must be uploaded through the app first (unknown or foreign image URL).",
        )
    return rec
