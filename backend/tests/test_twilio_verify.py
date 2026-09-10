"""
Unit tests for Twilio Verify OTP Service and Auth Router using standard unittest.
Tests E.164 phone normalization, rate limiting, and mock Twilio interactions.
"""

import unittest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.services.twilio_verify_service import TwilioVerifyService

class TestTwilioVerifyService(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)

    # ============================================================
    # 1. PHONE NORMALIZATION & VALIDATION TESTS
    # ============================================================

    def test_phone_normalization_valid_formats(self):
        service = TwilioVerifyService()
        
        # Standard 10-digit Indian number
        self.assertEqual(service.normalize_phone("9876543210"), "+919876543210")
        self.assertEqual(service.normalize_phone("919876543210"), "+919876543210")
        self.assertEqual(service.normalize_phone("+919876543210"), "+919876543210")
        
        # With spaces, hyphens, and brackets
        self.assertEqual(service.normalize_phone("+91 98765-43210"), "+919876543210")
        self.assertEqual(service.normalize_phone("(+91) 98765 43210"), "+919876543210")

        # US / International E.164
        self.assertEqual(service.normalize_phone("+14155552671"), "+14155552671")

    def test_phone_normalization_invalid_formats(self):
        service = TwilioVerifyService()
        
        with self.assertRaises(ValueError):
            service.normalize_phone("")
        
        with self.assertRaises(ValueError):
            service.normalize_phone("12345")  # Too short
        
        with self.assertRaises(ValueError):
            service.normalize_phone("invalid-phone")

    # ============================================================
    # 2. RATE LIMITING TESTS
    # ============================================================

    def test_send_rate_limiting_cooldown(self):
        service = TwilioVerifyService()
        phone = "+919876543210"
        
        # First send is allowed
        allowed, msg = service.check_send_rate_limit(phone)
        self.assertTrue(allowed)
        service.record_send(phone)
        
        # Immediate second send should be blocked by 30s cooldown
        allowed, msg = service.check_send_rate_limit(phone)
        self.assertFalse(allowed)
        self.assertIn("Please wait", msg)

    def test_verify_rate_limiting_brute_force(self):
        service = TwilioVerifyService()
        phone = "+919876543210"
        
        # 5 consecutive failed attempts
        for _ in range(5):
            service.record_failed_attempt(phone)
        
        allowed, msg = service.check_verify_rate_limit(phone)
        self.assertFalse(allowed)
        self.assertIn("Maximum verification attempts exceeded", msg)

    # ============================================================
    # 3. ENDPOINT INTEGRATION TESTS (WITH TWILIO MOCKS)
    # ============================================================

    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_ACCOUNT_SID", "ACtest123456789")
    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_AUTH_TOKEN", "authtokentest")
    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_VERIFY_SERVICE_SID", "VAtest123456789")
    def test_send_otp_success_mock(self):
        with patch("backend.app.services.twilio_verify_service.Client") as mock_twilio_client:
            mock_instance = MagicMock()
            mock_verification = MagicMock()
            mock_verification.status = "pending"
            mock_instance.verify.v2.services.return_value.verifications.create.return_value = mock_verification
            mock_twilio_client.return_value = mock_instance

            response = self.client.post("/api/auth/send-otp", json={"phone": "+919876543210"})
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertTrue(data["success"])
            self.assertEqual(data["message"], "OTP sent successfully")

            # Also verify /api/v1/auth prefix works
            response_v1 = self.client.post("/api/v1/auth/send-otp", json={"phone": "+919876543211"})
            self.assertEqual(response_v1.status_code, 200)

    def test_send_otp_invalid_phone(self):
        response = self.client.post("/api/auth/send-otp", json={"phone": "123"})
        self.assertEqual(response.status_code, 400)
        data = response.json()
        self.assertIn("Invalid phone number format", data["detail"])

    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_ACCOUNT_SID", "ACtest123456789")
    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_AUTH_TOKEN", "authtokentest")
    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_VERIFY_SERVICE_SID", "VAtest123456789")
    def test_verify_otp_approved_mock(self):
        with patch("backend.app.services.twilio_verify_service.Client") as mock_twilio_client:
            mock_instance = MagicMock()
            mock_check = MagicMock()
            mock_check.status = "approved"
            mock_instance.verify.v2.services.return_value.verification_checks.create.return_value = mock_check
            mock_twilio_client.return_value = mock_instance

            response = self.client.post(
                "/api/auth/verify-otp",
                json={
                    "phone": "+919876543210",
                    "otp": "123456",
                    "name": "Ramesh Patil",
                    "village": "Dindori",
                    "state": "Maharashtra"
                }
            )
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertTrue(data["success"])
            self.assertEqual(data["message"], "Phone number verified successfully")
            self.assertEqual(data["user"]["phone"], "+919876543210")

    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_ACCOUNT_SID", "ACtest123456789")
    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_AUTH_TOKEN", "authtokentest")
    @patch("backend.app.services.twilio_verify_service.settings.TWILIO_VERIFY_SERVICE_SID", "VAtest123456789")
    def test_verify_otp_rejected_mock(self):
        with patch("backend.app.services.twilio_verify_service.Client") as mock_twilio_client:
            mock_instance = MagicMock()
            mock_check = MagicMock()
            mock_check.status = "canceled"
            mock_instance.verify.v2.services.return_value.verification_checks.create.return_value = mock_check
            mock_twilio_client.return_value = mock_instance

            response = self.client.post(
                "/api/auth/verify-otp",
                json={
                    "phone": "+919876543210",
                    "otp": "999999"
                }
            )
            self.assertEqual(response.status_code, 400)
            data = response.json()
            self.assertIn("Invalid verification code", data["detail"])

if __name__ == "__main__":
    unittest.main()
