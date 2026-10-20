import logging
from typing import Any, Optional

import certifi
from bson import ObjectId
from fastapi import HTTPException, status
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from backend.app.core.config import settings

logger = logging.getLogger("toolverse.db")


class MongoDB:
    client: Optional[AsyncIOMotorClient] = None
    db: Optional[AsyncIOMotorDatabase] = None


db_instance = MongoDB()


def serialize_doc(doc: Optional[dict[str, Any]]) -> Optional[dict[str, Any]]:
    """Turn a Mongo document into JSON-safe primitives (`_id` -> `id`)."""
    if doc is None:
        return None
    out = dict(doc)
    if "_id" in out:
        out["id"] = str(out.pop("_id"))
    for k, v in list(out.items()):
        if isinstance(v, ObjectId):
            out[k] = str(v)
    return out


def parse_object_id(raw: str, what: str = "Record") -> ObjectId:
    """Validate an id coming from a URL/body. Unknown formats are simply 'not found'."""
    if not isinstance(raw, str) or not ObjectId.is_valid(raw):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{what} not found.")
    return ObjectId(raw)


async def connect_to_mongo() -> None:
    """Connect to Atlas. Keeps Motor client active so it auto-reconnects once Atlas network access allows the IP."""
    client = AsyncIOMotorClient(
        settings.MONGODB_URI,
        tlsCAFile=certifi.where(),
        serverSelectionTimeoutMS=5000,
        tz_aware=True,  # so API datetimes carry a UTC offset and Flutter parses them correctly
    )
    db_instance.client = client
    db_instance.db = client[settings.MONGODB_DATABASE]

    try:
        await client.admin.command("ping")
        logger.info("Connected to MongoDB Atlas database '%s'.", settings.MONGODB_DATABASE)
        await _create_indexes()
    except Exception as exc:
        logger.warning(
            "MongoDB Atlas connection pending (%s). Whitelist your current IP in Atlas > Network Access. Motor will automatically connect.",
            type(exc).__name__,
        )


async def close_mongo_connection() -> None:
    if db_instance.client:
        db_instance.client.close()
        db_instance.client = None
        db_instance.db = None
        logger.info("MongoDB connection closed.")


async def _safe_index(coll, keys, **kwargs) -> None:
    try:
        await coll.create_index(keys, **kwargs)
    except Exception as exc:  # existing data may violate a new unique index; do not crash startup
        logger.error("Index %s on %s failed: %s", keys, coll.name, type(exc).__name__)


async def _create_indexes() -> None:
    db = db_instance.db
    if db is None:
        return

    await _safe_index(db.users, "uid", unique=True)
    # Verified identities: unique, but guests have empty values.
    await _safe_index(
        db.users, "phone", unique=True, partialFilterExpression={"phone": {"$gt": ""}}
    )
    await _safe_index(
        db.users, "email", unique=True, partialFilterExpression={"email": {"$gt": ""}}
    )

    await _safe_index(db.items, [("ownerId", 1), ("createdAt", -1)])
    await _safe_index(db.items, "category")
    await _safe_index(db.items, [("createdAt", -1)])

    await _safe_index(db.bookings, [("borrowerId", 1), ("createdAt", -1)])
    await _safe_index(db.bookings, [("lenderId", 1), ("createdAt", -1)])
    await _safe_index(db.bookings, [("itemId", 1), ("status", 1)])

    await _safe_index(db.chats, [("bookingId", 1), ("timestamp", 1)])

    await _safe_index(db.notifications, [("userId", 1), ("timestamp", -1)])
    await _safe_index(
        db.notifications,
        [("userId", 1), ("key", 1)],
        unique=True,
        partialFilterExpression={"key": {"$type": "string"}},
    )

    await _safe_index(db.uploads, "publicId", unique=True)
    await _safe_index(db.uploads, [("ownerId", 1), ("createdAt", -1)])

    await _safe_index(db.otps, "target", unique=True, partialFilterExpression={"target": {"$gt": ""}})
    await _safe_index(db.otps, "phone", unique=True, partialFilterExpression={"phone": {"$gt": ""}})
    await _safe_index(db.otps, "expiresAt", expireAfterSeconds=0)
    await _safe_index(db.rate_limits, "expiresAt", expireAfterSeconds=0)
    await _safe_index(db.rate_limits, "key", unique=True)
    logger.info("MongoDB indexes ensured.")


def get_database() -> AsyncIOMotorDatabase:
    if db_instance.db is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is not available.",
        )
    return db_instance.db


def get_collection(name: str):
    return get_database()[name]
