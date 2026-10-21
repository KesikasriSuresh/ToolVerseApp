"""Functional tests for the intended flows (dev OTP provider, mocked Cloudinary, mongomock)."""
import pytest

from backend.tests.conftest import PNG


@pytest.mark.asyncio
async def test_health_reports_real_state(client):
    r = await client.get("/api/health")
    assert r.status_code == 200 and r.json()["mongodb"] == "healthy"


@pytest.mark.asyncio
async def test_otp_login_and_profile(client):
    s = (await client.post("/api/auth/otp/send", json={"phone": "9876543210"})).json()
    assert s["phone"] == "+919876543210" and s["dev_code"] == "123456"
    v = (await client.post("/api/auth/otp/verify", json={"phone": "+919876543210", "otp": "123456"})).json()
    assert v["is_new_user"] is True and v["token_type"] == "bearer"
    me = (await client.get("/api/auth/me", headers={"Authorization": f"Bearer {v['access_token']}"})).json()
    assert me["phone"] == "+919876543210" and "fcmTokens" not in me


@pytest.mark.asyncio
async def test_email_otp_login_and_profile(client):
    s = (await client.post("/api/auth/otp/send", json={"email": "neighbor@toolverse.local"})).json()
    assert s["email"] == "neighbor@toolverse.local" and s["dev_code"] == "123456"
    v = (await client.post("/api/auth/otp/verify", json={"email": "neighbor@toolverse.local", "otp": "123456"})).json()
    assert v["is_new_user"] is True and v["token_type"] == "bearer"
    me = (await client.get("/api/auth/me", headers={"Authorization": f"Bearer {v['access_token']}"})).json()
    assert me["email"] == "neighbor@toolverse.local" and "fcmTokens" not in me


@pytest.mark.asyncio
async def test_returning_user_gets_same_account(client, make_user):
    from backend.app.db.mongodb import get_collection
    u = await make_user()
    await get_collection("rate_limits").delete_many({})  # a real user would just wait out the 30s resend cooldown
    await client.post("/api/auth/otp/send", json={"phone": u.phone})
    again = (await client.post("/api/auth/otp/verify", json={"phone": u.phone, "otp": "123456"})).json()
    assert again["uid"] == u.uid and again["is_new_user"] is False


@pytest.mark.asyncio
async def test_logout_revokes_token(client, make_user):
    u = await make_user()
    assert (await client.get("/api/auth/me", headers=u.h)).status_code == 200
    assert (await client.post("/api/auth/logout", headers=u.h)).status_code == 200
    assert (await client.get("/api/auth/me", headers=u.h)).status_code == 401


@pytest.mark.asyncio
async def test_image_upload_then_create_item_with_it(client, make_user):
    u = await make_user("Owner")
    up = await client.post("/api/uploads/image?category=item_photo", files={"file": ("a.png", PNG, "image/png")}, headers=u.h)
    assert up.status_code == 200
    img = up.json()
    assert img["public_id"].startswith(f"toolverse/items/{u.uid}/")
    item = await client.post("/api/items", json={"name": "Drill", "category": "tools", "desc": "x", "deposit": 100,
                                                 "imageUrl": img["url"]}, headers=u.h)
    assert item.status_code == 201
    body = item.json()
    assert body["cloudinaryPublicId"] == img["public_id"] and body["ownerId"] == u.uid and body["owner"] == "Owner"
    mine = (await client.get("/api/items/my", headers=u.h)).json()
    assert [i["id"] for i in mine] == [body["id"]]


@pytest.mark.asyncio
async def test_full_borrow_flow_two_accounts(client, booking_setup):
    lender, borrower, item, booking = booking_setup
    assert booking["status"] == "pending"
    assert booking["lenderId"] == lender.uid == item["ownerId"] and booking["borrowerId"] == borrower.uid
    assert booking["itemDeposit"] == 500 and booking["itemOwner"] == "Lena Lender"

    # Both perspectives see it, from the right side
    assert len((await client.get("/api/bookings?role=lender", headers=lender.h)).json()) == 1
    assert (await client.get("/api/bookings?role=lender", headers=borrower.h)).json() == []
    assert len((await client.get("/api/bookings?role=borrower", headers=borrower.h)).json()) == 1

    # Lender got the notification, with the id the Flutter app expects
    notes = (await client.get("/api/notifications", headers=lender.h)).json()
    assert f"booking_request_{booking['id']}" in [n["id"] for n in notes]

    r = await client.patch(f"/api/bookings/{booking['id']}/status", json={"status": "active"}, headers=borrower.h)
    assert r.status_code == 200 and r.json()["status"] == "active"
    # the other party is notified, the actor is not (the app already shows its own banner)
    assert any(n["title"].startswith("Handover") for n in (await client.get("/api/notifications", headers=lender.h)).json())
    assert not any(n["title"].startswith("Handover") for n in (await client.get("/api/notifications", headers=borrower.h)).json())

    await client.patch(f"/api/bookings/{booking['id']}/photos", json={"before": True}, headers=borrower.h)
    r = await client.post(f"/api/bookings/{booking['id']}/ai-check", headers=borrower.h)
    assert r.status_code == 400  # after-photo missing
    await client.patch(f"/api/bookings/{booking['id']}/photos", json={"after": True}, headers=borrower.h)
    r = await client.post(f"/api/bookings/{booking['id']}/ai-check", headers=borrower.h)
    assert r.status_code == 200 and r.json()["status"] == "done"
    final = (await client.get(f"/api/bookings/{booking['id']}", headers=lender.h)).json()
    assert final["status"] == "done"


@pytest.mark.asyncio
async def test_chat_between_participants(client, booking_setup):
    lender, borrower, _, booking = booking_setup
    bid = booking["id"]
    r = await client.post(f"/api/chats/{bid}", json={"text": "📍 Gate 2", "type": "location", "latitude": 12.96,
                                                     "longitude": 77.72, "locationAddress": "Gate 2"}, headers=borrower.h)
    assert r.status_code == 201 and r.json()["fromMe"] is True
    seen = (await client.get(f"/api/chats/{bid}", headers=lender.h)).json()
    assert len(seen) == 1 and seen[0]["fromMe"] is False and seen[0]["type"] == "location"
    # the demo client's canned replies are stored as "system", never as the caller
    s = await client.post(f"/api/chats/{bid}", json={"text": "Sounds good!", "senderId": "system"}, headers=borrower.h)
    assert s.json()["senderId"] == "system" and s.json()["fromMe"] is False
    # Lender received a chat notification for incoming message
    lender_notes = (await client.get("/api/notifications", headers=lender.h)).json()
    assert any(n["type"] == "chat" for n in lender_notes)


@pytest.mark.asyncio
async def test_item_search_is_literal_not_regex(client, make_user):
    u = await make_user()
    await client.post("/api/items", json={"name": "Drill (18V)", "category": "tools"}, headers=u.h)
    assert len((await client.get("/api/items", params={"query": "(18V)"}, headers=u.h)).json()) == 1
    assert (await client.get("/api/items", params={"query": "(a+)+$"}, headers=u.h)).status_code == 200


@pytest.mark.asyncio
async def test_google_login_profile_pic_persistence(client):
    pic_url = "https://lh3.googleusercontent.com/a/ACg8ocISampleAvatarUrl"
    # First login with Google
    r1 = await client.post("/api/auth/google", json={
        "email": "sarah.connor@gmail.com",
        "name": "Sarah Connor",
        "profilePic": pic_url,
    })
    assert r1.status_code == 200
    data1 = r1.json()
    assert data1["user"]["profilePic"] == pic_url

    headers = {"Authorization": f"Bearer {data1['access_token']}"}

    # Verify /api/users/profile returns picture
    prof = (await client.get("/api/users/profile", headers=headers)).json()
    assert prof["profilePic"] == pic_url

    # User completes address screen without sending profilePic (empty string)
    update_res = await client.put("/api/users/profile", json={
        "name": "Sarah Connor",
        "society": "Skynet Resistance",
        "profilePic": "",
    }, headers=headers)
    assert update_res.status_code == 200
    # Must NOT wipe existing profilePic
    assert update_res.json()["profilePic"] == pic_url

    # User logs out
    await client.post("/api/auth/logout", headers=headers)

    # User logs back in as the same user
    r2 = await client.post("/api/auth/google", json={
        "email": "sarah.connor@gmail.com",
        "name": "Sarah Connor",
        "profilePic": pic_url,
    })
    assert r2.status_code == 200
    data2 = r2.json()
    assert data2["uid"] == data1["uid"]
    assert data2["user"]["profilePic"] == pic_url

    # Check /api/users/{uid} as well
    h2 = {"Authorization": f"Bearer {data2['access_token']}"}
    u_get = (await client.get(f"/api/users/{data2['uid']}", headers=h2)).json()
    assert u_get["profilePic"] == pic_url
