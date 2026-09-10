# Twilio Verify OTP Authentication Setup Guide

This guide walks you through setting up **Twilio Verify** for phone number OTP authentication in the Pramaan application.

---

## 📌 Architecture Overview

```text
Farmer Phone Number (+91 XXXXX XXXXX)
         │
         ▼
[Flutter Mobile/Web Client] ────────────► [FastAPI Backend] ────────► [Twilio Verify Service]
(Sends phone number)                      POST /api/auth/send-otp      Dispatches SMS OTP via Twilio
         │
         │ (User receives 6-digit SMS OTP)
         ▼
[Flutter Mobile/Web Client] ────────────► [FastAPI Backend] ────────► [Twilio Verify Service]
(Enters 6-digit OTP)                      POST /api/auth/verify-otp    Validates code directly
                                                  │
                                                  ▼
                                       [MongoDB / Local DB]
                                       Find / Create Farmer Session
                                                  │
                                                  ▼
                                       [Authenticated Dashboard]
```

### Key Security Features
- **Zero Secrets on Client**: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_VERIFY_SERVICE_SID` reside **only** in the backend server environment.
- **Twilio Verify Engine**: OTPs are generated and validated on Twilio's infrastructure. No plaintext OTPs are ever generated, logged, or returned via API.
- **E.164 Normalization**: Automatic formatting of Indian (10-digit / 12-digit) and international phone numbers to standard E.164 format (e.g., `+919876543210`).
- **Sliding-Window Rate Limiting**:
  - Maximum 3 OTP requests per phone per 10 minutes (60-second cooldown between requests).
  - Maximum 15 OTP requests per IP per hour.
  - Maximum 5 failed OTP verification attempts per phone per 15 minutes.

---

## 🛠️ Step-by-Step Twilio Setup Instructions

### Step 1: Create or Sign in to Your Twilio Account
1. Visit [https://www.twilio.com](https://www.twilio.com) and create an account or sign in to your existing account.
2. Complete phone and email verification if prompted.

### Step 2: Retrieve Your Account SID and Auth Token
1. In the [Twilio Console Dashboard](https://console.twilio.com/), locate the **Account Info** tile on the home page.
2. Copy your **Account SID** (starts with `AC...`).
3. Click **Show** under **Auth Token** and copy your secure token.

### Step 3: Create a Twilio Verify Service
1. In the left navigation menu, go to **Explore Products** > **Verify** (or navigate to **Verify** > **Services**).
2. Click **Create Service** (or **+ Create new Service**).
3. Give your service a friendly name (e.g., `Pramaan AgTech Auth`).
4. Select **SMS** as an enabled channel.
5. Set the OTP code length to **6 digits** (default).
6. Click **Create**.
7. Once created, copy the **Service SID** (starts with `VA...`).

> [!NOTE]
> Twilio Verify does **NOT** require a dedicated Twilio phone number purchase; Verify uses Twilio's managed carrier pool to deliver OTP SMS automatically worldwide.

### Step 4: Configure Your `.env` File
In the project root directory, add your Twilio credentials to `.env`:

```env
# Twilio Verify OTP Configuration
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> [!IMPORTANT]
> Keep `.env` secret. It is included in `.gitignore` and must **never** be committed to version control.

---

## 📡 Backend API Reference

### 1. Send OTP
- **Endpoint**: `POST /api/auth/send-otp` (or `/api/v1/auth/send-otp`)
- **Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "phone": "+919876543210"
  }
  ```
- **Response** (Success - HTTP 200):
  ```json
  {
    "success": true,
    "message": "OTP sent successfully",
    "phone": "+919876543210",
    "status": "pending"
  }
  ```

### 2. Verify OTP & Authenticate
- **Endpoint**: `POST /api/auth/verify-otp` (or `/api/v1/auth/verify-otp`)
- **Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "phone": "+919876543210",
    "otp": "123456",
    "name": "Ramesh Patil",
    "village": "Nashik",
    "state": "Maharashtra",
    "crop": "Cotton",
    "acres": 10.0
  }
  ```
- **Response** (Success - HTTP 200):
  ```json
  {
    "success": true,
    "message": "Phone number verified successfully",
    "phone": "+919876543210",
    "user": {
      "phone": "+919876543210",
      "name": "Ramesh Patil",
      "phoneVerified": true,
      "village": "Nashik",
      "state": "Maharashtra",
      "crop": "Cotton",
      "acres": 10.0,
      "last_login": "2026-09-10T07:15:00Z"
    }
  }
  ```

---

## 🧪 Running & Testing the Implementation

### 1. Run Backend Unit Tests
Execute the unit test suite verifying phone normalization, rate limits, and verification mocks:
```bash
python -m unittest backend/tests/test_twilio_verify.py
```

### 2. Start the FastAPI Backend
```bash
python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```
Interactive Swagger docs: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

### 3. Start the Flutter Frontend
```bash
cd frontend
flutter run
```

### 4. Verification Checklist
- [x] Step 1: Enter Name and 10-digit mobile number, click **Send Verification OTP**.
- [x] Step 2: 6 individual OTP input boxes appear with automatic next-field focus and paste support.
- [x] Step 3: 30-second countdown timer runs before **Resend OTP** becomes active.
- [x] Step 4: Entering 6 digits enables the **Verify OTP & Enter Farm** button.
- [x] Step 5: Successful verification registers the session and opens `/farmer_dashboard`.
