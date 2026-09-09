import logging
import requests
from typing import Dict, Any, Optional
from fastapi import APIRouter, Body
from pydantic import BaseModel
from backend.app.models.schemas import VoiceLogRequest, VoiceLogResponse
from backend.app.ai.voice_agent import voice_agent
from backend.app.database.db import db
from backend.app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voice", tags=["Voice Agent & Intent Parser"])

class FarmerLogSyncRequest(BaseModel):
    farmer_name: str
    farmer_phone: Optional[str] = "9876543210"
    village: Optional[str] = "Dindori, Nashik"
    state: Optional[str] = "Maharashtra"
    crop: str
    action_type: str
    product_name: Optional[str] = None
    dosage: Optional[str] = None
    target_pest: Optional[str] = None
    voice_transcript: str
    compliance_score: Optional[float] = 98.6
    verification_status: Optional[str] = "VERIFIED"
    report_id: Optional[str] = None
    hash_anchor: Optional[str] = None
    apps_script_url: Optional[str] = None

@router.post("/process", response_model=VoiceLogResponse)
def process_voice_note(request: VoiceLogRequest):
    return voice_agent.process_voice_transcript(request)

@router.post("/sync-sheet")
def sync_farmer_log_to_sheet(payload: FarmerLogSyncRequest):
    """
    Saves the farmer's voice log into the farmer's database account
    and pushes the row to Google Apps Script / Google Sheets.
    """
    record = payload.model_dump()
    
    # 1. Save to backend database
    db.add_evidence({
        "id": payload.report_id or f"EV-{payload.crop[:3].upper()}-{hash(payload.voice_transcript) % 10000}",
        "farm_id": "farm-101",
        "crop_name": payload.crop,
        "crop_stage": "Flowering Stage",
        "evidence_type": "VOICE_LOG",
        "timestamp": record.get("timestamp") or "2026-09-04T10:00:00Z",
        "location": {
            "latitude": 20.1985,
            "longitude": 73.8322,
            "fieldName": "Plot North-04",
            "village": payload.village
        },
        "title": f"Voice Log: {payload.action_type} {payload.crop}",
        "description": payload.voice_transcript,
        "audio_transcript": payload.voice_transcript,
        "product_name": payload.product_name,
        "dosage_per_acre": payload.dosage,
        "verification_status": payload.verification_status,
        "verification_score": payload.compliance_score,
        "verification_hash": payload.hash_anchor
    })

    # 2. Forward to Google Apps Script if URL provided
    sheet_synced = False
    script_url = payload.apps_script_url or getattr(settings, "GOOGLE_APPS_SCRIPT_URL", None)
    if script_url:
        try:
            resp = requests.post(script_url, json=record, timeout=5)
            sheet_synced = resp.status_code == 200
        except Exception as ex:
            logger.warning(f"Google Apps Script sync failed: {ex}")

    return {
        "status": "success",
        "message": "Farmer log saved to account successfully",
        "google_sheet_synced": sheet_synced,
        "record": record
    }
