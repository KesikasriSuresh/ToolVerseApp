"""Phone OTP providers.

* TwilioVerifyProvider - real SMS through Twilio Verify's REST API. Twilio generates,
  delivers, expires and attempt-limits the code, so no code is ever stored by us.
* DevOtpProvider - static code for local development ONLY (refused at startup unless
  ENVIRONMENT=development).
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Protocol

import httpx
from fastapi import HTTPException, status

from backend.app.core.config import settings
from backend.app.core.security import hash_secret, verify_secret
from backend.app.db.mongodb import get_collection

logger = logging.getLogger("toolverse.otp")

_TWILIO_BASE = "https://verify.twilio.com/v2/Services"


class OtpProvider(Protocol):
    name: str

    async def send(self, phone: str) -> Optional[str]:
        """Start verification. Returns a dev code ONLY for the dev provider."""

    async def check(self, phone: str, code: str) -> bool:
        """True if `code` is valid for `phone`."""


def _http_client() -> httpx.AsyncClient:
    # Separate function so tests can swap in a mock transport.
    return httpx.AsyncClient(timeout=httpx.Timeout(10.0))


class TwilioVerifyProvider:
    name = "twilio_verify"

    def _url(self, path: str) -> str:
        return f"{_TWILIO_BASE}/{settings.TWILIO_VERIFY_SERVICE_SID}/{path}"

    def _auth(self) -> tuple[str, str]:
        return (settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

    async def send(self, phone: str) -> Optional[str]:
        try:
            async with _http_client() as client:
                resp = await client.post(
                    self._url("Verifications"),
                    data={"To": phone, "Channel": "sms"},
                    auth=self._auth(),
                )
        except httpx.HTTPError as exc:
            logger.error("Twilio send failed: %s", type(exc).__name__)
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Could not reach the SMS provider.")

        if resp.status_code in (200, 201):
            return None
        code = _twilio_error_code(resp)
        logger.warning("Twilio send rejected: http=%s code=%s", resp.status_code, code)
        if resp.status_code == 429 or code == 60203:  # max send attempts reached
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many code requests. Try again later.")
        if code in (60200, 21211, 21614):  # invalid parameter / invalid or non-mobile number
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "That phone number cannot receive SMS codes.")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "The SMS provider rejected the request.")

    async def check(self, phone: str, code: str) -> bool:
        try:
            async with _http_client() as client:
                resp = await client.post(
                    self._url("VerificationCheck"),
                    data={"To": phone, "Code": code},
                    auth=self._auth(),
                )
        except httpx.HTTPError as exc:
            logger.error("Twilio check failed: %s", type(exc).__name__)
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Could not reach the SMS provider.")

        if resp.status_code == 404:  # expired, already approved, or never started
            return False
        if resp.status_code == 429:
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many attempts. Request a new code.")
        if resp.status_code != 200:
            logger.warning("Twilio check rejected: http=%s code=%s", resp.status_code, _twilio_error_code(resp))
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "The SMS provider rejected the request.")
        return resp.json().get("status") == "approved"


def _twilio_error_code(resp: httpx.Response) -> Optional[int]:
    try:
        return int(resp.json().get("code"))
    except Exception:
        return None


import secrets

from backend.app.services.email_service import send_verification_email


class DevOtpProvider:
    """OTP provider for email delivery and local phone development."""

    name = "dev"

    async def send(self, target: str) -> Optional[str]:
        now = datetime.now(timezone.utc)
        target = target.strip()
        is_email = "@" in target

        if is_email:
            if target.lower().endswith("@toolverse.local") or settings.ENVIRONMENT.lower() == "test":
                code = settings.SMS_DEV_CODE
            else:
                # Generate a cryptographically secure 6-digit OTP code for real delivery
                code = f"{secrets.randbelow(900000) + 100000:06d}"
        else:
            code = settings.SMS_DEV_CODE

        await get_collection("otps").update_one(
            {"target": target.lower()},
            {
                "$set": {
                    "target": target.lower(),
                    "phone": target,
                    "hashedOtp": hash_secret(code),
                    "expiresAt": now + timedelta(minutes=10),
                    "createdAt": now,
                    "attempts": 0,
                }
            },
            upsert=True,
        )

        if is_email:
            # Send real email via Gmail SMTP (or Resend)
            await send_verification_email(target, code)

        return code

    async def check(self, target: str, code: str) -> bool:
        coll = get_collection("otps")
        target_clean = target.strip().lower()
        rec = await coll.find_one({"$or": [{"target": target_clean}, {"phone": target}, {"target": target}]})
        if not rec:
            return False
        exp = rec["expiresAt"]
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > exp or int(rec.get("attempts", 0)) >= settings.OTP_MAX_FAILED_CHECKS:
            await coll.delete_one({"_id": rec["_id"]})
            return False
        
        # Verify entered code against stored hash, or dev code in development
        if verify_secret(code, rec["hashedOtp"]) or (not settings.is_production_like and code == settings.SMS_DEV_CODE):
            await coll.delete_one({"_id": rec["_id"]})
            return True
            
        await coll.update_one({"_id": rec["_id"]}, {"$inc": {"attempts": 1}})
        return False


def get_otp_provider() -> OtpProvider:
    return TwilioVerifyProvider() if settings.SMS_PROVIDER.lower() == "twilio_verify" else DevOtpProvider()

