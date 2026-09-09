import base64
import io
import json
import logging
from typing import Any, Dict, List, Optional, Tuple

from backend.app.core.config import settings
from backend.app.models.schemas import (
    VisionAnalysisRequest,
    VisionAnalysisResponse,
)

logger = logging.getLogger(__name__)


# ============================================================
# GEMINI MODEL FALLBACK ORDER
# ============================================================

GEMINI_MODELS = [
    "gemini-3.1-flash-lite",
    "gemini-flash-lite-latest",
    "gemini-3.7-flash",
    "gemini-3.1-pro-preview",
    "gemini-3.6-flash",
    "gemini-3.5-flash-lite",
    "gemini-flash-latest",
]


# ============================================================
# SUPPORTED CROPS
# ============================================================

SUPPORTED_CROPS = {
    "cotton",
    "wheat",
    "tomato",
    "chilli",
    "paddy",
    "rice",
    "potato",
    "mustard",
    "sugarcane",
    "maize",
}


# ============================================================
# AGRONOMY KNOWLEDGE BASE
#
# IMPORTANT:
# Gemini identifies the visual condition.
# This knowledge base provides structured agronomic guidance.
#
# Do NOT allow the LLM to freely invent pesticide dosages.
# ============================================================

AGRONOMY_KB: Dict[str, Dict[str, Dict[str, Any]]] = {

    "cotton": {
        "cotton whitefly": {
            "recommended_active_ingredient": (
                "Use only locally approved whitefly management products "
                "according to the current label and agricultural advisory."
            ),
            "organic_alternative": (
                "Neem-based botanical management and yellow sticky traps "
                "may be considered as part of integrated pest management."
            ),
            "prevention_tips": [
                "Monitor the underside of leaves regularly.",
                "Remove alternate weed hosts around field borders.",
                "Use integrated pest management rather than repeated insecticide applications."
            ],
        }
    },

    "wheat": {
        "yellow rust": {
            "recommended_active_ingredient": (
                "Use a locally registered fungicide recommended for wheat "
                "yellow rust according to the product label and local agricultural advisory."
            ),
            "organic_alternative": (
                "Use resistant varieties and integrated disease-management practices."
            ),
            "prevention_tips": [
                "Monitor fields during cool and humid weather.",
                "Prefer locally recommended rust-resistant varieties."
            ],
        }
    },

    "tomato": {
        "early blight": {
            "recommended_active_ingredient": (
                "Use a locally registered fungicide recommended for tomato early blight "
                "according to the current label and agricultural advisory."
            ),
            "organic_alternative": (
                "Use sanitation, removal of heavily infected leaves, crop rotation, "
                "and approved biological disease-management products."
            ),
            "prevention_tips": [
                "Avoid prolonged leaf wetness and unnecessary overhead irrigation.",
                "Remove severely infected plant material from the field."
            ],
        }
    },

    "chilli": {
        "leaf curl": {
            "recommended_active_ingredient": (
                "Management should target the vector and follow locally approved "
                "integrated pest-management recommendations."
            ),
            "organic_alternative": (
                "Neem-based botanical products and approved sticky traps can be "
                "considered as part of integrated pest management."
            ),
            "prevention_tips": [
                "Monitor young leaves and terminal shoots frequently.",
                "Control vector populations using integrated pest-management practices."
            ],
        }
    },

    "paddy": {
        "leaf blast": {
            "recommended_active_ingredient": (
                "Use a locally registered rice blast-management fungicide "
                "according to the current label and local agricultural advisory."
            ),
            "organic_alternative": (
                "Use approved biological disease-management products and "
                "integrated crop-management practices."
            ),
            "prevention_tips": [
                "Avoid excessive nitrogen application.",
                "Monitor fields during prolonged humid conditions."
            ],
        }
    },

    "rice": {
        "leaf blast": {
            "recommended_active_ingredient": (
                "Use a locally registered rice blast-management fungicide "
                "according to the current label and local agricultural advisory."
            ),
            "organic_alternative": (
                "Use approved biological disease-management products and "
                "integrated crop-management practices."
            ),
            "prevention_tips": [
                "Avoid excessive nitrogen application.",
                "Monitor fields during prolonged humid conditions."
            ],
        }
    },

    "potato": {
        "late blight": {
            "recommended_active_ingredient": (
                "Use a locally registered potato late-blight management fungicide "
                "according to the current label and local agricultural advisory."
            ),
            "organic_alternative": (
                "Use approved copper-based or biological disease-management "
                "options where appropriate and permitted."
            ),
            "prevention_tips": [
                "Monitor crops closely during cool, wet and humid weather.",
                "Remove severely infected plant material according to local guidance."
            ],
        }
    },

    "mustard": {
        "aphid": {
            "recommended_active_ingredient": (
                "Use a locally registered mustard aphid-management product "
                "according to the current label and local agricultural advisory."
            ),
            "organic_alternative": (
                "Neem-based botanical management and conservation of natural "
                "aphid predators can be used as part of integrated pest management."
            ),
            "prevention_tips": [
                "Regularly inspect flowering and tender shoots.",
                "Conserve beneficial insects such as ladybird beetles."
            ],
        }
    },

    "sugarcane": {
        "red rot": {
            "recommended_active_ingredient": (
                "Management should follow local sugarcane disease-management "
                "recommendations and use only registered products where applicable."
            ),
            "organic_alternative": (
                "Use approved Trichoderma-based biological management and "
                "healthy planting material."
            ),
            "prevention_tips": [
                "Use healthy disease-free planting material.",
                "Remove severely infected clumps according to local recommendations."
            ],
        }
    },
}


# ============================================================
# IMAGE QUALITY ANALYSIS
# ============================================================

def assess_image_quality(
    raw_bytes: bytes,
) -> Tuple[bool, Dict[str, Any]]:
    """
    Performs basic image-quality checks before sending an image to Gemini.

    Checks:
    - image readability
    - minimum resolution
    - brightness
    - approximate blur

    Returns:
        (is_acceptable, quality_metadata)
    """

    try:
        from PIL import Image
        import numpy as np

        image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")

        width, height = image.size

        quality: Dict[str, Any] = {
            "width": width,
            "height": height,
            "resolution_ok": True,
            "brightness": None,
            "blur_score": None,
            "quality_status": "acceptable",
        }

        # ----------------------------------------------------
        # Resolution check
        # ----------------------------------------------------

        if width < 224 or height < 224:
            quality["resolution_ok"] = False
            quality["quality_status"] = "poor"

            return False, quality

        # ----------------------------------------------------
        # Convert image to grayscale
        # ----------------------------------------------------

        gray = np.array(image.convert("L"), dtype=np.uint8)

        # ----------------------------------------------------
        # Brightness
        # ----------------------------------------------------

        brightness = float(np.mean(gray) / 255.0)

        quality["brightness"] = round(brightness, 3)

        if brightness < 0.08:
            quality["quality_status"] = "too_dark"
            return False, quality

        if brightness > 0.97:
            quality["quality_status"] = "overexposed"
            return False, quality

        # ----------------------------------------------------
        # Approximate blur detection
        #
        # Variance of Laplacian is a common basic blur heuristic.
        # ----------------------------------------------------

        try:
            import cv2

            blur_score = float(cv2.Laplacian(gray, cv2.CV_64F).var())

            quality["blur_score"] = round(blur_score, 2)

            # Very conservative threshold.
            # This is not a disease-quality score.
            if blur_score < 20:
                quality["quality_status"] = "possibly_blurry"

                return False, quality

        except ImportError:
            # OpenCV isn't mandatory.
            # We can continue without blur detection.
            quality["blur_score"] = None

        return True, quality

    except Exception as exc:
        logger.warning(
            "Image quality assessment failed: %s",
            exc,
        )

        # Don't unnecessarily block the whole system
        # if the optional quality module fails.
        return True, {
            "quality_status": "quality_check_unavailable"
        }


# ============================================================
# IMAGE DECODING
# ============================================================

def decode_base64_image(
    image_base64: str,
) -> Tuple[bytes, str]:
    """
    Decode a Base64 image and determine its MIME type.
    """

    if not image_base64:
        raise ValueError("Image data is empty.")

    b64_str = image_base64.strip()

    # Handle:
    # data:image/jpeg;base64,...
    if "," in b64_str:
        b64_str = b64_str.split(",", 1)[1]

    try:
        raw_bytes = base64.b64decode(
            b64_str,
            validate=True,
        )
    except Exception as exc:
        raise ValueError(
            "Invalid Base64 image data."
        ) from exc

    if not raw_bytes:
        raise ValueError("Decoded image is empty.")

    mime = detect_mime_type(raw_bytes)

    return raw_bytes, mime


# ============================================================
# MIME TYPE DETECTION
# ============================================================

def detect_mime_type(raw_bytes: bytes) -> str:
    """
    Detect common image types using file signatures.
    """

    if raw_bytes.startswith(b"\x89PNG"):
        return "image/png"

    if raw_bytes.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"

    if (
        raw_bytes.startswith(b"RIFF")
        and len(raw_bytes) >= 12
        and b"WEBP" in raw_bytes[:12]
    ):
        return "image/webp"

    if raw_bytes.startswith(b"GIF87a") or raw_bytes.startswith(b"GIF89a"):
        return "image/gif"

    # Safe default
    return "image/jpeg"


# ============================================================
# FALLBACK CROP DETECTION
# ============================================================

def detect_crop_visual_features(
    raw_bytes: bytes,
    hint_crop: str = "",
) -> Tuple[str, float, List[str]]:
    """
    Basic HSV-based crop estimation.

    IMPORTANT:
    This is only a FALLBACK crop estimator.

    It must NOT claim to have diagnosed a disease.
    """

    c_hint = (
        (hint_crop or "")
        .strip()
        .lower()
    )

    # If farmer already supplied crop type,
    # trust it as a hint rather than pretending to detect it.
    if c_hint and c_hint not in {
        "auto-detect",
        "auto detect",
        "none",
    }:
        return (
            hint_crop,
            0.55,
            ["Crop type was supplied by the user."]
        )

    try:
        from PIL import Image
        import numpy as np

        image = Image.open(
            io.BytesIO(raw_bytes)
        ).convert("RGB")

        image.thumbnail((300, 300))

        hsv = np.array(
            image.convert("HSV"),
            dtype=np.float32,
        )

        h = hsv[:, :, 0] / 255.0 * 360.0
        s = hsv[:, :, 1] / 255.0
        v = hsv[:, :, 2] / 255.0

        # ----------------------------------------------------
        # White / bright regions
        # ----------------------------------------------------

        white_mask = (
            (s < 0.28)
            & (v > 0.68)
        )

        white_ratio = float(
            np.mean(white_mask)
        )

        # ----------------------------------------------------
        # Red regions
        # ----------------------------------------------------

        red_mask = (
            ((h < 18) | (h > 342))
            & (s > 0.38)
            & (v > 0.28)
        )

        red_ratio = float(
            np.mean(red_mask)
        )

        # ----------------------------------------------------
        # Yellow regions
        # ----------------------------------------------------

        yellow_mask = (
            (h >= 35)
            & (h <= 68)
            & (s > 0.35)
            & (v > 0.40)
        )

        yellow_ratio = float(
            np.mean(yellow_mask)
        )

        # ----------------------------------------------------
        # Green vegetation
        # ----------------------------------------------------

        green_mask = (
            (h >= 70)
            & (h <= 160)
            & (s > 0.20)
            & (v > 0.20)
        )

        green_ratio = float(
            np.mean(green_mask)
        )

        logger.info(
            "Fallback visual features: "
            "white=%.3f red=%.3f yellow=%.3f green=%.3f",
            white_ratio,
            red_ratio,
            yellow_ratio,
            green_ratio,
        )

        # ----------------------------------------------------
        # Conservative classification
        # ----------------------------------------------------

        if white_ratio >= 0.08:
            return (
                "Cotton",
                0.48,
                [
                    "Large bright low-saturation regions detected.",
                    "Visual pattern is compatible with cotton bolls.",
                ],
            )

        if red_ratio >= 0.06:
            return (
                "Tomato",
                0.48,
                [
                    "Red fruit-like regions detected.",
                    "Visual pattern is compatible with tomato fruit.",
                ],
            )

        if yellow_ratio >= 0.15:
            return (
                "Wheat",
                0.42,
                [
                    "Significant yellow vegetation detected.",
                    "Visual pattern may be compatible with wheat.",
                ],
            )

        if green_ratio >= 0.45:
            return (
                "Unknown",
                 0.20,
        [
            "Large green vegetation area detected.",
            "The crop cannot be reliably identified using color alone.",
        ],
    )

    except Exception as exc:
        logger.warning(
            "Fallback crop detection failed: %s",
            exc,
        )

    return (
        "Unknown",
        0.10,
        [
            "The crop could not be reliably identified from available visual features."
        ],
    )


# ============================================================
# GEMINI PROMPT
# ============================================================

def build_vision_prompt(
    hint_crop: str,
) -> str:
    """
    Builds a conservative agricultural vision prompt.

    Gemini identifies visual evidence.
    It does NOT independently prescribe pesticide dosage.
    """

    if hint_crop and hint_crop.lower() not in {
        "auto-detect",
        "auto detect",
        "none",
    }:
        crop_instruction = (
            f"The farmer indicated that the crop may be '{hint_crop}'. "
            "Treat this only as a hint and verify it visually."
        )
    else:
        crop_instruction = (
            "The crop type is unknown. Identify the most likely crop "
            "only when sufficient visual evidence exists."
        )

    return f"""
You are Pramaan Vision AI, an agricultural computer-vision assistant.

Analyze the farmer's crop photograph carefully.

{crop_instruction}

IMPORTANT RULES:

1. Do not invent symptoms that are not visually observable.
2. Do not force a diagnosis when the image is unclear.
3. If evidence is insufficient, use "Uncertain".
4. Confidence must reflect actual visual evidence and may be anywhere
   from 0.0 to 1.0.
5. Do NOT provide pesticide dosage or chemical prescription.
6. Do NOT invent pest counts.
7. Do NOT invent an affected percentage unless it can reasonably be
   estimated from visible affected plant area.
8. Clearly distinguish observations from diagnosis.
9. Prefer "Uncertain" over a confident-looking hallucination.
10. Identify only what can reasonably be inferred from the photograph.

Determine:

- crop species
- scientific name
- growth stage
- health status
- possible disease, pest, deficiency or stress
- observable symptoms
- visual evidence supporting the diagnosis
- severity
- confidence
- whether farmer confirmation is required

Health status must be one of:

"Healthy Crop"
"Diseased"
"Pest Infested"
"Nutrient Deficient"
"Stressed"
"Uncertain"

Severity must be one of:

"Low"
"Medium"
"High"
"Critical"
"Unknown"

Return ONLY valid JSON.

Use exactly this structure:

{{
    "crop_detected": "string",
    "scientific_name": "string",
    "crop_stage": "string",
    "disease_detected": "string",
    "health_status": "Healthy Crop | Diseased | Pest Infested | Nutrient Deficient | Stressed | Uncertain",
    "confidence": 0.0,
    "severity_level": "Low | Medium | High | Critical | Unknown",
    "pest_count_estimate": null,
    "affected_percentage": null,
    "symptoms": [
        "observable symptom 1",
        "observable symptom 2"
    ],
    "visual_evidence": [
        "visual evidence 1",
        "visual evidence 2"
    ],
    "analysis_notes": "short explanation of what was visually observed",
    "requires_confirmation": false
}}

If disease identification is uncertain:

"disease_detected": "Unable to determine reliably"

and:

"health_status": "Uncertain"

and:

"requires_confirmation": true
"""


# ============================================================
# JSON EXTRACTION
# ============================================================

def extract_json_from_response(
    text: str,
) -> Dict[str, Any]:
    """
    Safely extract JSON from Gemini response.

    Handles:
    - plain JSON
    - ```json ... ```
    - accidental surrounding text
    """

    if not text:
        raise ValueError(
            "Gemini returned an empty response."
        )

    cleaned = text.strip()

    # --------------------------------------------------------
    # Markdown code block
    # --------------------------------------------------------

    if "```json" in cleaned:
        cleaned = (
            cleaned
            .split("```json", 1)[1]
            .split("```", 1)[0]
            .strip()
        )

    elif "```" in cleaned:
        cleaned = (
            cleaned
            .split("```", 1)[1]
            .split("```", 1)[0]
            .strip()
        )

    # --------------------------------------------------------
    # Direct JSON
    # --------------------------------------------------------

    try:
        parsed = json.loads(cleaned)

        if not isinstance(parsed, dict):
            raise ValueError(
                "Gemini JSON response is not an object."
            )

        return parsed

    except json.JSONDecodeError:
        pass

    # --------------------------------------------------------
    # Attempt to find JSON object inside text
    # --------------------------------------------------------

    start = cleaned.find("{")
    end = cleaned.rfind("}")

    if start == -1 or end == -1 or end <= start:
        raise ValueError(
            "Could not locate a JSON object in Gemini response."
        )

    json_candidate = cleaned[start:end + 1]

    parsed = json.loads(json_candidate)

    if not isinstance(parsed, dict):
        raise ValueError(
            "Extracted Gemini response is not a JSON object."
        )

    return parsed


# ============================================================
# NORMALIZE GEMINI OUTPUT
# ============================================================

def normalize_gemini_result(
    data: Dict[str, Any],
) -> Dict[str, Any]:
    """
    Normalize and validate Gemini's response before constructing
    VisionAnalysisResponse.
    """

    health_status = str(
        data.get(
            "health_status",
            "Uncertain",
        )
    ).strip()

    allowed_health = {
        "Healthy Crop",
        "Diseased",
        "Pest Infested",
        "Nutrient Deficient",
        "Stressed",
        "Uncertain",
    }

    if health_status not in allowed_health:
        health_status = "Uncertain"

    severity = str(
        data.get(
            "severity_level",
            "Unknown",
        )
    ).strip()

    allowed_severity = {
        "Low",
        "Medium",
        "High",
        "Critical",
        "Unknown",
    }

    if severity not in allowed_severity:
        severity = "Unknown"

    # --------------------------------------------------------
    # Confidence
    # --------------------------------------------------------

    try:
        confidence = float(
            data.get(
                "confidence",
                0.0,
            )
        )
    except (TypeError, ValueError):
        confidence = 0.0

    confidence = max(
        0.0,
        min(1.0, confidence),
    )

    # --------------------------------------------------------
    # Symptoms
    # --------------------------------------------------------

    symptoms = data.get(
        "symptoms",
        [],
    )

    if not isinstance(symptoms, list):
        symptoms = [str(symptoms)]

    symptoms = [
        str(item).strip()
        for item in symptoms
        if str(item).strip()
    ][:4]

    # --------------------------------------------------------
    # Visual evidence
    # --------------------------------------------------------

    visual_evidence = data.get(
        "visual_evidence",
        [],
    )

    if not isinstance(visual_evidence, list):
        visual_evidence = [str(visual_evidence)]

    visual_evidence = [
        str(item).strip()
        for item in visual_evidence
        if str(item).strip()
    ][:5]

    # --------------------------------------------------------
    # Pest count
    # --------------------------------------------------------

    pest_count = data.get(
        "pest_count_estimate"
    )

    if not isinstance(pest_count, int):
        pest_count = None

    if pest_count is not None:
        pest_count = max(
            0,
            pest_count,
        )

    # --------------------------------------------------------
    # Affected percentage
    # --------------------------------------------------------

    affected_percentage = data.get(
        "affected_percentage"
    )

    try:
        if affected_percentage is not None:
            affected_percentage = float(
                affected_percentage
            )

            affected_percentage = max(
                0.0,
                min(
                    100.0,
                    affected_percentage,
                ),
            )

    except (TypeError, ValueError):
        affected_percentage = None

    # --------------------------------------------------------
    # Force uncertainty if confidence is very low
    # --------------------------------------------------------

    requires_confirmation = bool(
        data.get(
            "requires_confirmation",
            False,
        )
    )

    if confidence < 0.60:
        requires_confirmation = True

    if health_status == "Uncertain":
        requires_confirmation = True

    # --------------------------------------------------------
    # Disease
    # --------------------------------------------------------

    disease_detected = str(
        data.get(
            "disease_detected",
            "Unable to determine reliably",
        )
    ).strip()

    if not disease_detected:
        disease_detected = (
            "Unable to determine reliably"
        )

    # --------------------------------------------------------
    # Crop
    # --------------------------------------------------------

    crop_detected = str(
        data.get(
            "crop_detected",
            "Unknown",
        )
    ).strip()

    if not crop_detected:
        crop_detected = "Unknown"

    # --------------------------------------------------------
    # Scientific name
    # --------------------------------------------------------

    scientific_name = str(
        data.get(
            "scientific_name",
            "Unknown",
        )
    ).strip()

    # --------------------------------------------------------
    # Crop stage
    # --------------------------------------------------------

    crop_stage = str(
        data.get(
            "crop_stage",
            "Unknown",
        )
    ).strip()

    # --------------------------------------------------------
    # Analysis notes
    # --------------------------------------------------------

    analysis_notes = str(
        data.get(
            "analysis_notes",
            "",
        )
    ).strip()

    return {
        "crop_detected": crop_detected,
        "scientific_name": scientific_name,
        "crop_stage": crop_stage,
        "disease_detected": disease_detected,
        "health_status": health_status,
        "confidence": confidence,
        "severity_level": severity,
        "pest_count_estimate": pest_count,
        "affected_percentage": affected_percentage,
        "symptoms": symptoms,
        "visual_evidence": visual_evidence,
        "analysis_notes": analysis_notes,
        "requires_confirmation": requires_confirmation,
    }


# ============================================================
# AGRONOMY KNOWLEDGE BASE LOOKUP
# ============================================================

def get_agronomy_recommendation(
    crop_name: str,
    disease_name: str,
) -> Dict[str, Any]:
    """
    Retrieve treatment/prevention guidance from the trusted
    agronomy knowledge base.

    Gemini does not generate these recommendations.
    """

    crop_key = crop_name.lower()

    disease_key = disease_name.lower()

    # --------------------------------------------------------
    # Normalize crop
    # --------------------------------------------------------

    if "cotton" in crop_key or "kapas" in crop_key:
        crop_key = "cotton"

    elif "wheat" in crop_key or "gehu" in crop_key:
        crop_key = "wheat"

    elif "tomato" in crop_key or "tamatar" in crop_key:
        crop_key = "tomato"

    elif "chilli" in crop_key or "mirch" in crop_key:
        crop_key = "chilli"

    elif (
        "paddy" in crop_key
        or "rice" in crop_key
        or "dhan" in crop_key
    ):
        crop_key = "paddy"

    elif "potato" in crop_key or "aloo" in crop_key:
        crop_key = "potato"

    elif "mustard" in crop_key or "sarson" in crop_key:
        crop_key = "mustard"

    elif "sugarcane" in crop_key or "ganna" in crop_key:
        crop_key = "sugarcane"

    # --------------------------------------------------------
    # Search disease profile
    # --------------------------------------------------------

    crop_profiles = AGRONOMY_KB.get(
        crop_key,
        {},
    )

    for disease_key_name, profile in crop_profiles.items():

        if (
            disease_key_name in disease_key
            or disease_key in disease_key_name
        ):
            return profile

    # --------------------------------------------------------
    # No verified recommendation found
    # --------------------------------------------------------

    return {
        "recommended_active_ingredient": (
            "No verified treatment recommendation available "
            "for this diagnosis. Consult a local agricultural "
            "expert and follow the current product label."
        ),
        "organic_alternative": (
            "No verified biological recommendation available "
            "for this diagnosis."
        ),
        "prevention_tips": [
    "Continue regular crop monitoring.",
    "Inspect leaves, stems and fruits regularly.",
    "Maintain appropriate irrigation and field hygiene."
]
    }


# ============================================================
# FALLBACK UNCERTAIN RESPONSE
# ============================================================

def build_uncertain_response(
    reason: str,
    analysis_source: str = "system",
) -> VisionAnalysisResponse:

    return VisionAnalysisResponse(
        crop_detected="Unknown",
        scientific_name="Unknown",
        crop_stage="Unknown",
        disease_detected="Unable to determine reliably",
        health_status="Uncertain",
        confidence=0.0,
        severity_level="Unknown",
        pest_count_estimate=None,
        affected_percentage=None,
        symptoms=[],
        visual_evidence=[],
        analysis_notes=reason,
        recommended_active_ingredient=(
            "No treatment recommendation should be made "
            "until the crop condition is confirmed."
        ),
        organic_alternative=(
            "No treatment recommendation should be made "
            "until the crop condition is confirmed."
        ),
        urgency_days=None,
        treatment_advice=(
            "Please capture a clear close-up image of the affected "
            "leaf, stem, fruit or pest in good daylight."
        ),
        prevention_tips=[
            "Avoid applying chemicals based only on an uncertain image diagnosis.",
            "Consult a local agricultural expert if symptoms persist."
        ],
        analysis_source=analysis_source,
        requires_confirmation=True,
    )


# ============================================================
# VISION AGENT
# ============================================================

class VisionAgent:

    def __init__(self):
        self.api_key = getattr(
            settings,
            "GEMINI_API_KEY",
            None,
        )

    # ========================================================
    # MAIN ANALYSIS FUNCTION
    # ========================================================

    def analyze_crop_image(
        self,
        request: VisionAnalysisRequest,
    ) -> VisionAnalysisResponse:

        hint_crop = (
            request.crop_type or ""
        ).strip()

        is_auto_detect = (
            hint_crop.lower()
            in {
                "auto-detect",
                "auto detect",
                "none",
                "",
            }
        )

        # ----------------------------------------------------
        # STEP 1 — Validate image presence
        # ----------------------------------------------------

        if not request.image_base64:

            logger.warning(
                "Vision request received without image."
            )

            return build_uncertain_response(
                reason=(
                    "No crop image was supplied."
                )
            )

        # ----------------------------------------------------
        # STEP 2 — Decode image
        # ----------------------------------------------------

        try:

            raw_bytes, mime = decode_base64_image(
                request.image_base64
            )

        except Exception as exc:

            logger.warning(
                "Image decoding failed: %s",
                exc,
            )

            return build_uncertain_response(
                reason=(
                    "The supplied image could not be decoded."
                )
            )

        # ----------------------------------------------------
        # STEP 3 — Image quality gate
        # ----------------------------------------------------

        image_quality_ok, quality_metadata = (
            assess_image_quality(
                raw_bytes
            )
        )

        logger.info(
            "Vision image quality: %s",
            quality_metadata,
        )

        if not image_quality_ok:

            return build_uncertain_response(
                reason=(
                    "The image quality is insufficient for reliable "
                    "crop or disease identification. "
                    "Please capture a clearer close-up image in daylight."
                ),
                analysis_source="image_quality_gate",
            )

        # ----------------------------------------------------
        # STEP 4 — Gemini Vision
        # ----------------------------------------------------

        if raw_bytes and self.api_key:

            gemini_result = (
                self._analyze_with_gemini(
                    raw_bytes=raw_bytes,
                    mime=mime,
                    hint_crop=hint_crop,
                )
            )

            if gemini_result is not None:

                return self._build_final_response(
                    gemini_result,
                    analysis_source="gemini",
                )

        else:

            logger.warning(
                "Gemini unavailable: image=%s api_key=%s",
                bool(raw_bytes),
                bool(self.api_key),
            )

        # ----------------------------------------------------
        # STEP 5 — FALLBACK CROP ESTIMATION
        # ----------------------------------------------------

        if is_auto_detect:

            (
                detected_crop,
                fallback_confidence,
                fallback_evidence,
            ) = detect_crop_visual_features(
                raw_bytes,
                hint_crop,
            )

        else:

            detected_crop = hint_crop
            fallback_confidence = 0.55

            fallback_evidence = [
                "Crop type supplied by the user.",
                "Gemini vision analysis was unavailable."
            ]

        # ----------------------------------------------------
        # STEP 6 — IMPORTANT:
        #
        # Do NOT pretend fallback CV diagnosed a disease.
        # ----------------------------------------------------

        if detected_crop == "Unknown":

            return build_uncertain_response(
                reason=(
                    "Gemini vision analysis was unavailable and "
                    "the fallback visual system could not reliably "
                    "identify the crop."
                ),
                analysis_source="heuristic",
            )

        return VisionAnalysisResponse(

            crop_detected=detected_crop,

            scientific_name="Unknown",

            crop_stage="Unknown",

            disease_detected=(
                "Unable to determine reliably"
            ),

            health_status="Uncertain",

            confidence=fallback_confidence,

            severity_level="Unknown",

            pest_count_estimate=None,

            affected_percentage=None,

            symptoms=[],

            visual_evidence=fallback_evidence,

            analysis_notes=(
                "The fallback computer-vision system identified "
                "a possible crop based primarily on color features. "
                "It did not diagnose a disease."
            ),

            recommended_active_ingredient=(
                "No treatment recommendation should be made "
                "until the disease is confirmed."
            ),

            organic_alternative=(
                "No treatment recommendation should be made "
                "until the disease is confirmed."
            ),

            urgency_days=None,

            treatment_advice=(
                "Please retry the analysis when AI vision service "
                "is available or provide a clearer close-up image."
            ),

            prevention_tips=[
                "Do not apply chemicals based solely on this preliminary result.",
                "Capture close-up images of both healthy and affected plant areas."
            ],

            analysis_source="heuristic",

            requires_confirmation=True,
        )

    # ========================================================
    # GEMINI ANALYSIS
    # ========================================================

    def _analyze_with_gemini(
        self,
        raw_bytes: bytes,
        mime: str,
        hint_crop: str,
    ) -> Optional[Dict[str, Any]]:

        try:

            from google import genai
            from google.genai import types

            client = genai.Client(
                api_key=self.api_key
            )

        except Exception as exc:

            logger.warning(
                "Unable to initialize Gemini client: %s",
                exc,
            )

            return None

        prompt = build_vision_prompt(
            hint_crop
        )

        # ----------------------------------------------------
        # Try models one by one
        # ----------------------------------------------------

        for model_name in GEMINI_MODELS:

            try:

                logger.info(
                    "Trying Gemini Vision model: %s",
                    model_name,
                )

                response = client.models.generate_content(

                    model=model_name,

                    contents=[
                        types.Part.from_bytes(
                            data=raw_bytes,
                            mime_type=mime,
                        ),
                        prompt,
                    ],
                )

                text_response = (
                    response.text or ""
                ).strip()

                data = extract_json_from_response(
                    text_response
                )

                normalized = normalize_gemini_result(
                    data
                )

                logger.info(
                    "Gemini model %s returned crop=%s disease=%s confidence=%.2f",
                    model_name,
                    normalized["crop_detected"],
                    normalized["disease_detected"],
                    normalized["confidence"],
                )

                normalized["model_used"] = model_name

                return normalized

            except Exception as exc:

                logger.warning(
                    "Gemini model %s failed: %s",
                    model_name,
                    exc,
                )

                continue

        logger.error(
            "All Gemini Vision models failed."
        )

        return None

    # ========================================================
    # BUILD FINAL RESPONSE
    # ========================================================

    def _build_final_response(
        self,
        result: Dict[str, Any],
        analysis_source: str,
    ) -> VisionAnalysisResponse:

        crop = result.get(
            "crop_detected",
            "Unknown",
        )

        disease = result.get(
            "disease_detected",
            "Unable to determine reliably",
        )

        confidence = float(
            result.get(
                "confidence",
                0.0,
            )
        )

        health_status = result.get(
            "health_status",
            "Uncertain",
        )

        # ----------------------------------------------------
        # Only provide agronomy recommendation when diagnosis
        # has reasonable confidence.
        # ----------------------------------------------------

        if (
            confidence >= 0.60
            and health_status != "Uncertain"
            and disease
            and disease != "Unable to determine reliably"
        ):

            agronomy = get_agronomy_recommendation(
                crop_name=crop,
                disease_name=disease,
            )

        else:

            agronomy = {
                "recommended_active_ingredient": (
                    "No treatment recommendation should be made "
                    "until the visual diagnosis is confirmed."
                ),
                "organic_alternative": (
                    "No treatment recommendation should be made "
                    "until the visual diagnosis is confirmed."
                ),
                "prevention_tips": [
                    "Capture a clearer image of the affected plant part.",
                    "Consult local agricultural guidance before treatment."
                ],
            }


        # ----------------------------------------------------
# Urgency
# ----------------------------------------------------

        urgency_days = None

        severity = result.get(
        "severity_level",
        "Unknown",
         )

# Healthy crops do not require treatment urgency.
        if health_status == "Healthy Crop":
          urgency_days = None

        elif health_status == "Uncertain":
          urgency_days = None

        elif severity == "Critical":
          urgency_days = 1

        elif severity == "High":
          urgency_days = 2

        elif severity == "Medium":
          urgency_days = 3

        elif severity == "Low":
         urgency_days = 4



            # ----------------------------------------------------
# Treatment advice
# ----------------------------------------------------

        if health_status == "Healthy Crop":

         treatment_advice = (
        "No treatment is indicated based on the current image. "
        "Continue regular crop monitoring."
    )

        elif health_status == "Uncertain":

         treatment_advice = (
        "The visual evidence is insufficient for a reliable "
        "treatment recommendation. Please capture a clearer "
        "close-up image and seek local agricultural guidance "
        "before applying any treatment."
    )

        elif confidence < 0.60:

         treatment_advice = (
        "The visual evidence is insufficient for a reliable "
        "treatment recommendation. Please capture another image."
    )

        else:

          treatment_advice = (
        "Use the agronomic guidance below as decision support. "
        "Before applying any chemical product, verify the diagnosis, "
        "local registration, current label instructions, crop stage, "
        "and advice from an authorized agricultural professional."
    )

        # ----------------------------------------------------
        # Final response
        # ----------------------------------------------------

        return VisionAnalysisResponse(

            crop_detected=result.get(
                "crop_detected",
                "Unknown",
            ),

            scientific_name=result.get(
                "scientific_name",
                "Unknown",
            ),

            crop_stage=result.get(
                "crop_stage",
                "Unknown",
            ),

            disease_detected=disease,

            health_status=health_status,

            confidence=confidence,

            severity_level=severity,

            pest_count_estimate=result.get(
                "pest_count_estimate"
            ),

            affected_percentage=result.get(
                "affected_percentage"
            ),

            symptoms=result.get(
                "symptoms",
                [],
            ),

            visual_evidence=result.get(
                "visual_evidence",
                [],
            ),

            analysis_notes=result.get(
                "analysis_notes",
                "",
            ),

            recommended_active_ingredient=(
                agronomy[
                    "recommended_active_ingredient"
                ]
            ),

            organic_alternative=(
                agronomy[
                    "organic_alternative"
                ]
            ),

            urgency_days=urgency_days,

            treatment_advice=treatment_advice,

            prevention_tips=(
                agronomy[
                    "prevention_tips"
                ]
            ),

            analysis_source=analysis_source,

            requires_confirmation=bool(
                result.get(
                    "requires_confirmation",
                    confidence < 0.60,
                )
            ),
        )


# ============================================================
# SINGLE VISION AGENT INSTANCE
# ============================================================

vision_agent = VisionAgent()