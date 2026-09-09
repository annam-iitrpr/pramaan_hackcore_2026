"""
PRAMAAN Shared State & State Machine for Multi-Agent Orchestration.
Defines the working memory, agent contracts, intent models, and state transitions.
"""

from typing import Dict, Any, List, Optional
from enum import Enum
from datetime import datetime
from pydantic import BaseModel, Field


class WorkflowState(str, Enum):
    """11-step granular workflow lifecycle states."""
    CREATED = "CREATED"
    PROCESSING = "PROCESSING"
    STRUCTURED = "STRUCTURED"
    VALIDATING = "VALIDATING"
    NEEDS_REVIEW = "NEEDS_REVIEW"
    VALIDATED = "VALIDATED"
    STORED = "STORED"
    ANALYZING = "ANALYZING"
    ANALYZED = "ANALYZED"
    REPORT_GENERATED = "REPORT_GENERATED"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class IntentType(str, Enum):
    """Supported multi-agent intents."""
    CREATE_FIELD_RECORD = "CREATE_FIELD_RECORD"
    UPDATE_FIELD_RECORD = "UPDATE_FIELD_RECORD"
    ADD_OBSERVATION = "ADD_OBSERVATION"
    UPLOAD_EVIDENCE = "UPLOAD_EVIDENCE"
    CHECK_FIELD_STATUS = "CHECK_FIELD_STATUS"
    VIEW_HISTORY = "VIEW_HISTORY"
    ANALYZE_PRODUCT = "ANALYZE_PRODUCT"
    GENERATE_REPORT = "GENERATE_REPORT"


class AgentStatus(str, Enum):
    """Standardized execution status for every specialized agent."""
    PENDING = "PENDING"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    PARTIAL = "PARTIAL"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    UNAVAILABLE = "UNAVAILABLE"


class UserRole(str, Enum):
    """Target persona for role-aware output formatting."""
    FARMER = "FARMER"
    FIELD_AGENT = "FIELD_AGENT"
    ORGANIZATION = "ORGANIZATION"
    BUYER = "BUYER"


class AgentResult(BaseModel):
    """Fixed Agent Contract for all PRAMAAN specialized agents."""
    agent: str
    status: AgentStatus = AgentStatus.PENDING
    confidence: float = 1.0
    result: Dict[str, Any] = Field(default_factory=dict)
    warnings: List[str] = Field(default_factory=list)
    errors: List[str] = Field(default_factory=list)
    execution_time_ms: Optional[float] = None


class ExecutionPlan(BaseModel):
    """Execution graph created by Orchestrator Router."""
    workflow: IntentType
    required_agents: List[str]
    parallel_steps: List[str] = Field(default_factory=list)
    sequential_steps: List[str] = Field(default_factory=list)
    rationale: Optional[str] = None


class WorkflowContext(BaseModel):
    """Execution tracking and timeline."""
    status: WorkflowState = WorkflowState.CREATED
    current_intent: IntentType = IntentType.CREATE_FIELD_RECORD
    completed_agents: List[str] = Field(default_factory=list)
    failed_agents: List[str] = Field(default_factory=list)
    skipped_agents: List[str] = Field(default_factory=list)
    missing_fields: List[str] = Field(default_factory=list)
    clarification_prompt: Optional[str] = None
    next_action: Optional[str] = None
    started_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    completed_at: Optional[str] = None


class FieldEvidenceState(BaseModel):
    """
    The Shared Working Memory for the Orchestrator and all sub-agents.
    Every agent writes strictly into its own namespaced section.
    """
    record_id: str
    input: Dict[str, Any] = Field(default_factory=dict)
    nlp: Dict[str, Any] = Field(default_factory=dict)
    vision: Dict[str, Any] = Field(default_factory=dict)
    weather: Dict[str, Any] = Field(default_factory=dict)
    validation: Dict[str, Any] = Field(default_factory=dict)
    analytics: Dict[str, Any] = Field(default_factory=dict)
    report: Dict[str, Any] = Field(default_factory=dict)
    workflow: WorkflowContext = Field(default_factory=WorkflowContext)

    def to_dict(self) -> Dict[str, Any]:
        return self.model_dump()


class OrchestratorRequest(BaseModel):
    """Inbound request payload for the Orchestrator."""
    user_id: str = "F102"
    role: str = "farmer"
    language: str = "en"
    input_type: str = "voice"  # voice, text, image, mixed
    input: Optional[str] = None  # text message or voice transcript
    images: List[str] = Field(default_factory=list)  # paths or base64 or urls
    location: Optional[Dict[str, Any]] = None  # {latitude, longitude, village, state}
    timestamp: Optional[str] = None
    record_id: Optional[str] = None
    crop_hint: Optional[str] = None
    target_product: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class OrchestratorResponse(BaseModel):
    """Final unified response contract returned by the Orchestrator to Flutter and API consumers."""
    record_id: str
    workflow_status: str
    validation_status: str
    field_evidence: Dict[str, Any] = Field(default_factory=dict)
    weather_context: Dict[str, Any] = Field(default_factory=dict)
    evidence: Dict[str, Any] = Field(default_factory=dict)
    insight: Dict[str, Any] = Field(default_factory=dict)
    limitations: List[str] = Field(default_factory=list)
    farmer_message: str = ""
    role_view: Optional[Dict[str, Any]] = None
    clarification_required: bool = False
    clarification_question: Optional[str] = None
    execution_plan: Optional[Dict[str, Any]] = None
    shared_state_summary: Optional[Dict[str, Any]] = None
