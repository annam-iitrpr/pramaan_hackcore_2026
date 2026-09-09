import unittest
from fastapi.testclient import TestClient
from backend.app.main import app

class BackendTestSuite(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_root_endpoint(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "online")
        self.assertIn("Voice Agent", response.json()["agents"])

    def test_health_check(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "healthy")

    def test_farms_and_punjab_farms(self):
        response = self.client.get("/api/v1/farm/farms")
        self.assertEqual(response.status_code, 200)
        farms = response.json()
        self.assertGreater(len(farms), 0)
        punjab_farms = [f for f in farms if f.get("state") == "Punjab"]
        self.assertGreaterEqual(len(punjab_farms), 1)

    def test_punjab_districts_catalog(self):
        response = self.client.get("/api/v1/weather/punjab-districts")
        self.assertEqual(response.status_code, 200)
        districts = response.json()
        self.assertGreaterEqual(len(districts), 10)
        district_names = [d["name"] for d in districts]
        self.assertIn("Ludhiana", district_names)
        self.assertIn("Bathinda", district_names)
        self.assertIn("Amritsar", district_names)

    def test_realtime_weather_advisory(self):
        payload = {
            "latitude": 30.9010,
            "longitude": 75.8573,
            "district": "Ludhiana",
            "crop": "Wheat (Kanak)"
        }
        response = self.client.post("/api/v1/weather/advisory", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("current_weather", data)
        self.assertIn("upcoming_windows", data)
        self.assertGreater(len(data["upcoming_windows"]), 0)
        self.assertIsNotNone(data["current_weather"]["delta_t_c"])
        self.assertEqual(data["current_weather"]["district_name"], "Ludhiana")

    def test_punjab_district_weather_endpoint(self):
        response = self.client.get("/api/v1/weather/punjab/district/Bathinda?crop=Bt%20Cotton")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["current_weather"]["district_name"], "Bathinda")
        self.assertIn("upcoming_windows", data)

    def test_voice_agent_processing(self):
        payload = {
            "audio_transcript": "Sprayed 400ml Bio Neem on cotton crop in North plot today morning for whitefly control.",
            "language": "en",
            "farm_id": "farm-101"
        }
        response = self.client.post("/api/v1/voice/process", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIsNotNone(data["crop"])
        self.assertIn(data["action_type"], ["SPRAY", "OBSERVE", "FERTILIZE"])

    def test_vision_agent_analysis(self):
        # 1. Text hint test
        payload = {
            "crop_type": "Tomato",
            "plot_id": "plot-01"
        }
        response = self.client.post("/api/v1/vision/analyze", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("disease_detected", data)
        self.assertIn("crop_detected", data)
        self.assertIn(data["severity_level"], ["Low", "Medium", "High", "Critical", "Unknown"])
        self.assertIsInstance(data["symptoms"], list)

        # 2. Auto-Detect test with base64 image data
        import base64
        dummy_b64 = base64.b64encode(b"RIFF\x00\x00\x00\x00WEBPVP8 ").decode('utf-8')
        payload_img = {
            "crop_type": "Auto-Detect",
            "image_base64": dummy_b64,
            "plot_id": "plot-02"
        }
        response_img = self.client.post("/api/v1/vision/analyze", json=payload_img)
        self.assertEqual(response_img.status_code, 200)
        data_img = response_img.json()
        self.assertIn("crop_detected", data_img)
        self.assertIn("disease_detected", data_img)


    def test_validation_agent(self):
        payload = {
            "evidence_id": "EV-TEST-001",
            "farm_id": "farm-101",
            "evidence_type": "PRODUCT_SCAN",
            "timestamp": "2026-08-30T10:00:00Z",
            "location": {
                "latitude": 30.9010,
                "longitude": 75.8573
            },
            "crop_name": "Wheat",
            "product_data": {
                "qr_code": "PRM-INP-55310-TILT"
            }
        }
        response = self.client.post("/api/v1/validation/verify", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn(data["status"], ["VERIFIED", "PENDING", "FLAGGED"])
        self.assertEqual(len(data["hash_signature"]), 64)

    def test_report_generation(self):
        payload = {
            "farm_id": "farm-104",
            "crop": "Wheat (PBW-826)",
            "buyer_name": "ITC Agri-Business"
        }
        response = self.client.post("/api/v1/report/generate", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("report_id", data)
        self.assertGreater(data["compliance_score_percent"], 90.0)

if __name__ == "__main__":
    unittest.main()
