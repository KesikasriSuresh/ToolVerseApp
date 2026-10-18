"""Insert the app's original 12 demo catalogue items (owner id "seed").

Explicit and idempotent. The API no longer seeds data behind a public GET.
Run from the repository root:
    PYTHONPATH=. python -m backend.scripts.seed_demo_items --yes
"""
import asyncio
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from backend.app.db.mongodb import close_mongo_connection, connect_to_mongo, get_collection
from backend.app.core.config import settings

SEEDS = json.loads((Path(__file__).with_name("demo_items.json")).read_text(encoding="utf-8"))


async def main() -> None:
    if "--yes" not in sys.argv:
        print(f"Would insert up to {len(SEEDS)} demo items into '{settings.MONGODB_DATABASE}'. Re-run with --yes to proceed.")
        return
    await connect_to_mongo()
    items, added = get_collection("items"), 0
    now = datetime.now(timezone.utc)
    for s in SEEDS:
        if await items.find_one({"ownerId": "seed", "name": s["name"]}):
            continue
        await items.insert_one({**s, "ownerId": "seed", "isAvailable": True, "cloudinaryPublicId": None,
                                "createdAt": now, "updatedAt": now})
        added += 1
    print(f"Inserted {added} item(s); {len(SEEDS) - added} already present.")
    await close_mongo_connection()


if __name__ == "__main__":
    asyncio.run(main())
