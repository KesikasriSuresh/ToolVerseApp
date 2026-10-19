"""
Seed demo items into MongoDB for ToolVerse.
Run from project root:  python backend/seed_demo_items.py
"""
import asyncio
from datetime import datetime, timezone
from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv

load_dotenv("backend/.env")

MONGO_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
DB_NAME   = os.getenv("MONGODB_DB_NAME", "toolverse")

DEMO_ITEMS = [
    {"name": "Bosch Cordless Drill 18V", "category": "tools", "owner": "Anand K.", "ownerId": "demo_seed",
     "desc": "Two lithium batteries, charger and a 32-piece bit set. Great for shelving, drywall, and furniture assembly.",
     "deposit": 500, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80"},
    {"name": "Epson Home Cinema Projector", "category": "electronics", "owner": "Meera S.", "ownerId": "demo_seed",
     "desc": "Full HD 1080p projector with 5m HDMI cable and tripod stand — perfect for movie nights.",
     "deposit": 1200, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=600&auto=format&fit=crop&q=80"},
    {"name": "Canon EOS DSLR + 50mm f/1.8", "category": "electronics", "owner": "Farhan I.", "ownerId": "demo_seed",
     "desc": "Crystal sharp portrait lens, extra battery, 64GB SD card. Ideal for events and photoshoots.",
     "deposit": 2000, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=600&auto=format&fit=crop&q=80"},
    {"name": "Full Cricket Kit & Match Bat", "category": "sports", "owner": "Vignesh R.", "ownerId": "demo_seed",
     "desc": "English willow bat, pads, gloves, thigh guard and helmet. Adult size.",
     "deposit": 300, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=600&auto=format&fit=crop&q=80"},
    {"name": "2-Person All-Weather Camping Tent", "category": "camping", "owner": "Priya D.", "ownerId": "demo_seed",
     "desc": "Waterproof 3000mm, instant pitch in under 4 minutes. Comes with stakes and carry bag.",
     "deposit": 700, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=600&auto=format&fit=crop&q=80"},
    {"name": "Premium Board Games Bundle", "category": "games", "owner": "Sanjana T.", "ownerId": "demo_seed",
     "desc": "Catan, Codenames, Ticket to Ride and Uno — perfect condition with all pieces.",
     "deposit": 150, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1610890716171-6b1bb98ffd09?w=600&auto=format&fit=crop&q=80"},
    {"name": "Karcher High-Pressure Washer", "category": "tools", "owner": "Rohit M.", "ownerId": "demo_seed",
     "desc": "120 Bar washer with foam nozzle. Great for car washes, balconies and tile cleaning.",
     "deposit": 600, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1581244277943-fe4a9c777189?w=600&auto=format&fit=crop&q=80"},
    {"name": "DJI Mini 4K Fly-More Drone", "category": "electronics", "owner": "Karan V.", "ownerId": "demo_seed",
     "desc": "Ultra-light 4K drone with 3 batteries, multi-charger hub and spare propellers.",
     "deposit": 2500, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1508614589041-895b88991e3e?w=600&auto=format&fit=crop&q=80"},
    {"name": "Trek Marlin 21-Speed Mountain Bike", "category": "sports", "owner": "Aditya S.", "ownerId": "demo_seed",
     "desc": "Front suspension, disc brakes, helmet and lock included. Fits 5ft 6in to 6ft 1in.",
     "deposit": 1000, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=600&auto=format&fit=crop&q=80"},
    {"name": "Aluminum Multi-Position Ladder 12ft", "category": "tools", "owner": "Dinesh P.", "ownerId": "demo_seed",
     "desc": "Converts into step, extension and scaffold. 150kg capacity with rubber grip feet.",
     "deposit": 350, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=600&auto=format&fit=crop&q=80"},
    {"name": "Foldable BBQ Grill Set", "category": "camping", "owner": "Sneha K.", "ownerId": "demo_seed",
     "desc": "Stainless steel charcoal grill with skewers, tongs and carry tote. Great for terraces.",
     "deposit": 450, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80"},
    {"name": "Yamaha Acoustic Guitar with Gig Bag", "category": "games", "owner": "Natasha B.", "ownerId": "demo_seed",
     "desc": "Steel string dreadnought with padded bag, digital tuner, capo and picks.",
     "deposit": 400, "isAvailable": True,
     "imageUrl": "https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=600&auto=format&fit=crop&q=80"},
]

async def seed():
    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DB_NAME]
    col = db["items"]

    # Only insert seeds that don't already exist (idempotent by name + ownerId=demo_seed)
    inserted = 0
    for item in DEMO_ITEMS:
        exists = await col.find_one({"name": item["name"], "ownerId": "demo_seed"})
        if not exists:
            now = datetime.now(timezone.utc)
            item["createdAt"] = now
            item["updatedAt"] = now
            await col.insert_one(item)
            inserted += 1
            print(f"  ✅ Inserted: {item['name']}")
        else:
            print(f"  ⏭  Already exists: {item['name']}")

    print(f"\nDone. Inserted {inserted} new demo items.")
    client.close()

if __name__ == "__main__":
    asyncio.run(seed())
