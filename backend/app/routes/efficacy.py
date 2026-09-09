from fastapi import APIRouter
from backend.app.models.schemas import EfficacyRequest, EfficacyResponse
from backend.app.ai.efficacy_agent import efficacy_agent

router = APIRouter(prefix="/efficacy", tags=["Efficacy Agent & Recovery Analytics"])

@router.post("/compute", response_model=EfficacyResponse)
def compute_treatment_efficacy(request: EfficacyRequest):
    return efficacy_agent.compute_efficacy(request)
