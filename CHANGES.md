# ToolVerse migration: stage 2 completion patch

Overlay these files onto your project (same relative paths). `backend/.env` is NOT included: keep yours,
but ROTATE the MongoDB password, Cloudinary secret and JWT secret first, and update it:
  - SMS_PROVIDER must be `dev` (was `mock`) or `twilio_verify`
  - JWT_SECRET_KEY must be >= 32 chars
  - add ENVIRONMENT=development (see backend/.env.example for the rest)
Delete old demo data written by the previous backend:  items where ownerId matches ^seed_\d+$ , then run the seed script.

Removed old file: backend/tests/test_api.py is replaced (new test_api.py + test_security.py).
Not changed: pubspec.yaml (Firebase packages intentionally still present until you verify on device).
