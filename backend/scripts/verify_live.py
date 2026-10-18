"""Check the REAL external services, using your local backend/.env. Prints PASS/FAIL only; never prints secrets.

    cd <project root>
    PYTHONPATH=. backend/.venv/bin/python -m backend.scripts.verify_live

Checks: config sanity, MongoDB Atlas ping + write/read/delete round trip, Cloudinary ping +
upload + delete of a 1x1 test image, Twilio Verify service lookup (sends NO SMS), Firebase credentials load.
"""
import asyncio
import base64
import sys
import uuid
from datetime import datetime, timezone

from backend.app.core.config import settings

PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
)
results: list[tuple[str, bool, str]] = []


def redact(text: str) -> str:
    for secret in (settings.MONGODB_URI, settings.JWT_SECRET_KEY, settings.CLOUDINARY_API_SECRET,
                   settings.CLOUDINARY_API_KEY, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_ACCOUNT_SID):
        if secret:
            text = text.replace(secret, "***")
    return text


def record(name: str, ok: bool, detail: str = "") -> None:
    results.append((name, ok, redact(detail)))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" - {redact(detail)}" if detail else ""))


async def check_config() -> None:
    try:
        settings.validate_for_startup()
        record("Configuration", True, f"environment={settings.ENVIRONMENT}, otp={settings.SMS_PROVIDER}")
    except RuntimeError as e:
        record("Configuration", False, str(e).replace("\n", " "))


async def check_mongo() -> None:
    from backend.app.db.mongodb import close_mongo_connection, connect_to_mongo, get_collection
    try:
        await connect_to_mongo()
        coll = get_collection("_healthcheck")
        marker = uuid.uuid4().hex
        await coll.insert_one({"marker": marker, "at": datetime.now(timezone.utc)})
        found = await coll.find_one({"marker": marker})
        await coll.delete_one({"marker": marker})
        record("MongoDB Atlas ping + write/read/delete", bool(found), f"database={settings.MONGODB_DATABASE}")
        counts = {n: await get_collection(n).count_documents({}) for n in ("users", "items", "bookings")}
        print(f"       document counts: {counts}")
        await close_mongo_connection()
    except Exception as e:
        record("MongoDB Atlas", False, f"{type(e).__name__}: {e}")


async def check_cloudinary() -> None:
    if not settings.cloudinary_configured:
        return record("Cloudinary", False, "CLOUDINARY_* not set")
    import cloudinary, cloudinary.api, cloudinary.uploader
    from backend.app.services.cloudinary_service import configure_cloudinary
    configure_cloudinary()
    try:
        await asyncio.to_thread(cloudinary.api.ping)
        record("Cloudinary API credentials", True)
        pid = f"toolverse/_healthcheck/{uuid.uuid4().hex}"
        up = await asyncio.to_thread(cloudinary.uploader.upload, PNG_1X1, public_id=pid, resource_type="image")
        record("Cloudinary test upload", bool(up.get("secure_url")), "https URL returned" if up.get("secure_url") else "no URL")
        de = await asyncio.to_thread(cloudinary.uploader.destroy, pid, resource_type="image")
        record("Cloudinary test delete", de.get("result") == "ok", f"result={de.get('result')}")
    except Exception as e:
        record("Cloudinary", False, f"{type(e).__name__}: {e}")


async def check_twilio() -> None:
    if settings.SMS_PROVIDER.lower() != "twilio_verify":
        return print("[SKIP] Twilio Verify (SMS_PROVIDER is not twilio_verify)")
    import httpx
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.get(f"https://verify.twilio.com/v2/Services/{settings.TWILIO_VERIFY_SERVICE_SID}",
                            auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN))
        record("Twilio Verify service lookup (no SMS sent)", r.status_code == 200,
               f"http={r.status_code}" + (f", name={r.json().get('friendly_name')}" if r.status_code == 200 else ""))
    except Exception as e:
        record("Twilio Verify", False, type(e).__name__)


async def check_firebase() -> None:
    if not settings.FIREBASE_CREDENTIALS_FILE:
        return print("[SKIP] Firebase push (FIREBASE_CREDENTIALS_FILE not set; push stays disabled)")
    from backend.app.services import push_service
    record("Firebase Admin credentials load", push_service._init(), "push can be sent once a device has registered a token")


async def main() -> int:
    for step in (check_config, check_mongo, check_cloudinary, check_twilio, check_firebase):
        await step()
    failed = [n for n, ok, _ in results if not ok]
    print("\n" + ("ALL CHECKS PASSED" if not failed else f"{len(failed)} CHECK(S) FAILED: {', '.join(failed)}"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
