"""
PRAMAAN Orchestrator REST API Routes.
Exposes multi-agent orchestration, execution graph planning, state inspection, and human-in-the-loop resumption.
"""

from typing import Dict, Any, Optional
from fastapi import APIRouter, HTTPException, status
from backend.app.models.schemas import ChatQueryRequest, ChatQueryResponse
from backend.app.ai.orchestrator import orchestrator_agent
from backend.app.orchestrator.state import (
    OrchestratorRequest,
    OrchestratorResponse,
    ExecutionPlan,
)
from backend.app.orchestrator.root_agent import master_orchestrator

router = APIRouter(prefix="/orchestrator", tags=["Orchestrator & Multi-Agent Brain"])


@router.post("/process", response_model=OrchestratorResponse, summary="Execute Multi-Agent Orchestration")
async def process_orchestrator_request(request: OrchestratorRequest):
    """
    Primary multi-agent entrypoint:
    1. Understands intent (Create record, product analysis, report, etc.)
    2. Executes independent agents in parallel (NLP, Vision, Weather)
    3. Evaluates validation gate
    4. Executes sequential pipeline (Efficacy analytics, Evidence report)
    5. Returns unified persona-aware output for Flutter/Web
    """
    try:
        return await master_orchestrator.process(request)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Orchestrator execution error: {str(e)}"
        )


@router.post("/plan", response_model=ExecutionPlan, summary="Preview Execution Plan")
def preview_execution_plan(request: OrchestratorRequest):
    """Returns the intent and parallel/sequential execution graph without executing the sub-agents."""
    return master_orchestrator.get_plan(request)


@router.get("/state/{record_id}", summary="Inspect Shared Field Evidence State")
def get_shared_evidence_state(record_id: str):
    """Retrieves full namespaced shared state for a given field record ID."""
    state = master_orchestrator.get_state(record_id)
    if not state:
        raise HTTPException(status_code=404, detail=f"Record state for {record_id} not found.")
    return state


@router.post("/resume", response_model=OrchestratorResponse, summary="Human-in-the-loop Resume Workflow")
async def resume_workflow_with_correction(payload: Dict[str, Any]):
    """
    Resumes a paused workflow after the farmer provides missing or corrected parameters.
    """
    record_id = payload.get("record_id")
    if not record_id:
        raise HTTPException(status_code=400, detail="Missing required field: 'record_id'")
    return await master_orchestrator.resume_workflow(record_id, payload)


@router.post("/chat", response_model=ChatQueryResponse, summary="Ask Pramaan Conversational Agronomy")
def ask_pramaan_chat(request: ChatQueryRequest):
    """Backward-compatible AI Agronomy & Microclimate Assistant."""
    return orchestrator_agent.handle_chat_query(request)
