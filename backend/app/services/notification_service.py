import logging
from datetime import datetime, timezone
from typing import Any, Optional

from pymongo.errors import DuplicateKeyError

from backend.app.db.mongodb import get_collection
from backend.app.services.push_service import send_push

logger = logging.getLogger("toolverse.notifications")


async def create_user_notification(
    user_id: str,
    title: str,
    body: str,
    notification_type: str = "booking",
    key: Optional[str] = None,
    data: Optional[dict[str, Any]] = None,
) -> Optional[str]:
    """Persist a notification in MongoDB and attempt an FCM push.

    `key` makes the notification idempotent per user and becomes its public id, so the
    Flutter app (which uses ids like `booking_created_<id>`) can de-duplicate it against
    the banner it already showed locally. Never raises: a failed notification must not
    fail the business action that triggered it."""
    if not user_id or user_id == "seed":  # demo catalogue items have no real owner
        return None
    now = datetime.now(timezone.utc)
    doc = {
        "userId": user_id,
        "title": title,
        "body": body,
        "type": notification_type,
        "isRead": False,
        "data": {k: str(v) for k, v in (data or {}).items()},
        "timestamp": now,
        "createdAt": now,
        "pushStatus": "pending",
    }
    if key:
        doc["key"] = key
    try:
        result = await get_collection("notifications").insert_one(doc)
    except DuplicateKeyError:
        return key
    except Exception as exc:
        logger.error("Could not store notification: %s", type(exc).__name__)
        return None

    public_id = key or str(result.inserted_id)
    try:
        status = await send_push(user_id, title, body, {**doc["data"], "type": notification_type, "notificationId": public_id})
        await get_collection("notifications").update_one({"_id": result.inserted_id}, {"$set": {"pushStatus": status}})
    except Exception as exc:
        logger.error("Push dispatch failed: %s", type(exc).__name__)
    return public_id
