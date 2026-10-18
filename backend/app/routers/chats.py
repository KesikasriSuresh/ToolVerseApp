from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from backend.app.core.config import settings
from backend.app.core.dependencies import get_current_user
from backend.app.core.rate_limit import hit
from backend.app.db.mongodb import get_collection, serialize_doc
from backend.app.routers.bookings import load_booking_for_participant
from backend.app.schemas.chat import ChatMessageCreate, ChatMessageOut

router = APIRouter(prefix="/api/chats", tags=["Chat"])


def _out(doc: dict, uid: str) -> ChatMessageOut:
    data = serialize_doc(doc)
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
    await load_booking_for_participant(booking_id, uid)
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
    return _out(doc, uid)
