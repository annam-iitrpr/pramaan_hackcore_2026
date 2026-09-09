from fastapi import APIRouter
from backend.app.models.schemas import VisionAnalysisRequest, VisionAnalysisResponse
from backend.app.ai.vision_agent import vision_agent

router = APIRouter(prefix="/vision", tags=["Vision Agent & Disease Diagnostics"])

@router.post("/analyze", response_model=VisionAnalysisResponse)
def analyze_crop_image(request: VisionAnalysisRequest):
    return vision_agent.analyze_crop_image(request)
