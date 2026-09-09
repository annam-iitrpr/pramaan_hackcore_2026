from typing import List, Optional
from fastapi import APIRouter, Query
from backend.app.models.schemas import (
    WeatherAdvisoryRequest,
    WeatherAdvisoryResponse,
    PunjabDistrictInfo
)
from backend.app.ai.weather_agent import weather_agent

router = APIRouter(prefix="/weather", tags=["Weather Agent & Spray Windows"])

@router.post("/advisory", response_model=WeatherAdvisoryResponse)
def get_spray_advisory(request: WeatherAdvisoryRequest):
    return weather_agent.get_weather_advisory(request)

@router.get("/punjab-districts", response_model=List[PunjabDistrictInfo])
def get_all_punjab_districts():
    """Retrieve all verified Punjab agricultural districts with PAU agro-zones."""
    return weather_agent.get_punjab_districts()

@router.get("/punjab/district/{district_name}", response_model=WeatherAdvisoryResponse)
def get_district_weather(
    district_name: str,
    crop: Optional[str] = Query(default="Wheat (Kanak)")
):
    """Retrieve live real-time weather & spray advisory for a specific Punjab district."""
    district_info = weather_agent.resolve_punjab_district(0.0, 0.0, district_name)
    request = WeatherAdvisoryRequest(
        latitude=district_info["latitude"],
        longitude=district_info["longitude"],
        district=district_info["name"],
        crop=crop
    )
    return weather_agent.get_weather_advisory(request)
