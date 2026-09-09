import hashlib
import json
import re
import logging
from typing import Dict, Any, List, Optional, Tuple
from backend.app.models.schemas import (
    ValidationRequest,
    MultiAgentValidationRequest,
    ValidationResponse,
    ValidationFlag,
    VerificationStatus,
    GeoLocation
)
from backend.app.database.db import db

logger = logging.getLogger(__name__)

# Standard Agronomic Package Dosages & Constraints (PAU / ICAR baseline)
AGRONOMIC_KNOWLEDGE_BASE = {
    "bio-neem": {
        "standard_dose_ml_acre": 400.0,
        "max_safe_dose_ml_acre": 800.0,
        "dose_display": "400 ml/acre",
        "type": "Bio-Insecticide",
        "valid_crops": ["cotton", "wheat", "chilli", "tomato", "paddy", "vegetables"],
        "target_pests": ["whitefly", "aphids", "jassids", "thrips", "caterpillars", "bollworm"]
    },
    "bio-x": {
        "standard_dose_ml_acre": 1000.0, # 1 L/acre
        "max_safe_dose_ml_acre": 1500.0,
        "dose_display": "1 L/acre",
        "type": "Bio-Stimulant / Insecticide",
        "valid_crops": ["cotton", "wheat", "chilli", "paddy", "mustard"],
        "target_pests": ["whitefly", "sucking pests", "mildew", "foliar health"]
    },
    "tilt": {
        "standard_dose_ml_acre": 200.0, # Propiconazole 25% EC
        "max_safe_dose_ml_acre": 300.0,
        "dose_display": "200 ml/acre in 200L water",
        "type": "Fungicide",
        "valid_crops": ["wheat", "paddy", "barley", "groundnut"],
        "target_pests": ["yellow rust", "stripe rust", "brown rust", "karnal bunt", "sheath blight"]
    },
    "propiconazole": {
        "standard_dose_ml_acre": 200.0,
        "max_safe_dose_ml_acre": 300.0,
        "dose_display": "200 ml/acre in 200L water",
        "type": "Fungicide",
        "valid_crops": ["wheat", "paddy", "barley"],
        "target_pests": ["yellow rust", "stripe rust", "leaf rust", "sheath blight"]
    },
    "pegasus": {
        "standard_dose_ml_acre": 300.0, # Diafenthiuron 50% WP (300g / acre)
        "max_safe_dose_ml_acre": 450.0,
        "dose_display": "300 g/acre (1.5 g/L in 200L water)",
        "type": "Insecticide / Acaricide",
        "valid_crops": ["cotton", "chilli", "cabbage", "brinjal"],
        "target_pests": ["whitefly", "mites", "thrips", "aphids"]
    },
    "coragen": {
        "standard_dose_ml_acre": 60.0, # Chlorantraniliprole 18.5% SC
        "max_safe_dose_ml_acre": 100.0,
        "dose_display": "60 ml/acre in 200L water",
        "type": "Insecticide",
        "valid_crops": ["paddy", "sugarcane", "cotton", "maize", "tomato"],
        "target_pests": ["stem borer", "leaf folder", "bollworm", "fruit borer"]
    }
}

class ValidationAgent:
    """
    Agent #4: Trust & Validation Agent
    Performs multi-agent cross-verification (NLP Output + Vision Output + Weather Output),
    detects anomalies/conflicts (dose mismatch, crop/pest mismatch, adverse weather drift),
    calculates completeness score, and generates cryptographic tamper-evident proof seals.
    """

    def validate_multi_agent(self, request: MultiAgentValidationRequest) -> ValidationResponse:
        flags: List[ValidationFlag] = []
        anomalies: List[str] = []
        scores: Dict[str, float] = {}

        nlp = request.nlp_output or {}
        vision = request.vision_output or {}
        weather = request.weather_output or {}
        loc = request.location
        farm_id = request.farm_id or "farm-101"

        # ----------------------------------------------------------------------
        # 1. DOSAGE CONSISTENCY & OVERDOSE CHECK
        # ----------------------------------------------------------------------
        nlp_dose_raw = str(nlp.get("dosage") or nlp.get("dosage_per_acre") or "").strip()
        vision_dose_raw = str(vision.get("label_dosage") or vision.get("recommended_dosage") or vision.get("dosage") or "").strip()
        nlp_product = str(nlp.get("product_mentioned") or nlp.get("product_name") or "").strip()
        vision_product = str(vision.get("product_name") or vision.get("recommended_active_ingredient") or "").strip()

        nlp_dose_val, nlp_dose_unit = self._parse_dose_value(nlp_dose_raw)
        vision_dose_val, vision_dose_unit = self._parse_dose_value(vision_dose_raw)

        # Lookup standard agronomic database if available
        matched_db_product = self._match_known_product(nlp_product or vision_product)

        # Compare NLP vs Vision Label Dose
        if nlp_dose_val is not None and vision_dose_val is not None:
            # Normalize to same unit comparison if possible (L vs ml, kg vs g)
            norm_nlp = self._normalize_to_ml_or_g(nlp_dose_val, nlp_dose_unit)
            norm_vision = self._normalize_to_ml_or_g(vision_dose_val, vision_dose_unit)

            if abs(norm_nlp - norm_vision) / max(norm_vision, 1.0) > 0.25:
                # Discrepancy > 25%
                msg = f"Recorded dose ({nlp_dose_raw or f'{nlp_dose_val} {nlp_dose_unit}'}) differs from visible product-label dose ({vision_dose_raw or f'{vision_dose_val} {vision_dose_unit}'})."
                flags.append(ValidationFlag(type="dose_mismatch", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["dose_consistency"] = 65.0
            else:
                scores["dose_consistency"] = 98.0
        elif nlp_dose_val is not None and matched_db_product:
            norm_nlp = self._normalize_to_ml_or_g(nlp_dose_val, nlp_dose_unit)
            std_dose = matched_db_product["standard_dose_ml_acre"]
            max_safe = matched_db_product["max_safe_dose_ml_acre"]

            if norm_nlp > max_safe:
                msg = f"Recorded dose ({nlp_dose_raw}) exceeds maximum safe threshold ({matched_db_product['dose_display']}) for {nlp_product}."
                flags.append(ValidationFlag(type="overdose_warning", message=msg, severity="critical"))
                anomalies.append(msg)
                scores["dose_consistency"] = 55.0
            elif abs(norm_nlp - std_dose) / std_dose > 0.40:
                msg = f"Recorded dose ({nlp_dose_raw}) varies from standard package recommendation ({matched_db_product['dose_display']})."
                flags.append(ValidationFlag(type="dose_mismatch", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["dose_consistency"] = 75.0
            else:
                scores["dose_consistency"] = 96.0
        else:
            scores["dose_consistency"] = 90.0

        # ----------------------------------------------------------------------
        # 2. CROP & PATHOGEN / CHEMICAL COMPATIBILITY CHECK
        # ----------------------------------------------------------------------
        nlp_crop = str(nlp.get("crop") or request.crop_name or "").lower().strip()
        vision_crop = str(vision.get("crop_detected") or "").lower().strip()
        nlp_pest = str(nlp.get("target_pest") or "").lower().strip()
        vision_disease = str(vision.get("disease_detected") or "").lower().strip()

        # Check crop mismatch between voice and camera
        if nlp_crop and vision_crop and vision_crop != "auto-detect" and vision_crop != "unknown crop":
            clean_nlp_crop = re.sub(r'\(.*?\)', '', nlp_crop).strip()
            clean_vis_crop = re.sub(r'\(.*?\)', '', vision_crop).strip()
            if clean_nlp_crop and clean_vis_crop and clean_nlp_crop not in clean_vis_crop and clean_vis_crop not in clean_nlp_crop:
                msg = f"Voice log specified crop as '{nlp_crop.title()}', but vision diagnosis detected '{vision_crop.title()}'."
                flags.append(ValidationFlag(type="crop_mismatch", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["crop_alignment"] = 60.0
            else:
                scores["crop_alignment"] = 98.0
        else:
            scores["crop_alignment"] = 95.0

        # Check pest vs crop plausibility
        if matched_db_product and (nlp_crop or vision_crop):
            active_crop = nlp_crop or vision_crop
            valid_crops = matched_db_product.get("valid_crops", [])
            if valid_crops and not any(vc in active_crop for vc in valid_crops):
                msg = f"Product '{nlp_product or vision_product}' is not recommended for crop '{active_crop.title()}' (Registered for: {', '.join(valid_crops).title()})."
                flags.append(ValidationFlag(type="crop_product_mismatch", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["product_suitability"] = 65.0
            else:
                scores["product_suitability"] = 98.0
        else:
            scores["product_suitability"] = 92.0

        # Check fungicide vs insect pest mismatch
        active_pest = nlp_pest or vision_disease
        if matched_db_product and active_pest:
            prod_type = matched_db_product.get("type", "")
            if "Fungicide" in prod_type and any(i in active_pest for i in ["whitefly", "bollworm", "aphid", "thrips", "caterpillar", "borer"]):
                msg = f"Chemical '{nlp_product or vision_product}' is a Fungicide, but target pathogen '{active_pest.title()}' is an insect pest."
                flags.append(ValidationFlag(type="chemical_pest_incompatibility", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["pathogen_alignment"] = 50.0
            elif "Insecticide" in prod_type and any(f in active_pest for f in ["rust", "blight", "mildew", "rot", "scab", "smut"]):
                msg = f"Chemical '{nlp_product or vision_product}' is an Insecticide, but target disease '{active_pest.title()}' is a fungal pathogen."
                flags.append(ValidationFlag(type="chemical_pest_incompatibility", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["pathogen_alignment"] = 50.0
            else:
                scores["pathogen_alignment"] = 97.0
        else:
            scores["pathogen_alignment"] = 95.0

        # ----------------------------------------------------------------------
        # 3. WEATHER PLAUSIBILITY & DRIFT SAFETY CHECK
        # ----------------------------------------------------------------------
        w_temp = self._extract_float(weather.get("temperature_c") or weather.get("temp") or nlp.get("temperature_c"))
        w_wind = self._extract_float(weather.get("wind_speed_kmh") or weather.get("wind_kmh") or weather.get("wind"))
        w_precip = self._extract_float(weather.get("precipitation_prob") or weather.get("rain_prob"))
        w_delta_t = self._extract_float(weather.get("delta_t_c") or weather.get("delta_t"))

        weather_score = 98.0
        if w_wind is not None and w_wind > 15.0:
            msg = f"Wind speed ({w_wind} km/h) exceeds the safe spraying limit (15.0 km/h) — high drift risk."
            flags.append(ValidationFlag(type="weather_spray_conflict", message=msg, severity="warning"))
            anomalies.append(msg)
            weather_score -= 25.0

        if w_precip is not None and w_precip > 50.0:
            msg = f"High rain probability ({int(w_precip)}%) within application window — risk of chemical wash-off."
            flags.append(ValidationFlag(type="washoff_risk", message=msg, severity="warning"))
            anomalies.append(msg)
            weather_score -= 20.0

        if w_delta_t is not None:
            if w_delta_t > 8.0:
                msg = f"Delta-T ({w_delta_t}°C) is above optimal window (2.0–8.0°C) — spray droplets prone to rapid evaporation."
                flags.append(ValidationFlag(type="evaporation_risk", message=msg, severity="warning"))
                anomalies.append(msg)
                weather_score -= 15.0
            elif w_delta_t < 2.0 and w_delta_t > 0:
                msg = f"Delta-T ({w_delta_t}°C) is below 2.0°C — risk of inversion drift."
                flags.append(ValidationFlag(type="inversion_risk", message=msg, severity="warning"))
                anomalies.append(msg)
                weather_score -= 15.0

        scores["weather_plausibility"] = max(40.0, weather_score)

        # ----------------------------------------------------------------------
        # 4. GEO-FENCE & CERTIFIED LOT AUTHENTICITY
        # ----------------------------------------------------------------------
        farm = db.get_farm_by_id(farm_id)
        if farm and loc and loc.latitude is not None and loc.longitude is not None:
            lat_diff = abs(farm["latitude"] - loc.latitude)
            lon_diff = abs(farm["longitude"] - loc.longitude)
            if lat_diff < 0.05 and lon_diff < 0.05:
                scores["geo_fence_match"] = 98.0
            else:
                msg = f"GPS location ({loc.latitude:.4f}, {loc.longitude:.4f}) deviates from registered farm boundary ({farm['latitude']:.4f}, {farm['longitude']:.4f})."
                flags.append(ValidationFlag(type="geo_fence_deviation", message=msg, severity="warning"))
                anomalies.append(msg)
                scores["geo_fence_match"] = 60.0
        else:
            scores["geo_fence_match"] = 95.0

        # Product QR / Batch check if present
        product_data = request.product_data or {}
        qr = product_data.get("qr_code") or vision.get("qr_code")
        if qr:
            product = db.find_product_by_code(qr)
            if product:
                scores["product_authenticity"] = 100.0
            else:
                msg = f"Scanned QR Code '{qr}' not found in certified manufacturer batch database."
                flags.append(ValidationFlag(type="unverified_batch_qr", message=msg, severity="critical"))
                anomalies.append(msg)
                scores["product_authenticity"] = 40.0
        else:
            scores["product_authenticity"] = 95.0

        # ----------------------------------------------------------------------
        # 5. COMPLETENESS SCORE CALCULATION (0.0 to 1.0)
        # ----------------------------------------------------------------------
        mandatory_elements = [
            bool(nlp_crop or vision_crop or request.crop_name),
            bool(nlp.get("action_type") or "spray"),
            bool(nlp_product or vision_product),
            bool(nlp_dose_raw or vision_dose_raw),
            bool(request.timestamp or nlp.get("observation_time")),
            bool(loc or farm_id),
            bool(nlp.get("raw_transcript") or vision.get("disease_detected") or request.observation_data)
        ]
        present_count = sum(1 for m in mandatory_elements if m)
        completeness_score = round(present_count / len(mandatory_elements), 2)

        # ----------------------------------------------------------------------
        # 6. COMPOSITE TRUST SCORE & VERDICT RESOLUTION
        # ----------------------------------------------------------------------
        composite_score = sum(scores.values()) / max(len(scores), 1)

        # Deduct penalties for flags
        if flags:
            critical_flags = [f for f in flags if f.severity == "critical"]
            warning_flags = [f for f in flags if f.severity == "warning"]
            composite_score -= (len(critical_flags) * 20.0 + len(warning_flags) * 8.0)
            composite_score = max(35.0, min(100.0, composite_score))

        # Determine validation_status, consistency_status, and required_action
        has_critical = any(f.severity == "critical" for f in flags)
        has_warning = any(f.severity == "warning" for f in flags)

        if not flags and completeness_score >= 0.85 and composite_score >= 85.0:
            validation_status = "validated"
            consistency_status = "consistent"
            required_action = "none"
            verif_status = VerificationStatus.VERIFIED
            explanation = "Evidence meets multi-factor verification criteria: Consistent dosage, verified crop context, and compliant weather."
        elif has_critical or composite_score < 60.0:
            validation_status = "rejected"
            consistency_status = "failed"
            required_action = "field_agent_review" if has_critical else "re_record"
            verif_status = VerificationStatus.FLAGGED
            explanation = "Flagged: Critical validation anomalies detected across agent outputs."
        else:
            validation_status = "needs_review"
            consistency_status = "warning"
            required_action = "user_confirmation"
            verif_status = VerificationStatus.PENDING
            explanation = f"Requires confirmation due to {len(flags)} detected cross-agent variance(s)."

        # ----------------------------------------------------------------------
        # 7. CRYPTOGRAPHIC SHA-256 PROOF ANCHOR
        # ----------------------------------------------------------------------
        ev_id = request.evidence_id or f"EV-{farm_id}-{nlp_crop or 'GEN'}-{int(composite_score)}"
        ts = request.timestamp or "2026-09-04T00:00:00Z"
        hash_payload = f"{ev_id}:{farm_id}:{ts}:{validation_status}:{composite_score:.2f}:{len(flags)}"
        signature = hashlib.sha256(hash_payload.encode('utf-8')).hexdigest()

        return ValidationResponse(
            validation_status=validation_status,
            completeness_score=completeness_score,
            consistency_status=consistency_status,
            flags=flags,
            required_action=required_action,
            evidence_id=ev_id,
            status=verif_status,
            composite_score=round(composite_score, 1),
            composite_trust_score=round(composite_score, 1),
            hash_signature=signature,
            cryptographic_hash=signature,
            breakdown={k: round(v / 100.0, 2) for k, v in scores.items()},
            explanation=explanation,
            anomalies=anomalies
        )

    def validate_evidence(self, request: ValidationRequest) -> ValidationResponse:
        """
        Legacy adapter endpoint for single EvidenceItem validation
        """
        multi_req = MultiAgentValidationRequest(
            evidence_id=request.evidence_id,
            farm_id=request.farm_id,
            crop_name=request.crop_name,
            timestamp=request.timestamp,
            location=request.location,
            nlp_output=request.nlp_output or request.observation_data,
            vision_output=request.vision_output or request.product_data,
            weather_output=request.weather_output,
            product_data=request.product_data,
            observation_data=request.observation_data
        )
        return self.validate_multi_agent(multi_req)

    # --------------------------------------------------------------------------
    # HELPER PARSERS & MATCHER UTILITIES
    # --------------------------------------------------------------------------
    def _parse_dose_value(self, dose_str: str) -> Tuple[Optional[float], Optional[str]]:
        if not dose_str:
            return None, None
        
        cleaned = dose_str.lower().replace(",", ".")
        # Match patterns like "2 L/acre", "400 ml", "1.5 g/L", "1000ml"
        match = re.search(r'([0-9]+(?:\.[0-9]+)?)\s*(l(?:iter|iters)?|ml|g|gm|kg|kg/acre|l/acre|ml/acre)?', cleaned)
        if match:
            val = float(match.group(1))
            unit = match.group(2) or ("l" if "l" in cleaned else "ml")
            return val, unit
        return None, None

    def _normalize_to_ml_or_g(self, val: float, unit: Optional[str]) -> float:
        if not unit:
            return val
        u = unit.lower()
        if "l" in u and "ml" not in u: # Liters -> Milliliters
            return val * 1000.0
        if "kg" in u: # Kilograms -> Grams
            return val * 1000.0
        return val

    def _match_known_product(self, name: str) -> Optional[Dict[str, Any]]:
        if not name:
            return None
        n = name.lower()
        for k, v in AGRONOMIC_KNOWLEDGE_BASE.items():
            if k in n:
                return v
        return None

    def _extract_float(self, val: Any) -> Optional[float]:
        if val is None:
            return None
        try:
            return float(val)
        except (ValueError, TypeError):
            return None

validation_agent = ValidationAgent()
