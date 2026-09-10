"""
PRAMAAN Authentication & Phone OTP Verification Router
Provides secure endpoints for Twilio Verify SMS OTP send & verification.
"""

from fastapi import APIRouter, HTTPException, Request, Body, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import logging

from backend.app.services.twilio_verify_service import twilio_verify_service
from backend.app.database.mongodb import mongo_db

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Authentication & Phone OTP"])


# ============================================================
# PYDANTIC SCHEMAS
# ============================================================

class SendOtpRequest(BaseModel):
    phone: str = Field(..., description="Farmer mobile number (E.164 or 10-digit Indian number)", example="+919876543210")

class SendOtpResponse(BaseModel):
    success: bool
    message: str

class VerifyOtpRequest(BaseModel):
    phone: str = Field(..., description="Farmer mobile number in E.164 format", example="+919876543210")
    otp: str = Field(..., description="6-digit verification code received via SMS", example="123456")
    name: Optional[str] = Field(None, description="Optional name for farmer profile registration", example="Ramesh Patil")
    village: Optional[str] = Field(None, description="Optional village / district location", example="Dindori, Nashik")
    state: Optional[str] = Field(None, description="Optional state", example="Maharashtra")
    crop: Optional[str] = Field(None, description="Optional primary crop", example="Cotton")
    acres: Optional[float] = Field(None, description="Optional farm size in acres", example=10.0)

class VerifyOtpResponse(BaseModel):
    success: bool
    message: str
    is_new_user: Optional[bool] = False
    user: Optional[Dict[str, Any]] = None
    logs: Optional[List[Dict[str, Any]]] = None


# ============================================================
# CLIENT IP HELPER
# ============================================================

def get_client_ip(request: Request) -> str:
    """Extracts client IP address considering proxy headers."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "127.0.0.1"


# ============================================================
# API ENDPOINTS
# ============================================================

@router.post(
    "/send-otp",
    response_model=SendOtpResponse,
    summary="Send Twilio Verify SMS OTP",
    description="Initiates an SMS OTP verification to the specified phone number via Twilio Verify."
)
async def send_otp(
    payload: SendOtpRequest,
    request: Request
):
    ip = get_client_ip(request)
    result = twilio_verify_service.send_otp(raw_phone=payload.phone, ip=ip)

    if not result.get("success"):
        error_code = result.get("code", "")
        status_code = status.HTTP_400_BAD_REQUEST

        if error_code == "RATE_LIMIT_EXCEEDED":
            status_code = status.HTTP_429_TOO_MANY_REQUESTS
        elif error_code == "TWILIO_CONFIG_MISSING":
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE

        raise HTTPException(
            status_code=status_code,
            detail=result.get("message", "Failed to send verification OTP.")
        )

    return SendOtpResponse(
        success=True,
        message=result.get("message", "OTP sent successfully")
    )


@router.post(
    "/verify-otp",
    response_model=VerifyOtpResponse,
    summary="Verify Twilio SMS OTP & Authenticate User",
    description="Validates the 6-digit OTP code using Twilio Verify and authenticates/registers the user."
)
async def verify_otp(
    payload: VerifyOtpRequest,
    request: Request
):
    ip = get_client_ip(request)
    result = twilio_verify_service.verify_otp(
        raw_phone=payload.phone,
        otp_code=payload.otp,
        ip=ip
    )

    if not result.get("success"):
        error_code = result.get("code", "")
        status_code = status.HTTP_400_BAD_REQUEST

        if error_code == "MAX_ATTEMPTS_EXCEEDED":
            status_code = status.HTTP_429_TOO_MANY_REQUESTS

        raise HTTPException(
            status_code=status_code,
            detail=result.get("message", "Invalid or expired OTP code.")
        )

    # 1. Fetch or create farmer profile in MongoDB
    phone = result.get("phone", payload.phone)
    existing_farmer = await mongo_db.get_farmer_profile(phone)
    is_new = existing_farmer is None

    farmer_data = {
        "phone": phone,
        "name": payload.name or (existing_farmer.get("name") if existing_farmer else "Kisan"),
        "village": payload.village or (existing_farmer.get("village") if existing_farmer else "Nashik"),
        "district": payload.village or (existing_farmer.get("district") if existing_farmer else "Nashik"),
        "state": payload.state or (existing_farmer.get("state") if existing_farmer else "Maharashtra"),
        "crop": payload.crop or (existing_farmer.get("crop") if existing_farmer else "Wheat"),
        "acres": payload.acres if payload.acres is not None else (existing_farmer.get("acres") if existing_farmer else 5.0),
        "phone_verified": True,
    }

    farmer_doc = await mongo_db.save_or_update_farmer(farmer_data)
    logs = await mongo_db.get_farmer_logs(phone)

    return VerifyOtpResponse(
        success=True,
        message="Phone number verified successfully",
        is_new_user=is_new,
        user=farmer_doc,
        logs=logs
    )
