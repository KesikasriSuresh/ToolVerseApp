import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pymongo.errors import DuplicateKeyError

from backend.app.core.config import settings
from backend.app.core.dependencies import get_current_user
from backend.app.core.rate_limit import hit
from backend.app.core.security import create_access_token
from backend.app.db.mongodb import get_collection, serialize_doc
from backend.app.schemas.user import (
    E164,
    _EMAIL,
    AnonymousAuthResponse,
    AuthResponse,
    GoogleAuthRequest,
    SendOtpRequest,
    SendOtpResponse,
    UserOut,
    VerifyOtpRequest,
    VerifyOtpResponse,
)
from backend.app.services.otp_service import get_otp_provider

logger = logging.getLogger("toolverse.auth")
router = APIRouter(prefix="/api/auth", tags=["Authentication"])


def sanitize_phone(raw: str) -> str:
    cleaned = "".join(c for c in raw if c.isdigit() or c == "+")
    if not cleaned.startswith("+"):
        cleaned = ("+91" + cleaned) if len(cleaned) == 10 else ("+" + cleaned)
    if not E164.match(cleaned):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number. Include the country code, e.g. +919876543210.",
        )
    return cleaned


def _client_ip(request: Request) -> str:
    # Deliberately ignores X-Forwarded-For (spoofable). Put a trusted proxy setting here if you deploy behind one.
    return request.client.host if request.client else "unknown"


def _new_user_doc(uid: str, phone: str = "", name: str = "", email: str = "") -> dict:
    now = datetime.now(timezone.utc)
    return {
        "uid": uid,
        "name": name,
        "society": "",
        "phone": phone,
        "email": email,
        "profilePic": "",
        "latitude": None,
        "longitude": None,
        "formattedAddress": "",
        "fcmTokens": [],
        "tokenVersion": 0,
        "createdAt": now,
        "updatedAt": now,
    }


def _auth_response(user: dict, is_new: bool) -> dict:
    token = create_access_token(subject=user["uid"], token_version=user.get("tokenVersion", 0))
    is_complete = bool(
        user.get("name")
        and len(str(user.get("name", "")).strip()) >= 2
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "uid": user["uid"],
        "is_new_user": is_new,
        "is_profile_complete": is_complete,
        "user": UserOut(**serialize_doc(user)),
    }


@router.post("/otp/send", response_model=SendOtpResponse)
async def send_otp(body: SendOtpRequest, request: Request):
    if not body.email and not body.phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either email or phone number is required.",
        )

    await hit(f"otp_send_ip:{_client_ip(request)}", 20, 3600)

    users = get_collection("users")

    if body.email:
        email = body.email.strip().lower()
        user = await users.find_one({"email": email})


        await hit(f"otp_send:{email}", settings.OTP_MAX_SENDS_PER_HOUR, 3600,
                  "Too many code requests for this email. Try again in an hour.")
        await hit(f"otp_cooldown:{email}", 1, 30, "Please wait 30 seconds before requesting another code.")

        provider = get_otp_provider()
        dev_code = await provider.send(email)
        logger.info("Verification code requested for email (provider=%s).", provider.name)
        return SendOtpResponse(
            success=True,
            message="Verification code sent to your email.",
            email=email,
            dev_code=dev_code if (provider.name == "dev" and not settings.is_production_like) else None,
        )
    else:
        phone = sanitize_phone(body.phone)
        digits_only = "".join(c for c in phone if c.isdigit())
        user = await users.find_one({
            "$or": [
                {"phone": phone},
                {"phone": {"$regex": f"{digits_only[-10:]}$"}}
            ]
        })


        await hit(f"otp_send:{phone}", settings.OTP_MAX_SENDS_PER_HOUR, 3600,
                  "Too many code requests for this number. Try again in an hour.")
        await hit(f"otp_cooldown:{phone}", 1, 30, "Please wait 30 seconds before requesting another code.")

        provider = get_otp_provider()
        dev_code = await provider.send(phone)
        logger.info("Verification code requested (provider=%s).", provider.name)  # never log phone or code
        return SendOtpResponse(
            success=True,
            message="Verification code sent.",
            phone=phone,
            dev_code=dev_code if (provider.name == "dev" and not settings.is_production_like) else None,
        )


@router.post("/otp/verify", response_model=VerifyOtpResponse)
async def verify_otp(body: VerifyOtpRequest, request: Request):
    if not body.email and not body.phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either email or phone number is required.",
        )

    await hit(f"otp_check_ip:{_client_ip(request)}", 60, 600)

    users = get_collection("users")

    if body.email:
        email = body.email.strip().lower()
        await hit(f"otp_check:{email}", settings.OTP_MAX_FAILED_CHECKS * 2, 600,
                  "Too many attempts. Request a new code.")

        if not await get_otp_provider().check(email, body.otp):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification code.",
            )

        user = await users.find_one({"email": email})
        is_new = False
        if not user:
            is_new = True
            doc = _new_user_doc(uid=str(uuid.uuid4()), email=email)
            await users.insert_one(doc)
            user = await users.find_one({"email": email})

        return _auth_response(user, is_new)
    else:
        phone = sanitize_phone(body.phone)
        # Our own cap on top of the provider's, counted per phone and per IP.
        await hit(f"otp_check:{phone}", settings.OTP_MAX_FAILED_CHECKS * 2, 600,
                  "Too many attempts. Request a new code.")

        if not await get_otp_provider().check(phone, body.otp):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification code.",
            )

        digits_only = "".join(c for c in phone if c.isdigit())
        user = await users.find_one({
            "$or": [
                {"phone": phone},
                {"phone": {"$regex": f"{digits_only[-10:]}$"}}
            ]
        })
        is_new = False
        if not user:
            is_new = True
            doc = _new_user_doc(uid=str(uuid.uuid4()), phone=phone)
            await users.insert_one(doc)
            user = await users.find_one({"phone": phone})

        return _auth_response(user, is_new)


@router.post("/google", response_model=AuthResponse)
async def google_login(body: GoogleAuthRequest, request: Request):
    """One-tap Google Sign-In endpoint. Authenticates user and links or creates profile."""
    await hit(f"google_login_ip:{_client_ip(request)}", 60, 3600)
    email = body.email.strip().lower()
    if not _EMAIL.match(email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid email provided by Google account.",
        )

    users = get_collection("users")
    user = await users.find_one({"email": email})
    is_new = False
    if not user:
        is_new = True
        doc = _new_user_doc(
            f"usr_{uuid.uuid4().hex[:16]}",
            email=email,
            name=body.name or "",
        )
        if body.profilePic:
            doc["profilePic"] = body.profilePic
        try:
            await users.insert_one(doc)
        except DuplicateKeyError:
            is_new = False
        user = await users.find_one({"email": email})
    else:
        # User already exists; enrich missing profile details or keep Google photo synced
        updates = {}
        if not user.get("name") and body.name:
            updates["name"] = body.name
        if body.profilePic:
            current_pic = user.get("profilePic", "")
            if not current_pic or "googleusercontent.com" in current_pic:
                updates["profilePic"] = body.profilePic
        if updates:
            updates["updatedAt"] = datetime.now(timezone.utc)
            await users.update_one({"_id": user["_id"]}, {"$set": updates})
            user = await users.find_one({"_id": user["_id"]})

    return _auth_response(user, is_new)



@router.post("/anonymous", response_model=AnonymousAuthResponse)
async def anonymous_login(request: Request):
    """Guest login (replaces Firebase signInAnonymously). Rate limited per IP."""
    if not settings.ALLOW_ANONYMOUS_AUTH:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Guest login is disabled.")
    await hit(f"anon:{_client_ip(request)}", settings.ANON_MAX_PER_HOUR_PER_IP, 3600,
              "Too many guest sessions from this network. Try again later.")
    users = get_collection("users")
    doc = _new_user_doc(f"anon_{uuid.uuid4().hex[:16]}", name="Neighbor")
    await users.insert_one(doc)
    return _auth_response(await users.find_one({"uid": doc["uid"]}), True)


@router.get("/me", response_model=UserOut)
async def get_my_profile(current_user: dict = Depends(get_current_user)):
    return UserOut(**current_user)


@router.post("/logout")
async def logout(current_user: dict = Depends(get_current_user)):
    """Revoke every token issued so far for this account."""
    await get_collection("users").update_one(
        {"uid": current_user["uid"]},
        {"$inc": {"tokenVersion": 1}, "$set": {"fcmTokens": []}},
    )
    return {"success": True}
