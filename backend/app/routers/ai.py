"""
Backend AI inspection endpoint — receives base64 images from the Flutter app
and proxies the Gemini Vision call using the server-side GEMINI_API_KEY.
This avoids exposing the API key to the client.
"""

import base64
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from backend.app.core.dependencies import security
from backend.app.core.security import decode_access_token
from backend.app.db.mongodb import get_collection, serialize_doc
from backend.app.services.gemini_service import analyze_tool_condition_with_gemini
from fastapi.security import HTTPAuthorizationCredentials

router = APIRouter(prefix="/api/ai", tags=["AI"])
logger = logging.getLogger("toolverse.ai")


class InspectRequest(BaseModel):
    listingImageB64: str          # base64-encoded listing (before) photo
    returnImageB64: str           # base64-encoded return (after) photo
    listingMime: str = "image/jpeg"
    returnMime: str = "image/jpeg"
    toolName: str = "Tool"
    depositAmount: int = 0


@router.post("/inspect")
async def inspect_tool_condition(
    body: InspectRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
):
    """
    Accepts base64-encoded before/after images, calls Gemini Vision on the server
    using GEMINI_API_KEY from .env, and returns the inspection result.
    The client never sees the API key. Authentication is optional so guests/demo users can inspect.
    """
    # Optional auth tracking
    user = None
    if credentials:
        try:
            payload = decode_access_token(credentials.credentials)
            if payload:
                user = await get_collection("users").find_one({"uid": payload["sub"]})
        except Exception:
            pass
    try:
        listing_bytes = base64.b64decode(body.listingImageB64)
        return_bytes = base64.b64decode(body.returnImageB64)
    except Exception:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid base64 image data.")

    if len(listing_bytes) == 0 or len(return_bytes) == 0:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Image data must not be empty.")

    result = await analyze_tool_condition_with_gemini(
        listing_image_bytes=listing_bytes,
        return_image_bytes=return_bytes,
        tool_name=body.toolName,
        deposit_amount=body.depositAmount,
        listing_mime=body.listingMime,
        return_mime=body.returnMime,
    )

    if not result.get("success"):
        err_code = result.get("error", "GEMINI_ERROR")
        err_msg = result.get("message", "Gemini inspection failed.")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"{err_code}: {err_msg}")

    return result
