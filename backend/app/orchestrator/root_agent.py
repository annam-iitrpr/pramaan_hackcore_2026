"""
PRAMAAN Root Master Orchestrator Agent.
The primary entrypoint for multi-agent coordination, state management, and human-in-the-loop workflows.
"""

import logging
from typing import Dict, Any, Optional
from backend.app.orchestrator.state import (
    OrchestratorRequest,
    OrchestratorResponse,
    FieldEvidenceState,
    ExecutionPlan,
    WorkflowState
)
from backend.app.orchestrator.router import router
from backend.app.orchestrator.workflow import workflow_engine

logger = logging.getLogger(__name__)


class PramaanMasterOrchestrator:
    """The central brain of PRAMAAN."""

    def __init__(self):
        # In-memory working state registry (keyed by record_id)
        self._state_store: Dict[str, FieldEvidenceState] = {}

    async def process(self, request: OrchestratorRequest) -> OrchestratorResponse:
        """Executes full multi-agent orchestration lifecycle."""
        response = await workflow_engine.execute(request)
        return response

    def get_plan(self, request: OrchestratorRequest) -> ExecutionPlan:
        """Returns the intent detection and parallel/sequential execution plan without running agents."""
        intent = router.detect_intent(request)
        return router.create_execution_plan(intent, request)

    def get_state(self, record_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves raw Field Evidence State for audit inspection."""
        state = self._state_store.get(record_id)
        return state.model_dump() if state else None

    async def resume_workflow(self, record_id: str, correction: Dict[str, Any]) -> OrchestratorResponse:
        """
        Human-in-the-loop: Resumes workflow after a farmer clarifies missing or flagged fields.
        """
        logger.info(f"[Orchestrator] Resuming workflow for record={record_id} with correction={correction}")
        
        req = OrchestratorRequest(
            record_id=record_id,
            user_id=correction.get("user_id", "F102"),
            role=correction.get("role", "farmer"),
            language=correction.get("language", "en"),
            input=correction.get("clarification_text") or correction.get("input"),
            crop_hint=correction.get("crop") or correction.get("crop_hint"),
            target_product=correction.get("product") or correction.get("target_product"),
            metadata={"resumed_from": record_id, "correction": correction}
        )
        return await self.process(req)


master_orchestrator = PramaanMasterOrchestrator()
