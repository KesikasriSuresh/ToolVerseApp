# ToolVerse backend (FastAPI + MongoDB Atlas + Cloudinary)

All commands run from the **project root** (the folder that contains `backend/` and `lib/`).

## 1. Setup (macOS)
```bash
python3 -m venv backend/.venv
source backend/.venv/bin/activate
pip install -r backend/requirements.txt
cp backend/.env.example backend/.env        # then edit backend/.env (never commit it)
python3 -c "import secrets; print(secrets.token_urlsafe(64))"   # paste as JWT_SECRET_KEY
```
Required in `backend/.env`: `MONGODB_URI`, `JWT_SECRET_KEY` (>= 32 chars), `CLOUDINARY_*`.
The server **refuses to start** with a missing/short JWT secret, an unreachable Atlas, or (outside
`ENVIRONMENT=development`) the dev OTP provider or `CORS_ORIGINS=*`.

## 2. Verify the real services (do this first)
```bash
PYTHONPATH=. python -m backend.scripts.verify_live
```
Pings Atlas (write/read/delete round-trip), checks Cloudinary credentials and does a real upload+delete of a
1x1 image, looks up your Twilio Verify service (sends no SMS), loads Firebase credentials if configured.
Prints PASS/FAIL only, never secrets. Atlas fails? Add your current IP under Atlas > Network Access.

## 3. Run
```bash
PYTHONPATH=. uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
# docs (development only): http://localhost:8000/docs     health: http://localhost:8000/api/health
```
Optional demo catalogue (the app's original 12 items, owner `seed`): `PYTHONPATH=. python -m backend.scripts.seed_demo_items --yes`

## 4. Tests
```bash
PYTHONPATH=. pytest backend/tests -q
```
They use `mongomock` and a mocked Cloudinary/Twilio, never your real `.env`. They prove authorization rules and
request handling, **not** live delivery. Use `verify_live` and the manual flow below for that.

## 5. Phone OTP with Twilio Verify
Create a Verify Service in the Twilio Console, then set `SMS_PROVIDER=twilio_verify`, `TWILIO_ACCOUNT_SID`,
`TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`. Twilio trial accounts can only text numbers you have verified
in the console. Twilio generates, expires and attempt-limits codes; we add per-phone and per-IP throttling.
`SMS_PROVIDER=dev` (static code, returned in the API response) works only when `ENVIRONMENT=development`.

## 6. Push notifications (FCM stays; the Cloud Function is replaced)
Firebase Console > Project settings > Service accounts > Generate new private key. Save the JSON **outside git** and
set `FIREBASE_CREDENTIALS_FILE=/absolute/path/to/it.json`. Until then `/api/health` shows `push: not_configured`,
and notifications still appear in-app (stored in MongoDB). Push is only proven once a real device receives one.

## 7. Compass
Connect with the same `MONGODB_URI`; database `toolverse`; collections: `users`, `items`, `bookings`, `chats`,
`notifications`, `uploads` (ownership record of every Cloudinary image), `otps`, `rate_limits`.

## 8. Manual two-account test (lender = A, borrower = B)
1. Sign in as A (phone 1), add an item with a photo. Compass: `items` doc has `ownerId` = A, `cloudinaryPublicId` set.
2. Sign in as B (phone 2 / second device or simulator). Open A's item, request to borrow.
3. Compass: `bookings` doc has `lenderId` = A and `borrowerId` = B. A has a `booking_request_<id>` notification.
4. B confirms handover (status `active`), marks both photos, runs the return check (status `done`). A sees every change.
5. Chat from B; A sees it. Sign in as a third account C: C must get 403 on that booking and its chat.

## Known limits (by design, for now)
* The original app has no lender approve/reject step: either participant advances `pending -> active -> done`, in order.
  Participants only; strangers get 403.
* "AI condition check" never analysed images (before/after "photos" are just flags). It still completes the booking and
  reports a refund, exactly as the original app did. Nothing is refunded for real.
* `ALLOW_CLIENT_SYSTEM_MESSAGES=true` keeps the demo's canned "owner" replies; set `false` for a real deployment.
* Polling replaces Firestore streams (chat 3s, bookings 5s, items/notifications 6s).
