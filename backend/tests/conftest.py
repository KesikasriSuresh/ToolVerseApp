import itertools
import os

# Must run BEFORE the app imports settings: env vars beat backend/.env, so tests never touch real secrets.
os.environ.update(
    ENVIRONMENT="development",
    MONGODB_URI="mongodb://unused-in-tests",
    MONGODB_DATABASE="test_toolverse",
    JWT_SECRET_KEY="test-secret-test-secret-test-secret-0123456789",
    CLOUDINARY_CLOUD_NAME="testcloud",
    CLOUDINARY_API_KEY="k",
    CLOUDINARY_API_SECRET="s",
    SMS_PROVIDER="dev",
    SMS_DEV_CODE="123456",
    FIREBASE_CREDENTIALS_FILE="",
    ALLOW_CLIENT_SYSTEM_MESSAGES="true",
)

import cloudinary.uploader  # noqa: E402
import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from mongomock_motor import AsyncMongoMockClient  # noqa: E402

from backend.app.db.mongodb import db_instance  # noqa: E402
from backend.app.main import app  # noqa: E402

PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4"
    b"\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)
_phones = itertools.count(9000000000)


@pytest_asyncio.fixture(autouse=True)
async def mock_db():
    client = AsyncMongoMockClient(tz_aware=True)
    db_instance.client, db_instance.db = client, client["test_toolverse"]
    yield
    client.close()


@pytest.fixture(autouse=True)
def fake_cloudinary(monkeypatch):
    calls = {"destroyed": []}

    def upload(data, public_id=None, **kw):
        return {"public_id": public_id, "secure_url": f"https://res.cloudinary.com/testcloud/image/upload/{public_id}.png",
                "format": "png", "bytes": len(data), "width": 1, "height": 1}

    def destroy(public_id, **kw):
        calls["destroyed"].append(public_id)
        return {"result": "ok"}

    monkeypatch.setattr(cloudinary.uploader, "upload", upload)
    monkeypatch.setattr(cloudinary.uploader, "destroy", destroy)
    return calls


@pytest_asyncio.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac


class User:
    def __init__(self, uid, token, phone):
        self.uid, self.token, self.phone = uid, token, phone
        self.h = {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def make_user(client):
    async def _make(name="Test User") -> User:
        phone = f"+91{next(_phones)}"
        await client.post("/api/auth/otp/send", json={"phone": phone})
        r = (await client.post("/api/auth/otp/verify", json={"phone": phone, "otp": "123456"})).json()
        u = User(r["uid"], r["access_token"], phone)
        await client.put("/api/users/profile", json={"name": name}, headers=u.h)
        return u
    return _make


@pytest_asyncio.fixture
async def booking_setup(client, make_user):
    lender, borrower = await make_user("Lena Lender"), await make_user("Bo Borrower")
    item = (await client.post("/api/items", json={"name": "Tent", "category": "camping", "desc": "2p", "deposit": 500},
                              headers=lender.h)).json()
    booking = (await client.post("/api/bookings", json={"itemId": item["id"], "note": "weekend"}, headers=borrower.h)).json()
    return lender, borrower, item, booking
