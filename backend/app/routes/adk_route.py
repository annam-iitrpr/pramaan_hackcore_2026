"""
API Route exposing live Google ADK (Agent Development Kit v2.8.0) runtime status and multi-agent execution.
"""

from fastapi import APIRouter
from typing import Dict, Any
from backend.app.ai.adk_orchestrator import (
    get_google_adk_system_info,
    fetch_live_weather_tool,
    verify_evidence_5layer_tool,
    parse_multilingual_voice_tool,
    compute_recovery_efficacy_tool
)

router = APIRouter(prefix="/adk", tags=["Google Agent Development Kit (ADK)"])

@router.get("/info", response_model=Dict[str, Any])
def get_adk_info():
    """Returns runtime telemetry verifying Google ADK multi-agent architecture."""
    return get_google_adk_system_info()

@router.get("/test-weather-tool", response_model=Dict[str, Any])
def test_adk_weather(district: str = "Ludhiana", crop: str = "Wheat"):
    """Executes the Google ADK Live Weather & Delta-T Tool."""
    return fetch_live_weather_tool(district=district, crop=crop)

@router.post("/test-validation-tool", response_model=Dict[str, Any])
def test_adk_validation(
    farm_id: str = "farm-104",
    crop_name: str = "Wheat (PBW 826)",
    product_name: str = "Tilt 25% EC",
    dosage_per_acre: str = "200 ml/Acre in 200L Water"
):
    """Executes the Google ADK 5-Layer Evidence Verification Tool."""
    return verify_evidence_5layer_tool(farm_id, crop_name, product_name, dosage_per_acre)
