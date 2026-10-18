"""Firebase Cloud Messaging sender (HTTP v1 via firebase-admin).

FCM stays the push transport; only the Firestore-triggered Cloud Function is replaced.
Disabled (and honest about it) until FIREBASE_CREDENTIALS_FILE points at a service-account JSON.
"""
import asyncio
import logging
from typing import Dict

from backend.app.core.config import settings
from backend.app.db.mongodb import get_collection

logger = logging.getLogger("toolverse.push")

_initialised = False
_warned = False


def _init() -> bool:
    global _initialised, _warned
    if _initialised:
        return True
    if not settings.FIREBASE_CREDENTIALS_FILE:
        if not _warned:
            logger.warning("FIREBASE_CREDENTIALS_FILE not set: push notifications are disabled (in-app notifications still work).")
            _warned = True
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(settings.FIREBASE_CREDENTIALS_FILE))
        _initialised = True
        return True
    except Exception as exc:
        if not _warned:
            logger.error("Firebase Admin init failed (%s). Push disabled.", type(exc).__name__)
            _warned = True
        return False


def _send_sync(tokens: list[str], title: str, body: str, data: Dict[str, str]) -> tuple[list[str], int]:
    """Returns (stale_tokens, success_count)."""
    from firebase_admin import messaging

    msg = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(channel_id="toolverse_notifications"),
        ),
        apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound="default"))),
    )
    resp = messaging.send_each_for_multicast(msg)
    stale = [
        tok
        for tok, r in zip(tokens, resp.responses)
        if not r.success and type(r.exception).__name__ in ("UnregisteredError", "SenderIdMismatchError")
    ]
    logger.info("FCM sent: %d ok, %d failed.", resp.success_count, resp.failure_count)
    return stale, resp.success_count


async def send_push(user_id: str, title: str, body: str, data: Dict[str, str]) -> str:
    """Returns pushStatus: sent | no_device_token | not_configured | failed."""
    if not _init():
        return "not_configured"
    users = get_collection("users")
    user = await users.find_one({"uid": user_id}) or {}
    tokens = [t for t in user.get("fcmTokens", []) if isinstance(t, str) and t]
    if not tokens:
        return "no_device_token"
    try:
        stale, ok = await asyncio.to_thread(_send_sync, tokens, title, body, data)
    except Exception as exc:
        logger.error("FCM send error: %s", type(exc).__name__)
        return "failed"
    if stale:
        await users.update_one({"uid": user_id}, {"$pull": {"fcmTokens": {"$in": stale}}})
    return "sent" if ok else "failed"
