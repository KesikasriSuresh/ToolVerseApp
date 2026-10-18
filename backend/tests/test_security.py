"""Negative tests. Each one used to SUCCEED against the previous backend; all must now be refused."""
import httpx
import pytest

from backend.app.core.config import settings
from backend.app.services import otp_service
from backend.tests.conftest import PNG


@pytest.mark.asyncio
async def test_unauthenticated_requests_rejected(client):
    for method, url in [("GET", "/api/items"), ("GET", "/api/users/x"), ("GET", "/api/bookings"),
                        ("GET", "/api/notifications"), ("POST", "/api/uploads/image")]:
        assert (await client.request(method, url)).status_code == 401, url


@pytest.mark.asyncio
async def test_token_for_unknown_user_does_not_create_account(client):
    from backend.app.core.security import create_access_token
    ghost = create_access_token("usr_ghost")
    assert (await client.get("/api/auth/me", headers={"Authorization": f"Bearer {ghost}"})).status_code == 401


@pytest.mark.asyncio
async def test_forged_or_tampered_token_rejected(client):
    assert (await client.get("/api/auth/me", headers={"Authorization": "Bearer abc.def.ghi"})).status_code == 401


@pytest.mark.asyncio
async def test_wrong_otp_is_locked_out_after_attempts(client):
    phone = "+919111111111"
    await client.post("/api/auth/otp/send", json={"phone": phone})
    codes = [(await client.post("/api/auth/otp/verify", json={"phone": phone, "otp": f"00000{i}"})).status_code for i in range(8)]
    assert codes[:5] == [400] * 5
    # even the CORRECT code no longer works once attempts are exhausted
    assert (await client.post("/api/auth/otp/verify", json={"phone": phone, "otp": "123456"})).status_code in (400, 429)


@pytest.mark.asyncio
async def test_otp_send_is_throttled(client):
    phone = "+919222222222"
    first = await client.post("/api/auth/otp/send", json={"phone": phone})
    second = await client.post("/api/auth/otp/send", json={"phone": phone})
    assert first.status_code == 200 and second.status_code == 429


@pytest.mark.asyncio
async def test_bad_phone_numbers_rejected(client):
    for bad in ["abc", "+0123456789", "123", "+" + "9" * 20]:
        assert (await client.post("/api/auth/otp/send", json={"phone": bad})).status_code == 400, bad


@pytest.mark.asyncio
async def test_dev_code_never_returned_in_production_like_env(client, monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    r = await client.post("/api/auth/otp/send", json={"phone": "+919333333333"})
    assert r.json()["dev_code"] is None


def test_production_refuses_dev_otp_and_wildcard_cors(monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    with pytest.raises(RuntimeError) as e:
        settings.validate_for_startup()
    msg = str(e.value)
    assert "SMS_PROVIDER=dev" in msg and "CORS_ORIGINS" in msg


def test_missing_or_short_jwt_secret_refuses_startup(monkeypatch):
    monkeypatch.setattr(settings, "JWT_SECRET_KEY", "short")
    with pytest.raises(RuntimeError):
        settings.validate_for_startup()


@pytest.mark.asyncio
async def test_stranger_cannot_read_or_write_chat(client, make_user, booking_setup):
    _, _, _, booking = booking_setup
    stranger = await make_user()
    assert (await client.get(f"/api/chats/{booking['id']}", headers=stranger.h)).status_code == 403
    assert (await client.post(f"/api/chats/{booking['id']}", json={"text": "hi"}, headers=stranger.h)).status_code == 403


@pytest.mark.asyncio
async def test_stranger_cannot_touch_booking(client, make_user, booking_setup):
    _, _, _, booking = booking_setup
    s, bid = await make_user(), booking["id"]
    assert (await client.get(f"/api/bookings/{bid}", headers=s.h)).status_code == 403
    assert (await client.patch(f"/api/bookings/{bid}/status", json={"status": "active"}, headers=s.h)).status_code == 403
    assert (await client.patch(f"/api/bookings/{bid}/photos", json={"before": True}, headers=s.h)).status_code == 403
    assert (await client.post(f"/api/bookings/{bid}/ai-check", headers=s.h)).status_code == 403
    assert (await client.get("/api/bookings", headers=s.h)).json() == []


@pytest.mark.asyncio
async def test_status_machine_enforced(client, booking_setup):
    _, borrower, _, booking = booking_setup
    url = f"/api/bookings/{booking['id']}/status"
    assert (await client.patch(url, json={"status": "banana"}, headers=borrower.h)).status_code == 422
    assert (await client.patch(url, json={"status": "done"}, headers=borrower.h)).status_code == 409   # can't skip active
    assert (await client.patch(url, json={"status": "active"}, headers=borrower.h)).status_code == 200
    assert (await client.patch(url, json={"status": "active"}, headers=borrower.h)).status_code == 409   # no repeats
    assert (await client.post(f"/api/bookings/{booking['id']}/ai-check", headers=borrower.h)).status_code == 400


@pytest.mark.asyncio
async def test_ai_check_requires_active_booking(client, booking_setup):
    _, borrower, _, booking = booking_setup
    await client.patch(f"/api/bookings/{booking['id']}/photos", json={"before": True, "after": True}, headers=borrower.h)
    assert (await client.post(f"/api/bookings/{booking['id']}/ai-check", headers=borrower.h)).status_code == 409


@pytest.mark.asyncio
async def test_booking_ignores_client_supplied_price_and_owner(client, make_user):
    lender, borrower = await make_user("Real Owner"), await make_user()
    item = (await client.post("/api/items", json={"name": "Drill", "category": "tools", "deposit": 1000}, headers=lender.h)).json()
    b = (await client.post("/api/bookings", json={"itemId": item["id"], "itemDeposit": 0, "itemOwner": "Fake",
                                                  "lenderId": borrower.uid}, headers=borrower.h)).json()
    assert b["itemDeposit"] == 1000 and b["itemOwner"] == "Real Owner" and b["lenderId"] == lender.uid


@pytest.mark.asyncio
async def test_booking_validation_rules(client, make_user):
    lender, borrower = await make_user(), await make_user()
    item = (await client.post("/api/items", json={"name": "Drill", "category": "tools"}, headers=lender.h)).json()
    bad = await client.post("/api/bookings", json={"itemId": item["id"], "from": "2026-12-10T10:00:00Z", "to": "2026-01-01T10:00:00Z"}, headers=borrower.h)
    assert bad.status_code == 422
    assert (await client.post("/api/bookings", json={"itemId": item["id"]}, headers=lender.h)).status_code == 400  # own item
    assert (await client.post("/api/bookings", json={"itemId": "nope"}, headers=borrower.h)).status_code == 404
    assert (await client.post("/api/bookings", json={"itemId": item["id"]}, headers=borrower.h)).status_code == 201
    assert (await client.post("/api/bookings", json={"itemId": item["id"]}, headers=borrower.h)).status_code == 409  # duplicate
    off = (await client.post("/api/items", json={"name": "Saw", "category": "tools", "isAvailable": False}, headers=lender.h)).json()
    assert (await client.post("/api/bookings", json={"itemId": off["id"]}, headers=borrower.h)).status_code == 409


@pytest.mark.asyncio
async def test_cannot_edit_or_delete_others_items(client, make_user):
    a, b = await make_user(), await make_user()
    item = (await client.post("/api/items", json={"name": "Drill", "category": "tools"}, headers=a.h)).json()
    assert (await client.put(f"/api/items/{item['id']}", json={"name": "Hacked"}, headers=b.h)).status_code == 403
    assert (await client.delete(f"/api/items/{item['id']}", headers=b.h)).status_code == 403
    assert (await client.put(f"/api/items/{item['id']}", json={"name": "Renamed"}, headers=a.h)).json()["name"] == "Renamed"


@pytest.mark.asyncio
async def test_item_input_validation(client, make_user):
    u = await make_user()
    assert (await client.post("/api/items", json={"name": "Xx", "category": "<script>"}, headers=u.h)).status_code == 422
    assert (await client.post("/api/items", json={"name": "Drill", "category": "tools", "deposit": -5}, headers=u.h)).status_code == 422
    # client cannot claim to be someone else
    item = (await client.post("/api/items", json={"name": "Drill", "category": "tools", "ownerId": "victim", "owner": "Victim"}, headers=u.h)).json()
    assert item["ownerId"] == u.uid


@pytest.mark.asyncio
async def test_cannot_attach_foreign_or_external_image(client, make_user):
    a, b = await make_user(), await make_user()
    up = (await client.post("/api/uploads/image", files={"file": ("a.png", PNG, "image/png")}, headers=a.h)).json()
    mine = {"name": "Drill", "category": "tools"}
    assert (await client.post("/api/items", json={**mine, "imageUrl": up["url"]}, headers=b.h)).status_code == 400   # A's image
    assert (await client.post("/api/items", json={**mine, "imageUrl": "https://evil.example/x.png"}, headers=b.h)).status_code == 400
    assert (await client.post("/api/items", json={**mine, "imageUrl": up["url"]}, headers=a.h)).status_code == 201


@pytest.mark.asyncio
async def test_cannot_delete_others_image(client, make_user, fake_cloudinary):
    a, b = await make_user(), await make_user()
    up = (await client.post("/api/uploads/image", files={"file": ("a.png", PNG, "image/png")}, headers=a.h)).json()
    assert (await client.delete("/api/uploads/image", params={"public_id": up["public_id"]}, headers=b.h)).status_code == 404
    assert fake_cloudinary["destroyed"] == []
    assert (await client.delete("/api/uploads/image", params={"public_id": up["public_id"]}, headers=a.h)).status_code == 200
    assert fake_cloudinary["destroyed"] == [up["public_id"]]


@pytest.mark.asyncio
async def test_upload_rejects_non_images_even_if_named_jpg(client, make_user):
    u = await make_user()
    for name, data in [("evil.jpg", b"<html><script>alert(1)</script></html>"), ("e.png", b""), ("d.pdf", b"%PDF-1.4")]:
        r = await client.post("/api/uploads/image", files={"file": (name, data, "image/jpeg")}, headers=u.h)
        assert r.status_code == 400, name
    big = b"\x89PNG\r\n\x1a\n" + b"0" * (settings.MAX_UPLOAD_BYTES + 10)
    assert (await client.post("/api/uploads/image", files={"file": ("big.png", big, "image/png")}, headers=u.h)).status_code == 413
    assert (await client.post("/api/uploads/image?category=../etc", files={"file": ("a.png", PNG, "image/png")}, headers=u.h)).status_code == 422


@pytest.mark.asyncio
async def test_upload_without_cloudinary_is_503_not_fake_success(client, make_user, monkeypatch):
    u = await make_user()
    monkeypatch.setattr(settings, "CLOUDINARY_API_SECRET", "")
    r = await client.post("/api/uploads/image", files={"file": ("a.png", PNG, "image/png")}, headers=u.h)
    assert r.status_code == 503


@pytest.mark.asyncio
async def test_phone_cannot_be_changed_via_profile(client, make_user):
    victim, attacker = await make_user(), await make_user()
    r = await client.put("/api/users/profile", json={"phone": victim.phone, "name": "Mallory"}, headers=attacker.h)
    assert r.status_code == 200 and r.json()["phone"] == attacker.phone


@pytest.mark.asyncio
async def test_other_users_see_only_public_profile(client, make_user):
    a, b = await make_user("Alice"), await make_user("Bob")
    await client.put("/api/users/profile", json={"email": "a@x.io", "latitude": 1.0, "longitude": 2.0}, headers=a.h)
    seen = (await client.get(f"/api/users/{a.uid}", headers=b.h)).json()
    assert set(seen) == {"uid", "name", "society", "profilePic"}
    assert "phone" in (await client.get(f"/api/users/{a.uid}", headers=a.h)).json()


@pytest.mark.asyncio
async def test_profile_picture_must_be_own_upload(client, make_user):
    a, b = await make_user(), await make_user()
    up = (await client.post("/api/uploads/image?category=profile_picture", files={"file": ("a.png", PNG, "image/png")}, headers=a.h)).json()
    assert (await client.put("/api/users/profile", json={"profilePic": up["url"]}, headers=b.h)).status_code == 400
    assert (await client.put("/api/users/profile", json={"profilePic": up["url"]}, headers=a.h)).status_code == 200


@pytest.mark.asyncio
async def test_no_endpoint_to_spoof_notifications(client, make_user):
    a, b = await make_user(), await make_user()
    r = await client.post("/api/notifications", json={"userId": b.uid, "title": "Security alert", "body": "x"}, headers=a.h)
    assert r.status_code == 405
    assert (await client.get("/api/notifications", headers=b.h)).json() == []


@pytest.mark.asyncio
async def test_cannot_mark_others_notifications_read(client, make_user, booking_setup):
    lender, borrower, _, booking = booking_setup
    nid = f"booking_request_{booking['id']}"
    assert (await client.patch(f"/api/notifications/{nid}/read", headers=borrower.h)).status_code == 404
    assert (await client.patch(f"/api/notifications/{nid}/read", headers=lender.h)).status_code == 200


@pytest.mark.asyncio
async def test_fcm_token_moves_between_accounts(client, make_user):
    from backend.app.db.mongodb import get_collection
    a, b = await make_user(), await make_user()
    await client.post("/api/users/fcm-token", json={"fcmToken": "device-1"}, headers=a.h)
    await client.post("/api/users/fcm-token", json={"fcmToken": "device-1"}, headers=b.h)  # same phone, new login
    assert (await get_collection("users").find_one({"uid": a.uid}))["fcmTokens"] == []
    assert (await get_collection("users").find_one({"uid": b.uid}))["fcmTokens"] == ["device-1"]


@pytest.mark.asyncio
async def test_guest_login_rate_limited_and_can_be_disabled(client, monkeypatch):
    codes = [(await client.post("/api/auth/anonymous")).status_code for _ in range(settings.ANON_MAX_PER_HOUR_PER_IP + 2)]
    assert codes[0] == 200 and codes[-1] == 429
    monkeypatch.setattr(settings, "ALLOW_ANONYMOUS_AUTH", False)
    assert (await client.post("/api/auth/anonymous")).status_code == 403


@pytest.mark.asyncio
async def test_system_chat_messages_can_be_disabled(client, booking_setup, monkeypatch):
    _, borrower, _, booking = booking_setup
    monkeypatch.setattr(settings, "ALLOW_CLIENT_SYSTEM_MESSAGES", False)
    r = await client.post(f"/api/chats/{booking['id']}", json={"text": "fake", "senderId": "system"}, headers=borrower.h)
    assert r.status_code == 403


# ---- Twilio Verify (HTTP mocked; proves our request/response handling, NOT live delivery) ----

def _twilio_client(handler):
    return lambda: httpx.AsyncClient(transport=httpx.MockTransport(handler))


@pytest.mark.asyncio
async def test_twilio_flow_and_no_dev_code_leak(client, monkeypatch):
    seen = []

    def handler(req: httpx.Request) -> httpx.Response:
        seen.append((req.url.path, req.content.decode()))
        if req.url.path.endswith("/Verifications"):
            return httpx.Response(201, json={"status": "pending"})
        approved = "Code=424242" in req.content.decode()
        return httpx.Response(200, json={"status": "approved" if approved else "pending"})

    monkeypatch.setattr(settings, "SMS_PROVIDER", "twilio_verify")
    for k in ("TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_VERIFY_SERVICE_SID"):
        monkeypatch.setattr(settings, k, "x" * 8 if k != "TWILIO_VERIFY_SERVICE_SID" else "VAtest")
    monkeypatch.setattr(otp_service, "_http_client", _twilio_client(handler))

    s = (await client.post("/api/auth/otp/send", json={"phone": "+919444444444"})).json()
    assert s["dev_code"] is None
    assert (await client.post("/api/auth/otp/verify", json={"phone": "+919444444444", "otp": "123456"})).status_code == 400
    ok = await client.post("/api/auth/otp/verify", json={"phone": "+919444444444", "otp": "424242"})
    assert ok.status_code == 200 and ok.json()["is_new_user"] is True
    assert any("VAtest/Verifications" in p for p, _ in seen)


@pytest.mark.asyncio
async def test_twilio_errors_map_to_safe_responses(client, monkeypatch):
    monkeypatch.setattr(settings, "SMS_PROVIDER", "twilio_verify")
    monkeypatch.setattr(otp_service, "_http_client", _twilio_client(lambda r: httpx.Response(400, json={"code": 60200, "message": "secret detail"})))
    r = await client.post("/api/auth/otp/send", json={"phone": "+919555555555"})
    assert r.status_code == 400 and "secret detail" not in r.text
    monkeypatch.setattr(otp_service, "_http_client", _twilio_client(lambda r: httpx.Response(404, json={})))
    assert (await client.post("/api/auth/otp/verify", json={"phone": "+919555555555", "otp": "123456"})).status_code == 400
