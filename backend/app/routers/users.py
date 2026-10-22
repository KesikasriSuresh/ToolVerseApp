from datetime import datetime, timezone
from typing import Union

from fastapi import APIRouter, Depends, HTTPException, status

from backend.app.core.dependencies import get_current_user
from backend.app.db.mongodb import get_collection, serialize_doc
from backend.app.schemas.user import PublicUserOut, RegisterFcmTokenRequest, UserOut, UserProfileUpdate
from backend.app.services.cloudinary_service import delete_asset, resolve_owned_image

router = APIRouter(prefix="/api/users", tags=["Users"])

MAX_FCM_TOKENS = 10


@router.get("/profile", response_model=UserOut)
async def get_current_user_profile(current_user: dict = Depends(get_current_user)):
    return UserOut(**current_user)


@router.put("/profile", response_model=UserOut)
async def update_user_profile(
    update: UserProfileUpdate,
    current_user: dict = Depends(get_current_user),
):
    users = get_collection("users")
    uid = current_user["uid"]
    fields = {k: v for k, v in update.model_dump().items() if v is not None}

    old_pic_public_id = None
    if "profilePic" in fields:
        pic = (fields["profilePic"] or "").strip()
        if pic:
            # Only internal Cloudinary uploads require ownership check in uploads collection.
            # External photo URLs (Google Sign-In, preset avatars, etc.) are allowed directly.
            if "cloudinary.com" in pic:
                await resolve_owned_image(pic, uid)
            if pic != current_user.get("profilePic", ""):
                prev = await get_collection("uploads").find_one({"url": current_user.get("profilePic", ""), "ownerId": uid})
                old_pic_public_id = prev["publicId"] if prev else None
            fields["profilePic"] = pic
        else:
            # Prevent accidental wiping if an empty string is passed during profile setup
            fields.pop("profilePic", None)

    if "phone" in fields:
        phone_val = (fields["phone"] or "").strip()
        if phone_val:
            conflict = await users.find_one({"phone": phone_val, "uid": {"$ne": uid}})
            if conflict:
                if uid.startswith("anon_"):
                    # Migrate anonymous updates into existing verified account
                    fields.pop("phone", None)
                    fields["updatedAt"] = datetime.now(timezone.utc)
                    await users.update_one({"uid": conflict["uid"]}, {"$set": fields})
                    await users.delete_one({"uid": uid})
                    return UserOut(**serialize_doc(await users.find_one({"uid": conflict["uid"]})))
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "This phone number is already linked to another account.")
            fields["phone"] = phone_val
        else:
            fields.pop("phone", None)

    if "email" in fields:
        email_val = (fields["email"] or "").strip().lower()
        if email_val:
            conflict = await users.find_one({"email": email_val, "uid": {"$ne": uid}})
            if conflict:
                if uid.startswith("anon_"):
                    # Migrate anonymous updates into existing verified account
                    fields.pop("email", None)
                    fields["updatedAt"] = datetime.now(timezone.utc)
                    await users.update_one({"uid": conflict["uid"]}, {"$set": fields})
                    await users.delete_one({"uid": uid})
                    return UserOut(**serialize_doc(await users.find_one({"uid": conflict["uid"]})))
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "This email is already linked to another account.")
            fields["email"] = email_val
        else:
            fields.pop("email", None)

    fields["updatedAt"] = datetime.now(timezone.utc)
    await users.update_one({"uid": uid}, {"$set": fields})

    if old_pic_public_id:
        await delete_asset(old_pic_public_id)  # best effort; replaced avatars don't pile up
    return UserOut(**serialize_doc(await users.find_one({"uid": uid})))


@router.post("/fcm-token")
async def register_fcm_token(
    body: RegisterFcmTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    token = body.fcmToken.strip()
    if not token:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "FCM token cannot be empty.")
    users = get_collection("users")
    uid = current_user["uid"]
    # A device token belongs to one account at a time (shared phones, re-login).
    await users.update_many({"uid": {"$ne": uid}, "fcmTokens": token}, {"$pull": {"fcmTokens": token}})
    await users.update_one({"uid": uid}, {"$addToSet": {"fcmTokens": token}})
    tokens = (await users.find_one({"uid": uid})).get("fcmTokens", [])
    if len(tokens) > MAX_FCM_TOKENS:  # keep the newest
        await users.update_one({"uid": uid}, {"$set": {"fcmTokens": tokens[-MAX_FCM_TOKENS:]}})
    return {"success": True}


@router.delete("/fcm-token")
async def unregister_fcm_token(body: RegisterFcmTokenRequest, current_user: dict = Depends(get_current_user)):
    await get_collection("users").update_one(
        {"uid": current_user["uid"]}, {"$pull": {"fcmTokens": body.fcmToken.strip()}}
    )
    return {"success": True}


@router.get("/{uid}", response_model=Union[UserOut, PublicUserOut])
async def get_user_by_uid(uid: str, current_user: dict = Depends(get_current_user)):
    """Your own uid returns your full profile. Anyone else's returns the public subset only."""
    if uid == current_user["uid"]:
        return UserOut(**current_user)
    user = await get_collection("users").find_one({"uid": uid})
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found.")
    return PublicUserOut(**serialize_doc(user))


@router.delete("/me")
async def delete_my_account(current_user: dict = Depends(get_current_user)):
    """Permanently delete user account and cascade delete all their data:
    items, bookings, chats, notifications, and uploaded images."""
    uid = current_user["uid"]

    # 1. Clean up user's items and Cloudinary assets
    items = await get_collection("items").find({"ownerId": uid}).to_list(1000)
    for it in items:
        if it.get("cloudinaryPublicId"):
            await delete_asset(it["cloudinaryPublicId"])
    await get_collection("items").delete_many({"ownerId": uid})

    # 2. Clean up user's uploaded images
    uploads = await get_collection("uploads").find({"ownerId": uid}).to_list(1000)
    for up in uploads:
        if up.get("publicId"):
            await delete_asset(up["publicId"])
    await get_collection("uploads").delete_many({"ownerId": uid})

    # 3. Clean up bookings where user was borrower or lender
    user_bookings = await get_collection("bookings").find(
        {"$or": [{"borrowerId": uid}, {"lenderId": uid}]}
    ).to_list(1000)
    booking_ids = [str(b["_id"]) for b in user_bookings]
    await get_collection("bookings").delete_many(
        {"$or": [{"borrowerId": uid}, {"lenderId": uid}]}
    )

    # 4. Clean up chats
    if booking_ids:
        await get_collection("chats").delete_many(
            {"$or": [{"bookingId": {"$in": booking_ids}}, {"senderId": uid}]}
        )
    else:
        await get_collection("chats").delete_many({"senderId": uid})

    # 5. Clean up notifications
    await get_collection("notifications").delete_many({"userId": uid})

    # 6. Delete user profile record
    await get_collection("users").delete_one({"uid": uid})

    return {"success": True, "message": "Account and all associated data permanently deleted."}
