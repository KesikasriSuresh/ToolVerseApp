from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from backend.app.core.config import settings
from backend.app.core.dependencies import get_current_user
from backend.app.core.rate_limit import hit
from backend.app.db.mongodb import get_collection, serialize_doc
from backend.app.routers.bookings import _other_party, load_booking_for_participant
from backend.app.schemas.chat import ChatMessageCreate, ChatMessageOut
from backend.app.services.notification_service import create_user_notification

router = APIRouter(prefix="/api/chats", tags=["Chat"])


def _out(doc: dict, uid: str) -> ChatMessageOut:
    data = serialize_doc(doc) or {}
    data["fromMe"] = data.get("senderId") == uid
    return ChatMessageOut(**data)


@router.get("/{booking_id}", response_model=List[ChatMessageOut])
async def get_booking_chat_messages(
    booking_id: str,
    limit: int = Query(300, ge=1, le=500),
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    await load_booking_for_participant(booking_id, uid)  # 403 for strangers
    cursor = get_collection("chats").find({"bookingId": booking_id}).sort("timestamp", 1).limit(limit)
    return [_out(d, uid) async for d in cursor]


@router.post("/{booking_id}", response_model=ChatMessageOut, status_code=status.HTTP_201_CREATED)
async def post_chat_message(
    booking_id: str,
    body: ChatMessageCreate,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    booking = await load_booking_for_participant(booking_id, uid)
    await hit(f"chat:{uid}", 120, 600, "You are sending messages too quickly.")

    sender = uid
    if body.senderId == "system":
        if not settings.ALLOW_CLIENT_SYSTEM_MESSAGES:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "System messages cannot be posted by clients.")
        sender = "system"

    doc = {
        "bookingId": booking_id,
        "text": body.text.strip(),
        "senderId": sender,
        "type": body.type,
        "latitude": body.latitude,
        "longitude": body.longitude,
        "locationAddress": body.locationAddress,
        "timestamp": datetime.now(timezone.utc),
    }
    result = await get_collection("chats").insert_one(doc)
    doc["_id"] = result.inserted_id

    # Notify recipient about the incoming chat message
    recipient_id = _other_party(booking, uid)
    if recipient_id:
        if sender == "system":
            sender_name = "System"
        else:
            sender_name = (
                current_user.get("name")
                or (booking.get("borrowerName") if uid == booking.get("borrowerId") else booking.get("itemOwner"))
                or current_user.get("email")
                or "Someone"
            )
        item_name = booking.get("itemName") or "Item"

        if body.type == "location":
            msg_preview = f"📍 Pickup Location: {body.locationAddress}" if body.locationAddress else "📍 Shared pickup location"
        else:
            msg_preview = body.text.strip()
            if len(msg_preview) > 100:
                msg_preview = msg_preview[:97] + "..."

        await create_user_notification(
            user_id=recipient_id,
            title=f"Chat: {sender_name}",
            body=msg_preview or f"New message regarding {item_name}",
            notification_type="chat",
            key=f"chat_{result.inserted_id}",
            data={"bookingId": booking_id, "chatId": str(result.inserted_id)},
        )

    return _out(doc, uid)
