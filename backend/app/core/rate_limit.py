from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from pymongo import ReturnDocument

from backend.app.db.mongodb import get_collection


async def hit(key: str, limit: int, window_seconds: int, detail: str = "Too many requests. Please try again later.") -> int:
    """Count one event in a fixed window; raise 429 when over `limit`. Stored in Mongo so it
    works across processes. Returns the new count."""
    now = datetime.now(timezone.utc)
    bucket = int(now.timestamp()) // window_seconds
    doc = await get_collection("rate_limits").find_one_and_update(
        {"key": f"{key}:{bucket}"},
        {
            "$inc": {"count": 1},
            "$setOnInsert": {"expiresAt": now + timedelta(seconds=window_seconds * 2)},
        },
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    count = int(doc["count"])
    if count > limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=detail,
            headers={"Retry-After": str(window_seconds)},
        )
    return count
