# ToolVerse

**A community-powered borrow & lend platform for tools, gadgets, and equipment.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![MongoDB Atlas](https://img.shields.io/badge/MongoDB_Atlas-Cloud_DB-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/atlas)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media_Storage-3448C5?logo=cloudinary&logoColor=white)](https://cloudinary.com)
[![Firebase FCM](https://img.shields.io/badge/Firebase-FCM_Push-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)

---

## Team Details

| Roll Number | Name | Department |
|---|---|---|
| **CB.SC.U4CSE24023** | Kesikasri Suresh | Computer Science & Engineering |
| **CB.SC.U4CSE24055** | V Shasmitha | Computer Science & Engineering |
| **CB.SC.U4CSE24068** | Battu Hasini | Computer Science & Engineering |

---

## 1. Project Overview & Problem Solved

People frequently purchase expensive tools, gadgets, and equipment (cordless drills, projectors, DSLR cameras, camping tents, high-pressure washers) that they only use once or twice a year. This leads to wasted money, idle household clutter, and unnecessary consumption. 

**ToolVerse** connects verified neighbors in apartment complexes, residential communities, and university campuses to discover, borrow, and lend idle items safely nearby. By combining **digital agreements**, **refundable security deposits**, **in-app real-time messaging**, and **AI-powered condition checks**, ToolVerse eliminates friction and trust issues when sharing high-value items.

---

## 2. System Architecture & Tech Stack

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client App                   │
│   (Mobile Android / iOS / Web PWA — Dart & Material 3) │
└──────────────┬─────────────────────────┬───────────────┘
               │ HTTP REST / JSON         │ Direct media upload
               ▼                         ▼
┌─────────────────────────────────┐   ┌───────────────────────┐
│        FastAPI REST API         │   │      Cloudinary       │
│  (Python 3.14 + Uvicorn Async)  │   │   (Image CDN & CDN)   │
└──────┬─────────────┬────────────┘   └───────────────────────┘
       │             │
       ▼             ▼
┌──────────────┐  ┌───────────────────────────────────────────┐
│MongoDB Atlas │  │ Google Gemini Vision / AI Condition Check │
│  (Cloud DB)  │  │ Firebase Cloud Messaging (Push Alerts)    │
└──────────────┘  └───────────────────────────────────────────┘
```

- **Frontend:** Flutter SDK (Dart), Material 3 Dark theme, Provider / ChangeNotifier state management, Google Fonts (Plus Jakarta Sans).
- **Backend:** FastAPI (Python), Motor (Async MongoDB driver), Pydantic v2 schemas.
- **Database:** MongoDB Atlas (collections: `users`, `items`, `bookings`, `chats`, `notifications`, `uploads`, `rate_limits`).
- **Media & Images:** Cloudinary Cloud Storage SDK with secure URL resolution.
- **Authentication:** Google Sign-In, Dev/Twilio SMS OTP verification, and JWT Bearer Tokens with token-version invalidation on logout.
- **Inspection & Vision:** Google Gemini API integration for tool damage detection and condition comparison.
- **Push Notifications:** Firebase Cloud Messaging (FCM) token synchronization.

---

## 3. Core Features Implemented

| # | Blueprint Feature | Implementation & Description |
|---|---|---|
| **1** | **Verified Neighbor Network & Trust Score** | Phone & address/neighborhood onboarding. Dynamic trust reliability score badges displayed on profiles and item cards based on lending activity. |
| **2** | **Smart Item Listing & Availability Calendar** | Lenders publish items with high-resolution photos, categories, item description, refundable deposit amount, and real-time availability status. |
| **3** | **In-App Borrow Requests & Digital Agreement** | Borrowers select dates, review automatically calculated refundable deposits, leave notes, and e-sign a legally binding digital borrower agreement before submitting. |
| **4** | **Booking Lifecycle & In-App Chat** | Status machine transitions (`pending` → `active` → `done` / `cancelled`). Live in-app chat per booking with borrower/lender, plus meeting point and pickup coordination. |
| **5** | **AI Return Condition Check** | Before-pickup and after-return photo comparison. AI analysis verifies item condition, calculates match percentage, and confirms refundable deposit return. |
| **6** | **My Borrows & My Lends Tracker** | Dedicated tabbed dashboard for borrowers and lenders with status chips (`Awaiting pickup`, `Active loan`, `Completed`, `Cancelled`) and action triggers. |
| **7** | **Profile & Listings Management** | Live counter badges for items listed and active loans. One-tap "My Listed Items" management sheet allowing users to view details, add new items, or delete listings with automated cascade cleanup. |

---

## 4. Project Structure

```
ToolVerseApp/
├── android/                   ← Android native project configuration & manifest
├── ios/                       ← iOS native project configuration
├── web/                       ← Web platform wrapper and FCM service worker
├── lib/                       ← Flutter application source code
│   ├── main.dart              ← Main entry point, UI screens, design tokens & AppState
│   ├── models/                ← Data models (ItemModel, BookingModel, UserModel, Chat)
│   ├── providers/             ← State management providers
│   ├── services/              ← API client, AuthService, Firestore/Mongo sync, Storage
│   └── utils/                 ← UI helpers, formatters, and theme colors
├── backend/                   ← FastAPI REST API backend
│   ├── app/
│   │   ├── core/              ← Security, JWT tokens, config & rate limiting
│   │   ├── db/                ← MongoDB Atlas async connection & indexes
│   │   ├── routers/           ← API routes (auth, items, bookings, chats, users, uploads)
│   │   ├── schemas/           ← Pydantic request/response models
│   │   ├── services/          ← Cloudinary, OTP, Notification, Gemini Vision services
│   │   └── main.py            ← FastAPI application setup and lifespan
│   ├── scripts/               ← Live verification and seeding scripts
│   ├── requirements.txt       ← Python dependencies
│   ├── seed_demo_items.py     ← Initial catalogue seeder
│   └── .env                   ← Environment secrets (keep local)
├── pubspec.yaml               ← Flutter dependencies and assets
└── README.md                  ← Project documentation
```

---

## 5. How to Run Locally

### Prerequisites
- **Flutter SDK** (`3.16+` or latest stable) installed: `flutter --version`
- **Python** (`3.11+` / `3.14`): `python3 --version`

---

### Step 1: Start the Backend Server

1. Open a terminal and navigate to the project directory:
   ```bash
   cd ToolVerseApp
   ```
2. Activate the Python virtual environment and ensure dependencies are installed:
   ```bash
   source backend/.venv/bin/activate
   pip install -r backend/requirements.txt
   ```
3. Start the FastAPI server with auto-reload:
   ```bash
   python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
4. Verify the backend is online by visiting:
   - **Health Check:** [http://localhost:8000/api/health](http://localhost:8000/api/health)
   - **Interactive API Docs (Swagger):** [http://localhost:8000/docs](http://localhost:8000/docs)

---

### Step 2: Run the Flutter Client

1. In a second terminal window (from `ToolVerseApp/`):
   ```bash
   flutter pub get
   ```
2. Run on your target platform:
   - **Chrome Web:**
     ```bash
     flutter run -d chrome
     ```
   - **Android Device / Emulator:**
     ```bash
     flutter run -d android
     ```
   - **iOS Simulator:**
     ```bash
     flutter run -d ios
     ```

---

## 6. Key API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Subsystem health report (MongoDB, Cloudinary, OTP, Push) |
| `POST` | `/api/auth/otp/send` | Request email/phone OTP code |
| `POST` | `/api/auth/otp/verify` | Verify OTP and issue JWT access token |
| `POST` | `/api/auth/google` | Google OAuth authentication & account linking |
| `GET` | `/api/items` | Catalogue search with category & name filters |
| `POST` | `/api/items` | Publish a new tool/equipment listing |
| `DELETE` | `/api/items/{id}` | Delete item and cascade-clean associated bookings |
| `GET` | `/api/bookings` | List user bookings (as borrower and lender) |
| `POST` | `/api/bookings` | Create new borrow request with dates & deposit |
| `PATCH` | `/api/bookings/{id}/status` | Advance booking status (`active`, `done`, `cancelled`) |
| `POST` | `/api/bookings/{id}/ai-check` | Execute AI return inspection & deposit refund |
| `GET` | `/api/chats/{booking_id}` | Retrieve real-time booking chat messages |
| `POST` | `/api/chats` | Send message to booking participant |

---

## 7. Submission Checklist Verification

- [x] Full user authentication flow with persistent sessions and logout
- [x] Complete item listing creation, editing, and deletion with image hosting
- [x] In-app borrow request creation with digital borrower agreement
- [x] Real-time booking chat and status progression
- [x] AI return inspection workflow with condition verification
- [x] Clean architecture separating presentation, business logic, and database layer
- [x] Passing `flutter analyze` with 0 errors and 0 warnings
