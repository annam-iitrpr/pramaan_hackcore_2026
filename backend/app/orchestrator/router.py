"""
PRAMAAN Intent Detection & Execution Planning Router.
Determines user intent from multi-modal inputs and produces optimized parallel & sequential execution graphs.
"""

import logging
from typing import Dict, Any, List, Optional
from backend.app.orchestrator.state import IntentType, ExecutionPlan, OrchestratorRequest
from backend.app.core.config import settings

logger = logging.getLogger(__name__)


class OrchestratorRouter:
    """Classifies user intent and builds agent execution plans."""

    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY

    def detect_intent(self, request: OrchestratorRequest) -> IntentType:
        """
        Classifies the intent based on multi-modal payload (voice/text, images, hints).
        Uses deterministic heuristic rule engine first for instant sub-millisecond classification.
        """
        raw_text = (request.input or "").strip().lower()
        has_images = len(request.images) > 0

        # 1. Direct explicit override if provided in metadata
        if request.metadata and "intent" in request.metadata:
            try:
                return IntentType(request.metadata["intent"])
            except ValueError:
                pass

        # 2. Product Comparison / Efficacy Analytics Intent
        analytics_keywords = [
            "compare", "efficacy", "performance", "how did", "how bio", "vs", "versus",
            "stat", "anova", "yield impact", "result of", "तुलना", "कामगिरी", "प्रभाव"
        ]
        if any(k in raw_text for k in analytics_keywords) and not ("sprayed" in raw_text or "applied" in raw_text or "फवारले" in raw_text or "छिड़का" in raw_text):
            return IntentType.ANALYZE_PRODUCT

        # 3. Report Generation Intent
        report_keywords = ["generate report", "download pdf", "audit report", "evidence report", "प्रमाणपत्र", "अहवाल"]
        if any(k in raw_text for k in report_keywords):
            return IntentType.GENERATE_REPORT

        # 4. Field Status / Weather Check Intent
        status_keywords = ["weather today", "can i spray", "wind speed", "delta-t", "spray window", "हवामान", "मौसम", "ਛਿੜਕਾਅ"]
        if any(k in raw_text for k in status_keywords) and not ("sprayed" in raw_text or "i have sprayed" in raw_text or "फवारले" in raw_text or "छिड़का" in raw_text):
            return IntentType.CHECK_FIELD_STATUS

        # 5. History / Past Records
        history_keywords = ["history", "past logs", "previous sprays", "मागील रेकॉर्ड", "पुराना रिकॉर्ड"]
        if any(k in raw_text for k in history_keywords):
            return IntentType.VIEW_HISTORY

        # 6. Follow-up Observation (Post-treatment observation)
        obs_keywords = ["observed", "observation", "leaf recovery", "yellowing reduced", "whitefly dead", "तपासणी", "निरीक्षण", "कीड कमी"]
        if any(k in raw_text for k in obs_keywords) and not ("sprayed" in raw_text or "फवारले" in raw_text or "छिड़का" in raw_text):
            return IntentType.ADD_OBSERVATION

        # 7. Image-only upload without text
        if has_images and not raw_text:
            return IntentType.UPLOAD_EVIDENCE

        # 8. Update / Correction of existing record
        if request.record_id and ("correct" in raw_text or "update" in raw_text or "change" in raw_text or "बदल" in raw_text):
            return IntentType.UPDATE_FIELD_RECORD

        # 9. Default: Primary Field Application Recording (Voice / Text log)
        return IntentType.CREATE_FIELD_RECORD

    def create_execution_plan(self, intent: IntentType, request: OrchestratorRequest) -> ExecutionPlan:
        """
        Builds the parallel + sequential agent execution graph for the given intent.
        Ensures independent agents run in parallel while dependencies wait for required inputs.
        """
        has_images = len(request.images) > 0
        has_text_or_audio = bool(request.input and request.input.strip())

        if intent == IntentType.CREATE_FIELD_RECORD:
            # Parallel: NLP + Vision (if images) + Weather
            parallel = []
            if has_text_or_audio:
                parallel.append("NLP")
            if has_images:
                parallel.append("VISION")
            # Weather is ingested in parallel for microclimate grounding
            parallel.append("WEATHER")

            # Sequential: Validation -> Efficacy -> Report
            sequential = ["VALIDATION", "EFFICACY", "REPORT"]
            required = parallel + sequential

            return ExecutionPlan(
                workflow=intent,
                required_agents=required,
                parallel_steps=parallel,
                sequential_steps=sequential,
                rationale="Ingests NLP voice transcript, image evidence, and weather telemetry concurrently in parallel, then sequentially validates evidence and computes efficacy."
            )

        elif intent == IntentType.ANALYZE_PRODUCT:
            parallel = ["NLP"] if has_text_or_audio else []
            sequential = ["EFFICACY", "REPORT"]
            return ExecutionPlan(
                workflow=intent,
                required_agents=parallel + sequential,
                parallel_steps=parallel,
                sequential_steps=sequential,
                rationale="Executes statistical efficacy comparison across validated field evidence records."
            )

        elif intent == IntentType.GENERATE_REPORT:
            return ExecutionPlan(
                workflow=intent,
                required_agents=["REPORT"],
                parallel_steps=[],
                sequential_steps=["REPORT"],
                rationale="Generates multi-lingual compliance audit report from existing verified state."
            )

        elif intent == IntentType.CHECK_FIELD_STATUS:
            return ExecutionPlan(
                workflow=intent,
                required_agents=["WEATHER", "REPORT"],
                parallel_steps=["WEATHER"],
                sequential_steps=["REPORT"],
                rationale="Retrieves real-time Delta-T and spray window safety advisory."
            )

        elif intent == IntentType.UPLOAD_EVIDENCE:
            parallel = ["VISION"]
            sequential = ["VALIDATION", "REPORT"]
            return ExecutionPlan(
                workflow=intent,
                required_agents=parallel + sequential,
                parallel_steps=parallel,
                sequential_steps=sequential,
                rationale="Extracts visual crop pathology & QR evidence, then validates against geo-location."
            )

        elif intent == IntentType.ADD_OBSERVATION:
            parallel = ["NLP"] if has_text_or_audio else []
            if has_images:
                parallel.append("VISION")
            sequential = ["VALIDATION", "EFFICACY", "REPORT"]
            return ExecutionPlan(
                workflow=intent,
                required_agents=parallel + sequential,
                parallel_steps=parallel,
                sequential_steps=sequential,
                rationale="Appends post-application vitality observation and recalculates canopy recovery ROI."
            )

        else:  # Fallback / UPDATE_FIELD_RECORD / VIEW_HISTORY
            parallel = ["NLP"] if has_text_or_audio else []
            sequential = ["VALIDATION", "REPORT"]
            return ExecutionPlan(
                workflow=intent,
                required_agents=parallel + sequential,
                parallel_steps=parallel,
                sequential_steps=sequential,
                rationale="Updates existing record and re-validates cryptographic signature."
            )


router = OrchestratorRouter()
