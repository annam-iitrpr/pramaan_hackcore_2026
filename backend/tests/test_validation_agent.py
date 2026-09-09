import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.ai.validation_agent import validation_agent
from backend.app.models.schemas import (
    MultiAgentValidationRequest,
    GeoLocation
)

client = TestClient(app)

def test_user_example_dose_mismatch():
    """
    User's exact example:
    NLP says: Bio-X, 2 L/acre
    Vision product-label says: Bio-X, recommended dose 1 L/acre
    Validation Agent flags this -> needs_review, warning, dose_mismatch, user_confirmation.
    """
    req = MultiAgentValidationRequest(
        evidence_id="EV-TEST-001",
        farm_id="farm-101",
        crop_name="Cotton",
        timestamp="2026-09-04T10:00:00Z",
        location=GeoLocation(latitude=20.1985, longitude=73.8322),
        nlp_output={
            "raw_transcript": "Sprayed Bio-X 2 L per acre on cotton crop for sucking pest control.",
            "crop": "Cotton",
            "action_type": "SPRAY",
            "product_mentioned": "Bio-X",
            "dosage": "2 L/acre",
            "target_pest": "Whitefly"
        },
        vision_output={
            "crop_detected": "Cotton (Bt-II)",
            "product_name": "Bio-X",
            "label_dosage": "1 L/acre",
            "recommended_dosage": "1 L/acre",
            "disease_detected": "Healthy Crop"
        },
        weather_output={
            "temperature_c": 27.5,
            "humidity_percent": 65.0,
            "wind_speed_kmh": 6.5,
            "precipitation_prob": 10.0,
            "delta_t_c": 4.5
        }
    )

    res = validation_agent.validate_multi_agent(req)

    assert res.validation_status == "needs_review"
    assert res.consistency_status == "warning"
    assert res.required_action == "user_confirmation"
    assert res.completeness_score >= 0.80
    assert len(res.flags) >= 1

    dose_flag = next((f for f in res.flags if f.type == "dose_mismatch"), None)
    assert dose_flag is not None
    assert "Recorded dose" in dose_flag.message
    assert "visible product-label dose" in dose_flag.message

def test_consistent_evidence_validated():
    """
    Test when all agents' outputs are completely consistent and compliant:
    Validation Agent returns validated, consistent, no flags, action none.
    """
    req = MultiAgentValidationRequest(
        evidence_id="EV-TEST-002",
        farm_id="farm-101",
        crop_name="Wheat",
        timestamp="2026-09-04T07:30:00Z",
        location=GeoLocation(latitude=20.1985, longitude=73.8322),
        nlp_output={
            "raw_transcript": "Applied Propiconazole 25% EC Tilt at 200 ml per acre in 200L water for wheat yellow rust control.",
            "crop": "Wheat",
            "action_type": "SPRAY",
            "product_mentioned": "Propiconazole 25% EC (Tilt)",
            "dosage": "200 ml in 200L water / acre",
            "target_pest": "Yellow Rust"
        },
        vision_output={
            "crop_detected": "Wheat",
            "disease_detected": "Yellow Rust (Puccinia striiformis)",
            "product_name": "Propiconazole 25% EC (Tilt)",
            "label_dosage": "200 ml/acre",
            "severity_level": "Medium"
        },
        weather_output={
            "temperature_c": 24.0,
            "humidity_percent": 70.0,
            "wind_speed_kmh": 5.2,
            "precipitation_prob": 5.0,
            "delta_t_c": 3.8
        }
    )

    res = validation_agent.validate_multi_agent(req)

    assert res.validation_status == "validated"
    assert res.consistency_status == "consistent"
    assert res.required_action == "none"
    assert len(res.flags) == 0
    assert res.completeness_score >= 0.85
    assert res.composite_trust_score >= 90.0
    assert res.cryptographic_hash is not None

def test_adverse_weather_drift_risk():
    """
    Test when weather conditions are adverse (high wind speed > 15 km/h):
    Validation Agent flags weather_spray_conflict.
    """
    req = MultiAgentValidationRequest(
        evidence_id="EV-TEST-003",
        farm_id="farm-101",
        crop_name="Cotton",
        timestamp="2026-09-04T14:00:00Z",
        location=GeoLocation(latitude=20.1985, longitude=73.8322),
        nlp_output={
            "raw_transcript": "Sprayed Bio-Neem 400 ml/acre on cotton.",
            "crop": "Cotton",
            "action_type": "SPRAY",
            "product_mentioned": "Bio-Neem",
            "dosage": "400 ml/acre",
            "target_pest": "Whitefly"
        },
        vision_output={
            "crop_detected": "Cotton",
            "disease_detected": "Whitefly Infestation"
        },
        weather_output={
            "temperature_c": 35.0,
            "humidity_percent": 40.0,
            "wind_speed_kmh": 22.5, # Exceeds 15 km/h
            "precipitation_prob": 15.0,
            "delta_t_c": 9.2 # High evaporation
        }
    )

    res = validation_agent.validate_multi_agent(req)

    assert res.validation_status == "needs_review"
    assert res.consistency_status == "warning"
    weather_flag = next((f for f in res.flags if f.type == "weather_spray_conflict"), None)
    assert weather_flag is not None
    assert "exceeds the safe spraying limit" in weather_flag.message

def test_crop_pest_incompatibility():
    """
    Test when chemical/disease category contradicts target pathogen (Fungicide used for Whitefly insect).
    """
    req = MultiAgentValidationRequest(
        evidence_id="EV-TEST-004",
        farm_id="farm-101",
        crop_name="Wheat",
        timestamp="2026-09-04T11:00:00Z",
        location=GeoLocation(latitude=20.1985, longitude=73.8322),
        nlp_output={
            "raw_transcript": "Sprayed Tilt fungicide for whitefly attack.",
            "crop": "Wheat",
            "action_type": "SPRAY",
            "product_mentioned": "Tilt",
            "dosage": "200 ml/acre",
            "target_pest": "Whitefly" # Insect pest with fungicide
        },
        vision_output={
            "crop_detected": "Wheat",
            "disease_detected": "Whitefly"
        }
    )

    res = validation_agent.validate_multi_agent(req)

    assert res.validation_status == "needs_review"
    incomp_flag = next((f for f in res.flags if f.type == "chemical_pest_incompatibility"), None)
    assert incomp_flag is not None

def test_cross_validate_api_endpoint():
    """
    Test FastAPI POST /api/v1/validation/cross-validate endpoint end-to-end.
    """
    payload = {
        "evidence_id": "EV-API-001",
        "farm_id": "farm-101",
        "crop_name": "Cotton",
        "nlp_output": {
            "crop": "Cotton",
            "action_type": "SPRAY",
            "product_mentioned": "Bio-X",
            "dosage": "2 L/acre"
        },
        "vision_output": {
            "crop_detected": "Cotton",
            "label_dosage": "1 L/acre"
        },
        "weather_output": {
            "wind_speed_kmh": 8.0,
            "precipitation_prob": 10.0
        }
    }

    response = client.post("/api/v1/validation/cross-validate", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["validation_status"] == "needs_review"
    assert data["consistency_status"] == "warning"
    assert data["required_action"] == "user_confirmation"
    assert any(f["type"] == "dose_mismatch" for f in data["flags"])

if __name__ == "__main__":
    print("\n" + "="*70)
    print("RUNNING TRUST & VALIDATION AGENT (AGENT #4) UNIT TESTS")
    print("="*70)
    
    test_user_example_dose_mismatch()
    print(" [PASSED] test_user_example_dose_mismatch: User's Bio-X 2L vs 1L dose mismatch flagged properly.")
    
    test_consistent_evidence_validated()
    print(" [PASSED] test_consistent_evidence_validated: Consistent Tilt spray on wheat validated without flags.")
    
    test_adverse_weather_drift_risk()
    print(" [PASSED] test_adverse_weather_drift_risk: High wind speed (>15 km/h) drift conflict flagged.")
    
    test_crop_pest_incompatibility()
    print(" [PASSED] test_crop_pest_incompatibility: Incompatible chemical / insect attack mismatch detected.")
    
    test_cross_validate_api_endpoint()
    print(" [PASSED] test_cross_validate_api_endpoint: POST /validation/cross-validate API working end-to-end.")
    
    print("\n" + "="*70)
    print(" ALL 5 TRUST & VALIDATION AGENT TESTS PASSED SUCCESSFULLY!")
    print("="*70 + "\n")
