import logging
from backend.app.core.config import settings
from backend.app.models.schemas import (
    ChatQueryRequest,
    ChatQueryResponse,
    WeatherAdvisoryRequest
)
from backend.app.ai.weather_agent import weather_agent

logger = logging.getLogger(__name__)

GEMINI_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.6-flash",
    "gemini-flash-latest",
]

class OrchestratorAgent:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY

    def handle_chat_query(self, request: ChatQueryRequest) -> ChatQueryResponse:
        user_msg = request.message
        crop = request.crop_context or "General Farming"
        lower = user_msg.lower()

        # Detect weather or Punjab regional query
        weather_keywords = [
            "weather", "spray", "rain", "wind", "temp", "temperature", "forecast",
            "climate", "window", "humidity", "delta-t", "advisory", "mausam", "barish",
            "ਮੌਸਮ", "ਸਪਰੇਅ", "ਮੀਂਹ", "ਬਾਰਿਸ਼", "ਕਣਕ", "ਪੰਜਾਬ", "ਲੁਧਿਆਣਾ", "ਬਠਿੰਡਾ", "ਅੰਮ੍ਰਿਤਸਰ"
        ]
        punjab_district_mentions = [
            "ludhiana", "bathinda", "amritsar", "jalandhar", "patiala", "sangrur",
            "mansa", "fazilka", "hoshiarpur", "firozpur", "gurdaspur", "punjab"
        ]

        is_weather_query = any(k in lower for k in weather_keywords)
        target_district = "Ludhiana"
        for d in punjab_district_mentions:
            if d in lower:
                target_district = d.capitalize()
                is_weather_query = True
                break

        # Fetch Real-Time Live Weather Snapshot for Grounded Intelligence
        weather_context = None
        try:
            w_req = WeatherAdvisoryRequest(
                district=target_district,
                crop=crop
            )
            weather_adv = weather_agent.get_weather_advisory(w_req)
            curr_w = weather_adv.current_weather
            weather_context = (
                f"Live Real-Time Weather in {curr_w.district_name}, Punjab ({curr_w.condition}): "
                f"Temperature {curr_w.temperature_c}°C, Relative Humidity {curr_w.humidity_percent}%, "
                f"Wind Speed {curr_w.wind_speed_kmh} km/h (Gusts {curr_w.wind_gusts_kmh or 0} km/h), "
                f"Delta-T {curr_w.delta_t_c}°C ({weather_adv.delta_t_status}), Rain Probability {curr_w.precipitation_prob}%. "
                f"Spray Recommendation: {curr_w.spray_recommendation}. "
                f"Pest Advisory: {weather_adv.pest_pressure_forecast}"
            )
        except Exception as ex:
            logger.warning(f"Error fetching live weather context for chat: {ex}")

        # 1. Try Gemini API with live real-time agronomic grounding
        if self.api_key:
            try:
                from google import genai
                client = genai.Client(api_key=self.api_key)
                prompt = f"""
                You are "Ask Pramaan", an AI Agronomy & Verification Assistant for Indian farmers, specialized in the Punjab agricultural belt (PAU Ludhiana standards).
                Farmer's Question: "{user_msg}"
                Active Crop Context: {crop} | Target Region: {target_district}, Punjab | Language: {request.language}
                Live Real-Time Weather Data: {weather_context or "Not available"}

                CRITICAL FORMATTING RULES:
                - DO NOT write long paragraphs.
                - Provide your response ONLY in 3-4 short, crisp, bite-sized bullet points.
                - If the question is about weather or spraying, quote the EXACT live temperature, wind, and Delta-T values from the provided Live Weather Data.
                - Use clear emojis and bold labels for each point.
                - Structure:
                  • 🎯 **Diagnosis / Live Status:** (1 short line mentioning live condition or crop state)
                  • 🧪 **Chemical / Spray Window:** (Exact recommendation, dosage, or PAU spray window)
                  • 🌿 **Organic / Safety Alternative:** (Biological alternative or PAU safety guideline)
                  • ⏰ **Delta-T & Timing:** (Live weather compliance & best morning/evening window)
                Keep it strictly under 70 words total.
                """
                for model_name in GEMINI_MODELS:
                    try:
                        response = client.models.generate_content(
                            model=model_name,
                            contents=prompt
                        )
                        reply_text = response.text.strip()
                        if reply_text:
                            chips = ["Check Weather Window", "Log Spray Log", "Punjab PAU Advisory", "Verify Product"]
                            if "wheat" in lower or "kanak" in lower:
                                chips = ["Wheat Yellow Rust Guide", "Check Tilt Dosage", "PAU Ludhiana Advisory"]
                            elif "cotton" in lower or "narma" in lower:
                                chips = ["Cotton Whitefly Window", "Log Bio-Neem", "Malwa Pest Alert"]
                            return ChatQueryResponse(
                                reply=reply_text,
                                citations=["PAU Ludhiana Agronomy Protocols", "Pramaan Verified Live Weather"],
                                action_chips=chips
                            )
                    except Exception as e:
                        logger.warning(f"Gemini model {model_name} failed: {e}")
                        continue
            except Exception as e:
                logger.warning(f"Gemini client initialization failed: {e}")

        # 2. Intelligent Real-Time Grounded Rule Engine Fallback
        if is_weather_query and weather_adv:
            w = weather_adv.current_weather
            reply = (
                f"• 🎯 **Live Status ({w.district_name}, Punjab):** {w.condition} at {w.temperature_c}°C | {w.humidity_percent}% RH\n"
                f"• 🧪 **Spray Safety:** {w.spray_recommendation}\n"
                f"• 🌿 **Delta-T Index:** {w.delta_t_c}°C (Wind: {w.wind_speed_kmh} km/h) — {weather_adv.delta_t_status}\n"
                f"• ⏰ **Best Window:** Morning (06:30 - 10:00 AM) or Evening (04:00 - 07:00 PM) for max absorption."
            )
            chips = ["View 48h Windows", "Log Spray", "PAU Advisory", "Change District"]
        elif "wheat" in lower or "ਕਣਕ" in lower or "गेहूं" in lower or "rust" in lower or "ਰਤੂਆ" in lower:
            reply = (
                "• 🎯 **Target:** Wheat Yellow / Stripe Rust (Puccinia striiformis)\n"
                "• 🧪 **PAU Recommended Fungicide:** Propiconazole 25% EC (Tilt) @ 1 ml/L (200 ml/Acre in 200L water)\n"
                "• 🌿 **Organic Alternative:** Bio-Sulfur dusting @ 10 kg/Acre or Trichoderma viride\n"
                "• ⏰ **Application:** Spray during morning calm window (Delta-T 2.0–8.0°C) within 24h of yellow stripe appearance"
            )
            chips = ["Log Tilt Spray", "Check Wind Speed", "PAU Yellow Rust Protocol"]
        elif "cotton" in lower or "ਕਪਾਹ" in lower or "नरमा" in lower or "whitefly" in lower or "ਚਿੱਟੀ ਮੱਖੀ" in lower:
            reply = (
                "• 🎯 **Target:** Cotton Whitefly (Bemisia tabaci) — Malwa Belt\n"
                "• 🧪 **Chemical Spray:** Pyriproxyfen 10% EC @ 400 ml/Acre or Diafenthiuron 50% WP @ 1.5 g/L\n"
                "• 🌿 **Organic Option:** Bio-Neem Power 10,000 PPM @ 2.5 ml/L + 16 Yellow Sticky Traps/Acre\n"
                "• ⏰ **Safety:** Maintain 3-day PHI safety window; avoid spraying when temperature exceeds 34°C"
            )
            chips = ["Log Bio-Neem", "Check Whitefly Window", "Malwa Trap Advisory"]
        elif "chilli" in lower or "ਮਿਰਚ" in lower or "मिर्च" in lower or "curl" in lower or "thrips" in lower:
            reply = (
                "• 🎯 **Target:** Chilli Leaf Curl & Thrips Complex\n"
                "• 🧪 **Chemical Spray:** Diafenthiuron 50% WP (Pegasus) @ 1.5 g/L in 200L clean water per acre\n"
                "• 🌿 **Organic Option:** Bio-Neem 10,000 PPM @ 2.5 ml/L + Blue Sticky Traps\n"
                "• ⏰ **Best Timing:** Spray early morning (07:00 - 10:00 AM) under calm wind"
            )
            chips = ["Log Pegasus Spray", "Check Weather", "View Thrips Threshold"]
        elif "potato" in lower or "ਆਲੂ" in lower or "आलू" in lower or "blight" in lower:
            reply = (
                "• 🎯 **Target:** Late Blight of Potato (Phytophthora infestans) — Doaba Zone\n"
                "• 🧪 **Fungicide:** Mancozeb 75% WP @ 600 g/Acre or Cymoxanil + Mancozeb @ 600 g/Acre\n"
                "• 🌿 **Preventive:** Ensure proper earthing-up and drain standing furrow water\n"
                "• ⏰ **Timing:** Apply prophylactically when relative humidity exceeds 80% and skies are overcast"
            )
            chips = ["Log Mancozeb", "Check Humidity", "Doaba Weather"]
        else:
            reply = (
                f"• 🎯 **Crop Guidance for {crop} (Punjab Agro-Zone)**\n"
                f"• 🧪 **Recommended Dose:** 2.0 to 2.5 ml/L foliar spray in 200L clean water per acre\n"
                "• 🌿 **Organic Alternative:** Neem Seed Extract (5%) or Trichoderma bio-agent\n"
                "• ⏰ **Application Window:** Apply between 06:30 - 10:00 AM under calm wind"
            )
            chips = ["Log Spray", "Live Weather Window", "Scan Product QR"]

        return ChatQueryResponse(
            reply=reply,
            citations=["PAU Ludhiana Protocols", "Pramaan Verified Microclimate"],
            action_chips=chips
        )

orchestrator_agent = OrchestratorAgent()
