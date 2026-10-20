import re
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from backend.app.core.dependencies import get_current_user
from backend.app.core.rate_limit import hit
from backend.app.db.mongodb import get_collection, parse_object_id, serialize_doc
from backend.app.schemas.item import ItemCreate, ItemOut, ItemUpdate
from backend.app.services.cloudinary_service import delete_asset, resolve_owned_image
from backend.app.services.notification_service import create_user_notification

router = APIRouter(prefix="/api/items", tags=["Items"])


def _out(doc: dict) -> ItemOut:
    return ItemOut(**serialize_doc(doc))


async def _get_item_or_404(item_id: str) -> dict:
    item = await get_collection("items").find_one({"_id": parse_object_id(item_id, "Item")})
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Item not found.")
    return item


@router.get("", response_model=List[ItemOut])
async def list_items(
    category: Optional[str] = Query(None, max_length=30),
    query: Optional[str] = Query(None, max_length=60),
    owner_id: Optional[str] = Query(None, max_length=64),
    limit: int = Query(100, ge=1, le=200),
    skip: int = Query(0, ge=0, le=10_000),
    current_user: dict = Depends(get_current_user),
):
    flt: dict = {}
    if category and category.lower() != "all":
        flt["category"] = category.lower()
    if owner_id:
        flt["ownerId"] = owner_id
    if query:
        flt["name"] = {"$regex": re.escape(query), "$options": "i"}  # escaped: no regex injection / ReDoS
    cursor = get_collection("items").find(flt).sort("createdAt", -1).skip(skip).limit(limit)
    return [_out(d) async for d in cursor]


@router.get("/my", response_model=List[ItemOut])
async def list_my_items(current_user: dict = Depends(get_current_user)):
    cursor = get_collection("items").find({"ownerId": current_user["uid"]}).sort("createdAt", -1).limit(200)
    return [_out(d) async for d in cursor]


@router.get("/{item_id}", response_model=ItemOut)
async def get_item(item_id: str, current_user: dict = Depends(get_current_user)):
    return _out(await _get_item_or_404(item_id))


@router.post("", response_model=ItemOut, status_code=status.HTTP_201_CREATED)
async def create_item(data: ItemCreate, current_user: dict = Depends(get_current_user)):
    uid = current_user["uid"]
    await hit(f"item_create:{uid}", 30, 3600, "You are creating items too quickly.")

    doc = data.model_dump()
    upload = await resolve_owned_image(doc["imageUrl"], uid)
    now = datetime.now(timezone.utc)
    doc.update(
        ownerId=uid,
        owner=(current_user.get("name") or "").strip() or current_user.get("email") or "Neighbor",  # server-side, not client-supplied
        cloudinaryPublicId=upload["publicId"] if upload else None,
        createdAt=now,
        updatedAt=now,
    )
    result = await get_collection("items").insert_one(doc)
    doc["_id"] = result.inserted_id

    item_id = str(result.inserted_id)
    # Same deterministic key the old Cloud Function used, so the app de-duplicates it with its local banner.
    await create_user_notification(
        user_id=uid,
        title="Your item is listed",
        body=f"{doc['name']} is now available for neighbors to borrow.",
        notification_type="status",
        key=f"item_listed_{item_id}",
        data={"itemId": item_id},
    )
    return _out(doc)


@router.put("/{item_id}", response_model=ItemOut)
async def update_item(item_id: str, patch: ItemUpdate, current_user: dict = Depends(get_current_user)):
    existing = await _get_item_or_404(item_id)
    if existing["ownerId"] != current_user["uid"]:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You can only edit your own items.")

    fields = {k: v for k, v in patch.model_dump().items() if v is not None}
    old_public_id = None
    if "imageUrl" in fields:
        upload = await resolve_owned_image(fields["imageUrl"], current_user["uid"])
        fields["cloudinaryPublicId"] = upload["publicId"] if upload else None
        if existing.get("cloudinaryPublicId") and existing.get("cloudinaryPublicId") != fields["cloudinaryPublicId"]:
            old_public_id = existing["cloudinaryPublicId"]
    fields["updatedAt"] = datetime.now(timezone.utc)

    await get_collection("items").update_one({"_id": existing["_id"]}, {"$set": fields})
    if old_public_id:
        await delete_asset(old_public_id)
    return _out(await get_collection("items").find_one({"_id": existing["_id"]}))


@router.delete("/{item_id}")
async def delete_item(item_id: str, current_user: dict = Depends(get_current_user)):
    existing = await _get_item_or_404(item_id)
    if existing["ownerId"] != current_user["uid"]:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You can only delete your own items.")

    item_id_str = str(existing["_id"])
    await get_collection("items").delete_one({"_id": existing["_id"]})
    if existing.get("cloudinaryPublicId"):
        await delete_asset(existing["cloudinaryPublicId"])

    # Cascade clean any associated bookings & chats so orphaned loans don't persist
    bookings_col = get_collection("bookings")
    item_bookings = await bookings_col.find({"itemId": item_id_str}).to_list(100)
    booking_ids = [str(b["_id"]) for b in item_bookings]
    if booking_ids:
        await bookings_col.delete_many({"itemId": item_id_str})
        await get_collection("chats").delete_many({"bookingId": {"$in": booking_ids}})
    return {"success": True}
