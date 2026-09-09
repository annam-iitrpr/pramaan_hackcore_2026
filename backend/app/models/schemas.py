from pydantic import BaseModel, Field
from typing import List, Optional, Dict,Literal, Any
from enum import Enum
from datetime import datetime



class EvidenceType(str, Enum):
    VOICE_LOG = "VOICE_LOG"
    CROP_IMAGE = "CROP_IMAGE"
    PRODUCT_SCAN = "PRODUCT_SCAN"
    FIELD_OBSERVATION = "FIELD_OBSERVATION"
    APPLICATION_LOG = "APPLICATION_LOG"

class VerificationStatus(str, Enum):
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    FLAGGED = "FLAGGED"
    REJECTED = "REJECTED"

class UserRole(str, Enum):
    FARMER = "FARMER"
    FIELD_AGENT = "FIELD_AGENT"
    BUYER = "BUYER"

# Location & Environment Metadata
class GeoLocation(BaseModel):
    latitude: float
    longitude: float
    accuracy_meters: Optional[float] = 5.0
    field_name: Optional[str] = "Plot North-04"
    village: Optional[str] = "Nashik Rural"

class WeatherSnapshot(BaseModel):
    temperature_c: float
    humidity_percent: float
    wind_speed_kmh: float
    precipitation_prob: float
    condition: str
    spray_suitability_score: float # 0.0 - 1.0 (1.0 = optimal)
    spray_recommendation: str
    apparent_temp_c: Optional[float] = None
    delta_t_c: Optional[float] = None
    dew_point_c: Optional[float] = None
    wind_gusts_kmh: Optional[float] = None
    cloud_cover_percent: Optional[float] = None
    soil_moisture_percent: Optional[float] = None
    location_name: Optional[str] = "Punjab Central Agri-Zone"
    district_name: Optional[str] = "Ludhiana"
    state_name: Optional[str] = "Punjab"
    is_punjab_region: bool = True
    pau_advisory_text: Optional[str] = None


# Evidence Item Model
class EvidenceItem(BaseModel):
    id: str
    farm_id: str
    crop_name: str
    crop_stage: str
    evidence_type: EvidenceType
    timestamp: str
    location: GeoLocation
    weather: Optional[WeatherSnapshot] = None
    title: str
    description: str
    media_url: Optional[str] = None
    audio_transcript: Optional[str] = None
    product_qr: Optional[str] = None
    product_name: Optional[str] = None
    dosage_per_acre: Optional[str] = None
    verification_status: VerificationStatus = VerificationStatus.PENDING
    verification_score: float = 0.0 # 0.0 to 100.0
    verification_hash: Optional[str] = None
    agent_verdicts: Dict[str, Any] = Field(default_factory=dict)
    flag_reasons: List[str] = Field(default_factory=list)

# Voice Parsing Request & Result
class VoiceLogRequest(BaseModel):
    audio_base64: Optional[str] = None

    audio_transcript: Optional[str] = None

    language: str = "hi"

    farm_id: str

    latitude: Optional[float] = None

    longitude: Optional[float] = None

class VoiceLogResponse(BaseModel):
    raw_transcript: str

    detected_language: str

    crop: Optional[str] = None

    action_type: Optional[str] = None

    product_mentioned: Optional[str] = None

    dosage: Optional[str] = None

    target_pest: Optional[str] = None

    plot_name: Optional[str] = None

    observation_time: Optional[str] = None

    confidence_score: float = Field(
        ge=0.0,
        le=1.0,
    )

    missing_information: List[str] = Field(
        default_factory=list
    )

    ambiguous_information: List[str] = Field(
        default_factory=list
    )

    needs_clarification: bool = False

    clarification_question: Optional[str] = None

    extracted_entities: Dict[str, Any] = Field(
        default_factory=dict
    )
# Vision Analysis Request & Result
class VisionAnalysisRequest(BaseModel):
    image_base64: Optional[str] = None
    image_url: Optional[str] = None
    crop_type: Optional[str] = "Auto-Detect"
    plot_id: Optional[str] = "plot-01"




class VisionAnalysisResponse(BaseModel):

    crop_detected: str

    scientific_name: str

    crop_stage: str

    disease_detected: str

    health_status: Literal[
        "Healthy Crop",
        "Diseased",
        "Pest Infested",
        "Nutrient Deficient",
        "Stressed",
        "Uncertain",
    ]

    confidence: float = Field(
        ge=0.0,
        le=1.0,
    )

    severity_level: Literal[
        "Low",
        "Medium",
        "High",
        "Critical",
        "Unknown",
    ]

    pest_count_estimate: Optional[int] = None

    affected_percentage: Optional[float] = Field(
        default=None,
        ge=0.0,
        le=100.0,
    )

    symptoms: List[str] = []

    visual_evidence: List[str] = []

    analysis_notes: str = ""

    recommended_active_ingredient: str

    organic_alternative: str

    urgency_days: Optional[int] = None

    treatment_advice: str

    prevention_tips: List[str] = []

    analysis_source: Literal[
        "gemini",
        "heuristic",
        "image_quality_gate",
        "system",
    ] = "system"

    requires_confirmation: bool = True

# Validation Agent Models
class ValidationFlag(BaseModel):
    type: str  # e.g. "dose_mismatch", "crop_pest_mismatch", "weather_spray_conflict", "product_mismatch", "geo_fence_deviation"
    message: str
    severity: Optional[str] = "warning"  # "warning", "critical", "info"

class MultiAgentValidationRequest(BaseModel):
    evidence_id: Optional[str] = None
    farm_id: Optional[str] = "farm-101"
    crop_name: Optional[str] = None
    timestamp: Optional[str] = None
    location: Optional[GeoLocation] = None
    nlp_output: Optional[Dict[str, Any]] = None
    vision_output: Optional[Dict[str, Any]] = None
    weather_output: Optional[Dict[str, Any]] = None
    product_data: Optional[Dict[str, Any]] = None
    observation_data: Optional[Dict[str, Any]] = None

class ValidationRequest(BaseModel):
    evidence_id: str
    farm_id: str
    evidence_type: EvidenceType
    timestamp: str
    location: GeoLocation
    crop_name: str
    product_data: Optional[Dict[str, Any]] = None
    observation_data: Optional[Dict[str, Any]] = None
    nlp_output: Optional[Dict[str, Any]] = None
    vision_output: Optional[Dict[str, Any]] = None
    weather_output: Optional[Dict[str, Any]] = None

class ValidationResponse(BaseModel):
    validation_status: str = "validated"  # "validated", "needs_review", "rejected"
    completeness_score: float = 1.0  # 0.0 to 1.0
    consistency_status: str = "consistent"  # "consistent", "warning", "failed"
    flags: List[ValidationFlag] = Field(default_factory=list)
    required_action: str = "none"  # "none", "user_confirmation", "field_agent_review", "re_record"
    
    # Extended & Compatibility fields
    evidence_id: Optional[str] = None
    status: VerificationStatus = VerificationStatus.VERIFIED
    composite_score: float = 95.0  # 0.0 to 100.0
    composite_trust_score: float = 95.0
    hash_signature: Optional[str] = None
    cryptographic_hash: Optional[str] = None
    breakdown: Dict[str, float] = Field(default_factory=dict)
    explanation: Optional[str] = None
    anomalies: List[str] = Field(default_factory=list)

# Efficacy Tracking Models
class EfficacyRequest(BaseModel):
    farm_id: str
    crop: str
    product_applied: str
    pre_application_evidence_id: str
    post_application_evidence_ids: List[str]

class EfficacyResponse(BaseModel):
    product_applied: str
    recovery_rate_percent: float # e.g. 84.5%
    pest_reduction_percent: float # e.g. 91.0%
    canopy_vitality_index: float # 0 - 1.0 (NDVI proxy)
    efficacy_rating: str # "Outstanding", "Standard", "Underperforming"
    days_elapsed: int
    economic_yield_gain_est_inr: float
    comparative_notes: str

# Weather & Spray Window Models
class WeatherAdvisoryRequest(BaseModel):
    latitude: Optional[float] = 30.9010
    longitude: Optional[float] = 75.8573
    district: Optional[str] = "Ludhiana"
    crop: Optional[str] = "Wheat (Kanak)"
    planned_chemical: Optional[str] = "Propiconazole 25% EC (Tilt)"

class SprayWindowSlot(BaseModel):
    time_window: str
    suitability: str # "OPTIMAL", "MODERATE", "DO_NOT_SPRAY"
    temperature_c: float
    wind_kmh: float
    rain_probability_percent: int
    advisory_reason: str
    delta_t_c: Optional[float] = None
    humidity_percent: Optional[float] = None

class PunjabDistrictInfo(BaseModel):
    id: str
    name: str
    punjabi_name: str
    latitude: float
    longitude: float
    agro_zone: str # Central Plain Zone, Western Zone (Malwa), Majha, Doaba, Undulating (Kandi)
    primary_crops: List[str]
    pau_station: str
    key_pest_risks: List[str]

class WeatherAdvisoryResponse(BaseModel):
    current_weather: WeatherSnapshot
    upcoming_windows: List[SprayWindowSlot]
    pest_pressure_forecast: str
    microclimate_alert: Optional[str] = None
    punjab_agro_zone: Optional[str] = "Central Plain Zone (PAU Ludhiana)"
    delta_t_status: Optional[str] = "OPTIMAL_SPRAY_WINDOW"


# Report Generation Models
class AuditReportRequest(BaseModel):
    farm_id: str
    crop: str
    season: str = "Kharif 2026"
    include_cryptographic_audit: bool = True
    buyer_name: Optional[str] = "ITC Agri-Business"
    voice_transcript: Optional[str] = None
    voice_action: Optional[str] = None
    product_applied: Optional[str] = None
    dosage: Optional[str] = None
    target_pest: Optional[str] = None
    plot_name: Optional[str] = "Plot North-04"
    disease_detected: Optional[str] = None
    health_status: Optional[str] = "Healthy Crop"
    severity_level: Optional[str] = "Low"
    affected_percentage: Optional[float] = 0.0
    weather_temp: Optional[float] = 28.5
    weather_humidity: Optional[float] = 68.0
    weather_wind: Optional[float] = 5.4
    weather_delta_t: Optional[float] = 3.6
    spray_suitability: Optional[str] = "OPTIMAL"
    spray_recommendation: Optional[str] = None

class AgronomyRecommendation(BaseModel):
    chemical_treatment: str
    chemical_dosage: str
    organic_alternative: str
    spray_window_advisory: str
    pre_harvest_interval_days: int
    safety_directives: List[str] = Field(default_factory=list)
    cultural_prevention_tips: List[str] = Field(default_factory=list)

class TrilingualReportContent(BaseModel):
    en: Dict[str, Any] = Field(default_factory=dict)
    hi: Dict[str, Any] = Field(default_factory=dict)
    mr: Dict[str, Any] = Field(default_factory=dict)

class AuditReportResponse(BaseModel):
    report_id: str
    farm_name: str
    crop: str
    total_evidence_count: int
    verified_evidence_count: int
    compliance_score_percent: float
    chemical_residue_risk: str # "Very Low (Organic Grade)", "Compliant / MRL Safe", "Borderline"
    sustainability_index: float # 0 - 100
    pdf_download_url: str
    json_manifest_url: str
    blockchain_hash_anchor: str
    generated_at: str
    pages_count: int = 3
    supported_languages: List[str] = ["English (Page 1)", "Hindi (Page 2)", "Marathi (Page 3)"]
    recommendations: Optional[AgronomyRecommendation] = None
    trilingual_data: Optional[TrilingualReportContent] = None
    mandi_base_price_per_qtl: Optional[float] = 7400.0
    pramaan_premium_per_qtl: Optional[float] = 450.0
    total_lot_value_inr: Optional[float] = 172700.0

# Buyer Pricing Models
class BuyerPricingRequest(BaseModel):
    crop: str
    quantity_quintals: float
    farm_id: str
    compliance_score: float

class BuyerPricingResponse(BaseModel):
    base_mandi_price_per_qtl: float
    pramaan_verified_premium_per_qtl: float
    total_rate_per_qtl: float
    total_lot_value_inr: float
    purity_grade: str # A+, A, B
    traceability_seal_url: str
    buyer_advantages: List[str]

# Ask Pramaan Chat
class ChatMessage(BaseModel):
    sender: str # "user" or "pramaan_ai"
    text: str
    timestamp: Optional[str] = None
    suggested_actions: Optional[List[str]] = None
    media_url: Optional[str] = None

class ChatQueryRequest(BaseModel):
    message: str
    crop_context: Optional[str] = "Cotton"
    farm_id: Optional[str] = "farm-101"
    language: Optional[str] = "en"

class ChatQueryResponse(BaseModel):
    reply: str
    audio_tts_url: Optional[str] = None
    citations: List[str] = Field(default_factory=list)
    action_chips: List[str] = Field(default_factory=list)
