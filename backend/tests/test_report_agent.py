import os
import unittest
from backend.app.ai.report_agent import report_agent
from backend.app.models.schemas import AuditReportRequest

class TestReportAgent(unittest.TestCase):
    def test_3page_trilingual_report_generation(self):
        req = AuditReportRequest(
            farm_id="farm-101",
            crop="Cotton (Bt-II)",
            season="Kharif 2026",
            voice_transcript="आज सकाळी 400 मिली बायो-नीम 200 लिटर पाण्यात मिसळून कापसावर फवारणी केली आहे.",
            voice_action="SPRAY",
            product_applied="Bio-Neem 10,000 PPM",
            dosage="400 ml in 200L Water / Acre",
            target_pest="Whitefly & Aphids",
            disease_detected="Whitefly Infestation & Leaf Curl",
            health_status="Pest Infested",
            severity_level="Medium",
            affected_percentage=22.5,
            weather_temp=29.0,
            weather_humidity=64.0,
            weather_wind=6.2,
            weather_delta_t=3.8,
            spray_suitability="OPTIMAL"
        )

        response = report_agent.generate_audit_report(req)

        self.assertTrue(response.report_id.startswith("PRM-REP-"))
        self.assertEqual(response.pages_count, 3)
        self.assertIn("English (Page 1)", response.supported_languages)
        self.assertIn("Hindi (Page 2)", response.supported_languages)
        self.assertIn("Marathi (Page 3)", response.supported_languages)
        self.assertIsNotNone(response.recommendations)
        self.assertNotEqual(response.recommendations.chemical_treatment, "")
        self.assertNotEqual(response.recommendations.organic_alternative, "")
        self.assertGreater(response.recommendations.pre_harvest_interval_days, 0)
        self.assertIsNotNone(response.blockchain_hash_anchor)
        self.assertEqual(len(response.blockchain_hash_anchor), 64)
        self.assertIsNotNone(response.trilingual_data)
        self.assertEqual(response.trilingual_data.en["lang"], "English")
        self.assertEqual(response.trilingual_data.hi["lang"], "हिंदी (Hindi)")
        self.assertEqual(response.trilingual_data.mr["lang"], "मराठी (Marathi)")

        # Verify generated PDF file exists and is not empty
        pdf_filename = f"{response.report_id}.pdf"
        from backend.app.core.config import settings
        pdf_file_path = settings.DATA_DIR / "reports" / pdf_filename
        self.assertTrue(pdf_file_path.exists())
        self.assertGreater(pdf_file_path.stat().st_size, 1000)

        # Verify PDF header/footer magic bytes
        with open(pdf_file_path, "rb") as f:
            content = f.read()
            self.assertIn(b"%PDF", content[:10])
            self.assertIn(b"%%EOF", content[-1024:])

    def test_wheat_agronomic_recommendations(self):
        req = AuditReportRequest(
            farm_id="farm-104",
            crop="Wheat (PBW-826)",
            voice_transcript="गेहूं के खेत में पीला रतुआ दिखा है, 200 मिली प्रोपिकोनाज़ोल का स्प्रे किया।",
            target_pest="Yellow Rust"
        )
        response = report_agent.generate_audit_report(req)
        self.assertIn("Propiconazole", response.recommendations.chemical_treatment)
        self.assertEqual(response.recommendations.pre_harvest_interval_days, 30)
        self.assertGreater(response.total_lot_value_inr, 0)

if __name__ == "__main__":
    unittest.main()
