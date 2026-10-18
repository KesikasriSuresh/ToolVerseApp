from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from backend.app.core.dependencies import get_current_user
from backend.app.db.mongodb import get_collection, serialize_doc
from backend.app.schemas.notification import NotificationOut
from bson import ObjectId

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])
# Notifications are created only by the server (booking/item events). There is deliberately
# no "create notification" endpoint: it would let any user message any other user.


def _out(doc: dict) -> NotificationOut:
    data = serialize_doc(doc)
    data["id"] = doc.get("key") or data["id"]  # public id = deterministic key when present
    return NotificationOut(**data)


@router.get("", response_model=List[NotificationOut])
async def list_notifications(limit: int = Query(100, ge=1, le=200), current_user: dict = Depends(get_current_user)):
    cursor = get_collection("notifications").find({"userId": current_user["uid"]}).sort("timestamp", -1).limit(limit)
    return [_out(d) async for d in cursor]


# Declared before "/{notification_id}/read" for clarity; the paths cannot collide anyway.
@router.patch("/read-all")
async def mark_all_notifications_read(current_user: dict = Depends(get_current_user)):
    await get_collection("notifications").update_many(
        {"userId": current_user["uid"], "isRead": False}, {"$set": {"isRead": True}}
    )
    return {"success": True}


@router.patch("/{notification_id}/read")
async def mark_notification_read(notification_id: str, current_user: dict = Depends(get_current_user)):
    flt = {"userId": current_user["uid"]}  # scoped to the caller: cannot touch others' records
    flt["$or"] = [{"key": notification_id}] + ([{"_id": ObjectId(notification_id)}] if ObjectId.is_valid(notification_id) else [])
    res = await get_collection("notifications").update_one(flt, {"$set": {"isRead": True}})
    if res.matched_count == 0:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Notification not found.")
    return {"success": True}
