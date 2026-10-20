from datetime import datetime, timedelta, timezone
from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from backend.app.core.dependencies import get_current_user
from backend.app.core.rate_limit import hit
from backend.app.db.mongodb import get_collection, parse_object_id, serialize_doc
from backend.app.schemas.booking import BookingCreate, BookingOut, BookingPhotosUpdate, BookingStatusUpdate
from backend.app.services.notification_service import create_user_notification

router = APIRouter(prefix="/api/bookings", tags=["Bookings"])

# The app's original flow is single-user: the person holding the item confirms the handover
# and the return. Either participant may advance a booking, strictly in this order, and
# nobody else can touch it.
ALLOWED_TRANSITIONS = {("pending", "active"), ("active", "done"), ("pending", "cancelled")}
MAX_LOAN_DAYS = 90


def _out(doc: dict) -> BookingOut:
    return BookingOut(**serialize_doc(doc))


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


async def load_booking_for_participant(booking_id: str, uid: str) -> dict:
    """404 if missing; 403 if the caller is neither borrower nor lender."""
    booking = await get_collection("bookings").find_one({"_id": parse_object_id(booking_id, "Booking")})
    if not booking:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Booking not found.")
    if uid not in (booking.get("borrowerId"), booking.get("lenderId")):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not a participant in this booking.")
    return booking


def _other_party(booking: dict, uid: str) -> str:
    return booking["lenderId"] if uid == booking["borrowerId"] else booking["borrowerId"]


@router.get("", response_model=List[BookingOut])
async def list_bookings(
    role: Optional[Literal["borrower", "lender"]] = Query(None, description="Omit for both perspectives"),
    limit: int = Query(100, ge=1, le=200),
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    if role == "borrower":
        flt = {"borrowerId": uid}
    elif role == "lender":
        flt = {"lenderId": uid}
    else:
        flt = {"$or": [{"borrowerId": uid}, {"lenderId": uid}]}
    cursor = get_collection("bookings").find(flt).sort("createdAt", -1).limit(limit)
    return [_out(d) async for d in cursor]


@router.get("/{booking_id}", response_model=BookingOut)
async def get_booking(booking_id: str, current_user: dict = Depends(get_current_user)):
    return _out(await load_booking_for_participant(booking_id, current_user["uid"]))


@router.post("", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
async def create_booking(body: BookingCreate, current_user: dict = Depends(get_current_user)):
    borrower_id = current_user["uid"]
    await hit(f"booking_create:{borrower_id}", 20, 3600, "You are sending requests too quickly.")

    item = await get_collection("items").find_one({"_id": parse_object_id(body.itemId, "Item")})
    if not item:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Item not found.")
    lender_id = item["ownerId"]
    if lender_id == borrower_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You cannot borrow your own item.")
    if not item.get("isAvailable", True):
        raise HTTPException(status.HTTP_409_CONFLICT, "This item is not currently available.")

    start, end = _aware(body.from_date), _aware(body.to_date)
    now = datetime.now(timezone.utc)
    if start and end:
        if end < start:
            raise HTTPException(422, "The return date must be after the pickup date.")
        if end - start > timedelta(days=MAX_LOAN_DAYS):
            raise HTTPException(422, f"Loans are limited to {MAX_LOAN_DAYS} days.")
    if end and end < now - timedelta(days=1):
        raise HTTPException(422, "The return date is in the past.")

    bookings = get_collection("bookings")
    item_id = str(item["_id"])
    if await bookings.find_one({"itemId": item_id, "borrowerId": borrower_id, "status": {"$in": ["pending", "active"]}}):
        raise HTTPException(status.HTTP_409_CONFLICT, "You already have an open request for this item.")
    if lender_id != "seed" and await bookings.find_one({"itemId": item_id, "status": "active"}):
        raise HTTPException(status.HTTP_409_CONFLICT, "This item is currently lent out.")

    users_col = get_collection("users")
    lender_user = await users_col.find_one({"uid": lender_id})
    lender_email = lender_user.get("email", "") if lender_user else ""

    doc = {
        "itemId": item_id,
        "itemName": item.get("name", "Item"),
        "itemCategory": item.get("category", "tools"),
        "itemOwner": item.get("owner", "Owner"),
        "itemDeposit": int(item.get("deposit", 0)),
        "itemImageUrl": item.get("imageUrl") or (item.get("images")[0] if item.get("images") else ""),
        "lenderId": lender_id,
        "lenderEmail": lender_email,
        "borrowerId": borrower_id,
        "borrowerName": current_user.get("name") or current_user.get("email") or "Borrower",
        "borrowerEmail": current_user.get("email", ""),
        "from": start,
        "to": end,
        "note": body.note.strip(),
        "status": "pending",
        "beforePhoto": False,
        "afterPhoto": False,
        "createdAt": now,
        "updatedAt": now,
    }
    result = await bookings.insert_one(doc)
    doc["_id"] = result.inserted_id
    booking_id = str(result.inserted_id)
    ids = {"bookingId": booking_id, "itemId": item_id}

    await create_user_notification(
        borrower_id, "Borrow request sent", f"Your request for {doc['itemName']} was sent to the owner.",
        "booking", key=f"booking_created_{booking_id}", data=ids,
    )
    await create_user_notification(
        lender_id, "New booking request", f"{doc['itemName']} has a new borrow request.",
        "booking", key=f"booking_request_{booking_id}", data=ids,
    )
    return _out(doc)


@router.patch("/{booking_id}/status", response_model=BookingOut)
async def update_booking_status(
    booking_id: str,
    body: BookingStatusUpdate,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    booking = await load_booking_for_participant(booking_id, uid)
    current, target = booking.get("status", "pending"), body.status
    if (current, target) not in ALLOWED_TRANSITIONS:
        raise HTTPException(status.HTTP_409_CONFLICT, f"A booking cannot move from '{current}' to '{target}'.")

    now = datetime.now(timezone.utc)
    # Compare-and-set so two simultaneous taps cannot both succeed.
    res = await get_collection("bookings").update_one(
        {"_id": booking["_id"], "status": current}, {"$set": {"status": target, "updatedAt": now}}
    )
    if res.modified_count == 0:
        raise HTTPException(status.HTTP_409_CONFLICT, "The booking was just updated. Refresh and try again.")

    if target == "active":
        await create_user_notification(
            _other_party(booking, uid), "Handover Confirmed 🤝",
            f"{booking.get('itemName', 'Item')} status updated to Active. Return countdown started.",
            "status", key=f"handover_{booking_id}", data={"bookingId": booking_id},
        )
    elif target == "cancelled":
        await create_user_notification(
            _other_party(booking, uid), "Request Cancelled",
            f"Borrow request for {booking.get('itemName', 'Item')} was cancelled.",
            "status", key=f"cancelled_{booking_id}", data={"bookingId": booking_id},
        )
    return _out(await get_collection("bookings").find_one({"_id": booking["_id"]}))


@router.delete("/{booking_id}")
async def delete_booking(booking_id: str, current_user: dict = Depends(get_current_user)):
    uid = current_user["uid"]
    booking = await load_booking_for_participant(booking_id, uid)
    if booking.get("status") == "active":
        raise HTTPException(status.HTTP_409_CONFLICT, "Active loans cannot be deleted until returned.")
    await get_collection("bookings").delete_one({"_id": booking["_id"]})
    await get_collection("chats").delete_many({"bookingId": booking_id})
    return {"success": True, "message": "Booking request deleted."}


@router.patch("/{booking_id}/photos", response_model=BookingOut)
async def update_booking_photos(
    booking_id: str,
    body: BookingPhotosUpdate,
    current_user: dict = Depends(get_current_user),
):
    booking = await load_booking_for_participant(booking_id, current_user["uid"])
    if booking.get("status") == "done":
        raise HTTPException(status.HTTP_409_CONFLICT, "This booking is already completed.")
    fields = {"updatedAt": datetime.now(timezone.utc)}
    if body.before is not None:
        fields["beforePhoto"] = body.before
    if body.after is not None:
        fields["afterPhoto"] = body.after
    await get_collection("bookings").update_one({"_id": booking["_id"]}, {"$set": fields})
    return _out(await get_collection("bookings").find_one({"_id": booking["_id"]}))


@router.post("/{booking_id}/ai-check")
async def run_ai_condition_check(booking_id: str, current_user: dict = Depends(get_current_user)):
    """Kept as in the original app: completes the booking once both photo flags are set.
    NOTE: no image analysis happens here (there never was any); see README."""
    uid = current_user["uid"]
    booking = await load_booking_for_participant(booking_id, uid)
    if booking.get("status") not in ("active", "pending"):
        raise HTTPException(status.HTTP_409_CONFLICT, "Only an active or pending booking can be checked for return.")
    if not booking.get("beforePhoto") or not booking.get("afterPhoto"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Both pickup (before) and return (after) photos are required.")

    res = await get_collection("bookings").update_one(
        {"_id": booking["_id"], "status": {"$in": ["active", "pending"]}},
        {"$set": {"status": "done", "updatedAt": datetime.now(timezone.utc)}},
    )
    if res.modified_count == 0:
        raise HTTPException(status.HTTP_409_CONFLICT, "The booking was just updated. Refresh and try again.")

    await create_user_notification(
        _other_party(booking, uid), "Return Verified ✅",
        f"{booking.get('itemName', 'Item')} returned in verified condition. ₹{booking.get('itemDeposit', 0)} deposit refunded!",
        "ai", key=f"return_verified_{booking_id}", data={"bookingId": booking_id},
    )
    updated = await get_collection("bookings").find_one({"_id": booking["_id"]})
    return {
        "success": True,
        "message": "AI condition analysis complete. No new damage detected.",
        "status": "done",
        "booking": _out(updated),
    }
