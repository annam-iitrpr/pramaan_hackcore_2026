"""
PRAMAAN Twilio Verify OTP Service
Handles production-ready phone number validation (E.164), rate-limiting,
and server-side OTP generation/verification using Twilio Verify API.
"""

import time
import re
import logging
from typing import Dict, Any, Tuple, Optional, List
from collections import defaultdict
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
from backend.app.core.config import settings

logger = logging.getLogger(__name__)

# Phone number validation regex (E.164 international standard: + followed by 7-15 digits)
E164_REGEX = re.compile(r"^\+[1-9]\d{7,14}$")

class TwilioVerifyService:
    def __init__(self):
        self._phone_send_timestamps: Dict[str, List[float]] = defaultdict(list)
        self._ip_send_timestamps: Dict[str, List[float]] = defaultdict(list)
        self._phone_failed_attempts: Dict[str, List[float]] = defaultdict(list)
        
        # Rate Limiting Parameters
        self.COOLDOWN_SECONDS = 30           # Minimum wait between consecutive OTP sends per phone
        self.MAX_SENDS_PER_WINDOW = 5        # Max OTP requests per phone in 10 minutes
        self.MAX_SENDS_PER_IP = 10           # Max OTP requests per IP in 10 minutes
        self.MAX_FAILED_ATTEMPTS = 5         # Max failed verification attempts per phone in 10 minutes
        self.WINDOW_SECONDS = 600            # 10 minutes sliding window

    @property
    def is_configured(self) -> bool:
        """Checks whether all required Twilio credentials are configured in environment."""
        return bool(
            settings.TWILIO_ACCOUNT_SID
            and settings.TWILIO_AUTH_TOKEN
            and settings.TWILIO_VERIFY_SERVICE_SID
            and not settings.TWILIO_VERIFY_SERVICE_SID.startswith("your_")
        )

    def get_twilio_client(self) -> Client:
        """Initializes and returns a Twilio Client."""
        if not self.is_configured:
            raise ValueError(
                "Twilio credentials are not configured. Please set TWILIO_ACCOUNT_SID, "
                "TWILIO_AUTH_TOKEN, and TWILIO_VERIFY_SERVICE_SID in your .env file."
            )
        return Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

    def normalize_phone(self, raw_phone: str) -> str:
        """
        Cleans and normalizes phone number to strict E.164 international format.
        Defaults 10-digit numbers to Indian (+91) country code.
        """
        if not raw_phone:
            raise ValueError("Phone number cannot be empty.")

        cleaned = raw_phone.strip().replace(" ", "").replace("-", "").replace("(", "").replace(")", "")

        # If it's a 10-digit number without country code, prefix with +91 (India)
        if len(cleaned) == 10 and cleaned.isdigit():
            cleaned = f"+91{cleaned}"
        elif len(cleaned) == 12 and cleaned.startswith("91") and cleaned.isdigit():
            cleaned = f"+{cleaned}"
        elif not cleaned.startswith("+"):
            cleaned = f"+{cleaned}"

        if not E164_REGEX.match(cleaned):
            raise ValueError(
                f"Invalid phone number format: '{raw_phone}'. Must be a valid phone number in E.164 format (e.g. +919876543210)."
            )

        return cleaned

    def _cleanup_old_timestamps(self, timestamps: List[float]) -> List[float]:
        """Removes timestamps outside of the sliding window."""
        now = time.time()
        return [ts for ts in timestamps if now - ts < self.WINDOW_SECONDS]

    def check_send_rate_limit(self, phone: str, ip: Optional[str] = None) -> Tuple[bool, Optional[str]]:
        """
        Validates rate limiting for sending OTP.
        Prevents spamming and rapid automated requests.
        """
        now = time.time()

        # 1. Cooldown Check per Phone
        phone_timestamps = self._cleanup_old_timestamps(self._phone_send_timestamps[phone])
        self._phone_send_timestamps[phone] = phone_timestamps

        if phone_timestamps:
            last_send = phone_timestamps[-1]
            elapsed = now - last_send
            if elapsed < self.COOLDOWN_SECONDS:
                remaining = int(self.COOLDOWN_SECONDS - elapsed)
                return False, f"Please wait {remaining} seconds before requesting another OTP."

        # 2. Window Request Count per Phone
        if len(phone_timestamps) >= self.MAX_SENDS_PER_WINDOW:
            return False, "Too many OTP requests for this phone number. Please try again after 10 minutes."

        # 3. IP Rate Limit Check
        if ip:
            ip_timestamps = self._cleanup_old_timestamps(self._ip_send_timestamps[ip])
            self._ip_send_timestamps[ip] = ip_timestamps
            if len(ip_timestamps) >= self.MAX_SENDS_PER_IP:
                return False, "Too many OTP requests from this network. Please try again later."

        return True, None

    def record_send(self, phone: str, ip: Optional[str] = None):
        """Records an OTP send event for rate limiting tracking."""
        now = time.time()
        self._phone_send_timestamps[phone].append(now)
        if ip:
            self._ip_send_timestamps[ip].append(now)

    def check_verify_rate_limit(self, phone: str) -> Tuple[bool, Optional[str]]:
        """Prevents brute force guessing on verification attempts."""
        failed_attempts = self._cleanup_old_timestamps(self._phone_failed_attempts[phone])
        self._phone_failed_attempts[phone] = failed_attempts

        if len(failed_attempts) >= self.MAX_FAILED_ATTEMPTS:
            return False, "Maximum verification attempts exceeded. Please request a new OTP."

        return True, None

    def record_failed_attempt(self, phone: str):
        """Records a failed verification attempt."""
        self._phone_failed_attempts[phone].append(time.time())

    def reset_failed_attempts(self, phone: str):
        """Resets failed attempts on successful verification."""
        self._phone_failed_attempts[phone] = []

    # ============================================================
    # PUBLIC TWILIO VERIFY METHODS
    # ============================================================

    def send_otp(self, raw_phone: str, ip: Optional[str] = None) -> Dict[str, Any]:
        """
        Initiates an SMS OTP verification via Twilio Verify.
        Validates phone, checks rate-limits, and creates a Twilio Verification.
        """
        # 1. Normalize Phone
        try:
            phone = self.normalize_phone(raw_phone)
        except ValueError as val_err:
            return {"success": False, "message": str(val_err), "code": "INVALID_PHONE"}

        # 2. Check Rate Limits
        is_allowed, rate_msg = self.check_send_rate_limit(phone, ip)
        if not is_allowed:
            return {"success": False, "message": rate_msg, "code": "RATE_LIMIT_EXCEEDED"}

        # 3. Check Configuration
        if not self.is_configured:
            logger.error("[TwilioVerify] Missing TWILIO_VERIFY_SERVICE_SID or credentials.")
            return {
                "success": False,
                "message": "Twilio Verify service is not configured on the server. Please check backend environment.",
                "code": "TWILIO_CONFIG_MISSING"
            }

        # 4. Call Twilio Verify
        try:
            client = self.get_twilio_client()
            verification = client.verify.v2.services(settings.TWILIO_VERIFY_SERVICE_SID).verifications.create(
                to=phone,
                channel="sms"
            )

            # Record send timestamp for rate limiter
            self.record_send(phone, ip)
            logger.info(f"[TwilioVerify] OTP sent to {phone[:5]}***, status={verification.status}")

            return {
                "success": True,
                "message": "OTP sent successfully",
                "status": verification.status,
                "phone": phone
            }

        except TwilioRestException as twilio_err:
            logger.error(f"[TwilioVerify] Twilio API error ({twilio_err.code}): {twilio_err.msg}")
            
            # Map Twilio error codes to user-friendly messages
            if twilio_err.code == 60200:
                msg = "Invalid phone number format."
            elif twilio_err.code == 60203:
                msg = "Max OTP send attempts reached for this phone number. Please try again later."
            elif twilio_err.code == 21211:
                msg = "The provided phone number is invalid."
            elif twilio_err.code == 60212:
                msg = "Too many concurrent requests. Please wait a moment."
            else:
                msg = f"SMS delivery error: {twilio_err.msg}"

            return {
                "success": False,
                "message": msg,
                "code": f"TWILIO_{twilio_err.code}"
            }

        except Exception as e:
            logger.exception("[TwilioVerify] Unexpected error in send_otp")
            return {
                "success": False,
                "message": "Failed to send verification code. Please try again.",
                "code": "INTERNAL_ERROR"
            }

    def verify_otp(self, raw_phone: str, otp_code: str, ip: Optional[str] = None) -> Dict[str, Any]:
        """
        Verifies a user-supplied OTP code using Twilio Verify API.
        Never logs or stores the OTP code.
        """
        # 1. Normalize Phone
        try:
            phone = self.normalize_phone(raw_phone)
        except ValueError as val_err:
            return {"success": False, "message": str(val_err), "code": "INVALID_PHONE"}

        # 2. Validate OTP format (must be 4-8 digits, typically 6 digits)
        clean_code = str(otp_code or "").strip()
        if not clean_code or not clean_code.isdigit() or len(clean_code) < 4 or len(clean_code) > 8:
            return {
                "success": False,
                "message": "Please enter a valid 6-digit verification code.",
                "code": "INVALID_CODE_FORMAT"
            }

        # 3. Check Verification Rate Limit (Brute Force Protection)
        is_allowed, rate_msg = self.check_verify_rate_limit(phone)
        if not is_allowed:
            return {"success": False, "message": rate_msg, "code": "MAX_ATTEMPTS_EXCEEDED"}

        # 4. Check Configuration
        if not self.is_configured:
            logger.error("[TwilioVerify] Missing TWILIO_VERIFY_SERVICE_SID or credentials.")
            return {
                "success": False,
                "message": "Twilio Verify service is not configured on the server.",
                "code": "TWILIO_CONFIG_MISSING"
            }

        # 5. Call Twilio Verify Check
        try:
            client = self.get_twilio_client()
            verification_check = client.verify.v2.services(settings.TWILIO_VERIFY_SERVICE_SID).verification_checks.create(
                to=phone,
                code=clean_code
            )

            if verification_check.status == "approved":
                self.reset_failed_attempts(phone)
                logger.info(f"[TwilioVerify] OTP verification approved for {phone[:5]}***")
                return {
                    "success": True,
                    "message": "Phone number verified successfully",
                    "status": "approved",
                    "phone": phone
                }
            else:
                self.record_failed_attempt(phone)
                logger.warning(f"[TwilioVerify] OTP verification rejected for {phone[:5]}*** (status={verification_check.status})")
                return {
                    "success": False,
                    "message": "Invalid verification code. Please check and try again.",
                    "code": "INVALID_OTP",
                    "status": verification_check.status
                }

        except TwilioRestException as twilio_err:
            self.record_failed_attempt(phone)
            logger.error(f"[TwilioVerify] Twilio check error ({twilio_err.code}): {twilio_err.msg}")
            
            if twilio_err.code == 20404:
                msg = "Verification code has expired or was not found. Please request a new OTP."
            elif twilio_err.code == 60202:
                msg = "Max verification attempts reached. Please request a new OTP."
            else:
                msg = "Verification failed. Please try again."

            return {
                "success": False,
                "message": msg,
                "code": f"TWILIO_{twilio_err.code}"
            }

        except Exception as e:
            logger.exception("[TwilioVerify] Unexpected error in verify_otp")
            return {
                "success": False,
                "message": "An error occurred during verification. Please try again.",
                "code": "INTERNAL_ERROR"
            }

# Singleton instance
twilio_verify_service = TwilioVerifyService()
