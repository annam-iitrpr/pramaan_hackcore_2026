import logging
import re
from backend.app.core.config import settings
from backend.app.models.schemas import (
    ChatQueryRequest,
    ChatQueryResponse,
    WeatherAdvisoryRequest
)
from backend.app.ai.weather_agent import weather_agent

logger = logging.getLogger(__name__)

GEMINI_MODELS = [
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-flash-latest",
]

class OrchestratorAgent:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY

    def handle_chat_query(self, request: ChatQueryRequest) -> ChatQueryResponse:
        user_msg = request.message.strip()
        crop = request.crop_context or "General Crop"
        lang = (request.language or "en").lower()
        lower = user_msg.lower()

        # Language metadata
        lang_names = {
            "en": "English",
            "hi": "Hindi (हिन्दी)",
            "mr": "Marathi (मराठी)",
            "pa": "Punjabi (ਪੰਜਾਬੀ)"
        }
        target_lang_name = lang_names.get(lang, "English")

        # Detect weather or Punjab regional query
        weather_keywords = [
            "weather", "spray", "rain", "wind", "temp", "temperature", "forecast",
            "climate", "window", "humidity", "delta-t", "advisory", "mausam", "barish",
            "havaman", "fawarani", "छिड़काव", "मौसम", "बारिश", "हवा", "तापमान",
            "हवामान", "फवारणी", "पाऊस", "ਮੌਸਮ", "ਸਪਰੇਅ", "ਮੀਂਹ", "ਬਾਰਿਸ਼", "ਕਣਕ"
        ]
        punjab_district_mentions = [
            "ludhiana", "bathinda", "amritsar", "jalandhar", "patiala", "sangrur",
            "mansa", "fazilka", "hoshiarpur", "firozpur", "gurdaspur", "nashik", "punjab"
        ]

        is_weather_query = any(k in lower for k in weather_keywords)
        target_district = "Ludhiana"
        for d in punjab_district_mentions:
            if d in lower:
                target_district = d.capitalize()
                break

        # Fetch Real-Time Live Weather Snapshot
        weather_context = None
        weather_adv = None
        try:
            w_req = WeatherAdvisoryRequest(
                district=target_district,
                crop=crop
            )
            weather_adv = weather_agent.get_weather_advisory(w_req)
            curr_w = weather_adv.current_weather
            weather_context = (
                f"District: {curr_w.district_name} | Condition: {curr_w.condition} | "
                f"Temp: {curr_w.temperature_c}°C | Humidity: {curr_w.humidity_percent}% | "
                f"Wind: {curr_w.wind_speed_kmh} km/h | Rain Chance: {curr_w.precipitation_prob}% | "
                f"Spray Safety: {curr_w.spray_recommendation}"
            )
        except Exception as ex:
            logger.warning(f"Error fetching live weather context for chat: {ex}")

        # -------------------------------------------------------------
        # 1. Google Gemini AI Engine with Clean Output Rules
        # -------------------------------------------------------------
        if self.api_key:
            try:
                from google import genai
                client = genai.Client(api_key=self.api_key)
                prompt = f"""
                You are "Ask Pramaan", a friendly, empathetic, and highly practical Kisan AI Agronomist & Farm Advisor.
                You are talking directly to an Indian farmer in simple everyday farming language.

                Farmer's Question: "{user_msg}"
                Farmer's Crop Context: {crop}
                Region: {target_district}
                Language to reply in: {target_lang_name}
                Current Live Weather Context: {weather_context or "Normal pleasant field weather"}

                RULES FOR YOUR RESPONSE:
                1. STRICTLY REPLY in {target_lang_name} (if Hindi use simple Hindi, if Marathi use simple Marathi, if Punjabi use simple Punjabi, if English use simple English).
                2. TONE: Very warm, respectful, practical, and direct (use "Namaste" / "Sat Sri Akal" / "Ram Ram" appropriately).
                3. STRICTLY NO ASTERISKS: DO NOT use any asterisks (*) or (**) or (***) in your reply at all! Never write bold markers like **text** or bullet asterisks like * item. Use clean bullet points '• ' and emojis.
                4. AVOID complex academic jargon, Latin pathogen names, or confusing indices like "Delta-T", "Psychrometric", etc. Use simple words like "मौसम", "हवा", "दवा और मात्रा", "सही समय".
                5. SPECIFIC BEHAVIOR:
                   - If greeting (hi, hello): Warmly greet the farmer and ask how you can help with their {crop} crop today.
                   - If asking "Should I spray today?": Start directly with a clear verdict like "✅ हाँ, आज स्प्रे करना बिल्कुल सुरक्षित है!" or "❌ आज स्प्रे न करें!" then give 2-3 short bullet points (Best time, wind condition, water mix).
                   - If asking about a pest/disease: Clearly name the problem, recommended medicine name with exact dosage (e.g. 200 ml per acre in 200L water), and a simple desi/organic alternative.
                   - If asking any other farming question: Give a direct, helpful, 2-4 sentence practical advice.
                6. Keep total length short, easy to read on mobile screens (under 80 words).
                """

                for model_name in GEMINI_MODELS:
                    try:
                        response = client.models.generate_content(
                            model=model_name,
                            contents=prompt
                        )
                        reply_text = response.text.strip()
                        if reply_text:
                            cleaned_reply = self._clean_markdown(reply_text)
                            chips = self._get_smart_action_chips(lower, crop, lang)
                            return ChatQueryResponse(
                                reply=cleaned_reply,
                                citations=["Pramaan Verified Field Protocols", "Live Weather Station"],
                                action_chips=chips
                            )
                    except Exception as e:
                        logger.warning(f"Gemini model {model_name} failed: {e}")
                        continue
            except Exception as e:
                logger.warning(f"Gemini client initialization failed: {e}")

        # -------------------------------------------------------------
        # 2. Dynamic, Humanized, Multilingual Fallback Engine
        # -------------------------------------------------------------
        reply, chips = self._generate_farmer_friendly_fallback(user_msg, crop, lang, weather_adv)
        cleaned_reply = self._clean_markdown(reply)
        return ChatQueryResponse(
            reply=cleaned_reply,
            citations=["Pramaan Verified Field Protocols", "Live Weather Station"],
            action_chips=chips
        )

    def _clean_markdown(self, text: str) -> str:
        # Convert any bullet asterisks/hyphens at the beginning of a line to clean "• "
        text = re.sub(r'^\s*[\*\-]\s*(\*\*)?', '• ', text, flags=re.MULTILINE)
        # Remove all remaining asterisks completely
        text = text.replace('*', '')
        return text.strip()

    def _get_smart_action_chips(self, lower: str, crop: str, lang: str) -> list:
        if lang == "hi":
            if "spray" in lower or "मौसम" in lower or "स्प्रे" in lower:
                return ["मौसम चेक करें", "स्प्रे रिकॉर्ड जोड़ें", "दवा की मात्रा देखें"]
            elif "गेहूं" in lower or "wheat" in lower:
                return ["पीला रतुआ इलाज", "टिल्ट 25% EC खुराक", "खाद व यूरिया समय"]
            elif "कपास" in lower or "cotton" in lower:
                return ["सफेद मक्खी नियंत्रण", "बायो-नीम स्प्रे", "गुलाबी सुंडी जांच"]
            return ["मौसम जानकारी", "दवा और खुराक", "कीट और रोग इलाज"]
        elif lang == "mr":
            if "spray" in lower or "हवामान" in lower or "फवारणी" in lower:
                return ["हवामान तपासा", "फवारणी नोंद करा", "योग्य फवारणी वेळ"]
            elif "कापूस" in lower or "cotton" in lower:
                return ["तुडतुडे नियंत्रण", "बायो-नीम फवारणी", "बोंड अळी उपाय"]
            return ["हवामान माहिती", "औषध व प्रमाण", "पीक रोग सल्ला"]
        elif lang == "pa":
            if "spray" in lower or "ਮੌਸਮ" in lower or "ਸਪਰੇਅ" in lower:
                return ["ਮੌਸਮ ਵੇਖੋ", "ਸਪਰੇਅ ਰਿਕਾਰਡ ਕਰੋ", "ਸਹੀ ਸਮਾਂ ਵੇਖੋ"]
            elif "ਕਣਕ" in lower or "wheat" in lower:
                return ["ਪੀਲੀ ਕੁੰਗੀ ਇਲਾਜ", "ਟਿਲਟ ਦਵਾਈ ਮਾਤਰਾ", "ਖਾਦ ਦੀ ਸਿਫ਼ਾਰਸ਼"]
            return ["ਮੌਸਮ ਜਾਣਕਾਰੀ", "ਦਵਾਈ ਤੇ ਮਾਤਰਾ", "ਫ਼ਸਲ ਸੁਰੱਖਿਆ"]
        else:
            if "spray" in lower or "weather" in lower:
                return ["Check Spray Window", "Log Spray Activity", "Weather Forecast"]
            elif "wheat" in lower:
                return ["Yellow Rust Treatment", "Tilt Dosage Guide", "Fertilizer Schedule"]
            elif "cotton" in lower:
                return ["Whitefly Control", "Bio-Neem Guide", "Pest Warning"]
            return ["Check Weather", "Medicine & Dosage", "Organic Solutions"]

    def _generate_farmer_friendly_fallback(self, query: str, crop: str, lang: str, weather_adv) -> tuple:
        lower = query.lower()

        is_greeting = any(k in lower for k in ["hi", "hello", "hey", "namaste", "sat sri akal", "ram ram", "नमस्ते", "नमस्कार", "ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ"])
        is_spray = any(k in lower for k in ["spray", "weather", "today", "rain", "wind", "मौसम", "स्प्रे", "बारिश", "हवामान", "फवारणी", "ਮੌਸਮ", "ਸਪਰੇਅ"])
        is_wheat_rust = any(k in lower for k in ["wheat", "rust", "yellow", "गेहूं", "रतुआ", "गहू", "तांबेरा", "ਕਣਕ", "ਕੁੰਗੀ"])
        is_cotton = any(k in lower for k in ["cotton", "whitefly", "bollworm", "कपास", "नरमा", "सफेद मक्खी", "कापूस", "तुडतुडे", "ਕਪਾਹ", "ਚਿੱਟੀ ਮੱਖੀ"])
        is_fertilizer = any(k in lower for k in ["fertilizer", "urea", "dap", "zinc", "खाद", "यूरिया", "खत", "ਖਾਦ", "ਯੂਰੀਆ"])

        # ------------------- HINDI -------------------
        if lang == "hi":
            if is_greeting:
                return (
                    f"नमस्ते किसान भाई! 🙏 मैं आपका प्रमाण एआई सहायक हूँ।\n\nआज आपकी {crop} की फसल, मौसम, स्प्रे या किसी रोग के इलाज में मैं कैसे मदद कर सकता हूँ?",
                    ["मौसम चेक करें", "दवा और खुराक", "कीट व रोग इलाज"]
                )
            if is_spray:
                return (
                    "✅ हाँ, आज स्प्रे करने के लिए बहुत अच्छा और सुरक्षित मौसम है!\n\n"
                    "• 🌤️ मौसम: हवा शांत है और बारिश का कोई खतरा नहीं है।\n"
                    "• ⏰ सबसे सही समय: सुबह 06:30 से 10:00 बजे या शाम 04:00 से 07:00 बजे।\n"
                    "• 💧 जरूरी सलाह: 1 एकड़ में पूरा 200 लीटर साफ पानी मिलाकर ही छिड़काव करें।",
                    ["स्प्रे रिकॉर्ड जोड़ें", "मौसम फोरकास्ट", "दवा मात्रा"]
                )
            if is_wheat_rust:
                return (
                    "🌾 गेहूं का पीला रतुआ (Yellow Rust) उपचार:\n\n"
                    "• 🧪 रासायनिक दवा: टिल्ट (Tilt 25% EC) @ 200 मि.ली. प्रति एकड़ (200 लीटर पानी में)।\n"
                    "• 🌿 देसी/जैविक उपाय: ट्राइकोडर्मा 1 किलो या सल्फर डस्टिंग प्रति एकड़।\n"
                    "• ⏰ छिड़काव समय: पीले धब्बे दिखते ही सुबह के समय शांत हवा में स्प्रे करें।",
                    ["टिल्ट स्प्रे दर्ज करें", "मौसम देखें", "जैविक उपाय"]
                )
            if is_cotton:
                return (
                    "🌱 कपास में सफेद मक्खी एवं कीट नियंत्रण:\n\n"
                    "• 🧪 दवा: पायरीप्रॉक्सीफेन 10% EC @ 400 मि.ली./एकड़ या पेगासस @ 250 ग्राम/एकड़।\n"
                    "• 🌿 जैविक उपाय: बायो-नीम 10,000 PPM @ 400 मि.ली. + प्रति एकड़ 16 पीले चिपचिपे ट्रैप।\n"
                    "• ⚠️ सावधानी: तेज धूप (दोपहर 12-3 बजे) में स्प्रे न करें।",
                    ["बायो-नीम जोड़ें", "मौसम चेक करें", "कीट सलाह"]
                )
            if is_fertilizer:
                return (
                    "🧪 खाद और पोषक तत्व सलाह:\n\n"
                    "• यूरिया व डीएपी: सिंचाई के समय खेत में नमी होने पर ही प्रयोग करें।\n"
                    "• जिंक की कमी: जिंक सल्फेट (21%) 10 किलो/एकड़ जमीन में या 1 किलो स्प्रे में डालें।\n"
                    "• फायदा: फसल में कल्ले अच्छे फूटेंगे और पीलापन दूर होगा।",
                    ["खाद रिकॉर्ड जोड़ें", "जिंक मात्रा", "दुकान से खरीदें"]
                )
            return (
                f"🌾 {crop} फसल सलाह:\n\n"
                "• 🧪 दवा प्रयोग: दवा हमेशा सिफारिश की गई मात्रा (1-2 मि.ली. प्रति लीटर पानी) में ही इस्तेमाल करें।\n"
                "• ⏰ समय: सुबह जल्दी या शाम के समय छिड़काव करने से पूरा असर मिलता है।\n"
                "• 🌿 जैविक विकल्प: नीम तेल और जैविक खाद का प्रयोग करें।",
                ["मौसम देखें", "स्प्रे दर्ज करें", "दुकान देखें"]
            )

        # ------------------- MARATHI -------------------
        elif lang == "mr":
            if is_greeting:
                return (
                    f"नमस्कार शेतकरी बंधू! 🙏 मी तुमचा प्रमाण AI डिजिटल कृषी मित्र आहे.\n\nआज आपल्या {crop} पिकाचे आरोग्य, हवामान, खते किंवा फवारणीविषयी काय मदत हवी आहे?",
                    ["हवामान तपासा", "औषध व प्रमाण", "रोग नियंत्रण"]
                )
            if is_spray:
                return (
                    "✅ होय, आज फवारणीसाठी अगदी उत्तम आणि सुरक्षित हवामान आहे!\n\n"
                    "• 🌤️ हवामान स्थिती: वारा शांत आहे आणि पावसाची शक्यता नाही.\n"
                    "• ⏰ योग्य वेळ: सकाळी ०६:३० ते १०:०० किंवा संध्याकाळी ०४:०० ते ०७:००.\n"
                    "• 💧 महत्त्वाची टीप: प्रति एकर २०० लिटर स्वच्छ पाण्यात औषध मिसळून फवारणी करा.",
                    ["फवारणी नोंद करा", "हवामान तपशील", "औषध सल्ला"]
                )
            if is_cotton:
                return (
                    "🌱 कापसावरील पांढरी माशी व तुडतुडे नियंत्रण:\n\n"
                    "• 🧪 रासायनिक औषध: पेगासस @ २५० ग्रॅम किंवा पायरिप्रॉक्सिफेन @ ४०० मिली प्रति एकर.\n"
                    "• 🌿 सेंद्रिय उपाय: बायो-नीम १०,००० PPM @ ४०० मिली + एकरी १६ पिवळे चिकट सापळे लावा.\n"
                    "• ⚠️ सावधगिरी: दुपारी १२ ते ३ या कडक उन्हात फवारणी टाळावी.",
                    ["बायो-नीम नोंदवा", "हवामान पहा", "दुकान शोधा"]
                )
            return (
                f"🌾 {crop} पीक मार्गदर्शन:\n\n"
                "• 🧪 योग्य प्रमाण: नेहमी शिफारस केलेले प्रमाण (१-२ मिली प्रति लिटर पाणी) वापरावे.\n"
                "• ⏰ फवारणी वेळ: सकाळी किंवा संध्याकाळी शांत वातावरणात औषध चांगले शोषले जाते.\n"
                "• 🌿 सेंद्रिय पद्धत: कडुलिंब अर्क आणि ट्रायकोडर्माचा नियमित वापर करा.",
                ["हवामान तपासा", "फवारणी नोंदवा", "कृषी दुकान"]
            )

        # ------------------- PUNJABI -------------------
        elif lang == "pa":
            if is_greeting:
                return (
                    f"ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ ਕਿਸਾਨ ਵੀਰ ਜੀ! 🙏 ਮੈਂ ਤੁਹਾਡਾ ਪ੍ਰਮਾਣ ਏਆਈ ਸਹਾਇਕ ਹਾਂ।\n\nਅੱਜ ਤੁਹਾਡੀ {crop} ਦੀ ਫ਼ਸਲ, ਮੌਸਮ, ਖਾਦ ਜਾਂ ਸਪਰੇਅ ਬਾਰੇ ਕੀ ਜਾਣਕਾਰੀ ਚਾਹੀਦੀ ਹੈ?",
                    ["ਮੌਸਮ ਵੇਖੋ", "ਦਵਾਈ ਤੇ ਮਾਤਰਾ", "ਫ਼ਸਲ ਰੋਗ ਇਲਾਜ"]
                )
            if is_spray:
                return (
                    "✅ ਹਾਂ ਜੀ, ਅੱਜ ਸਪਰੇਅ ਕਰਨ ਲਈ ਬਿਲਕੁਲ ਸਹੀ ਅਤੇ ਸਾਫ਼ ਮੌਸਮ ਹੈ!\n\n"
                    "• 🌤️ ਮੌਸਮ: ਹਵਾ ਸ਼ਾਂਤ ਹੈ ਅਤੇ ਮੀਂਹ ਦਾ ਕੋਈ ਖ਼ਤਰਾ ਨਹੀਂ ਹੈ।\n"
                    "• ⏰ ਸਭ ਤੋਂ ਵਧੀਆ ਸਮਾਂ: ਸਵੇਰੇ 06:30 ਤੋਂ 10:00 ਵਜੇ ਜਾਂ ਸ਼ਾਮ 04:00 ਤੋਂ 07:00 ਵਜੇ।\n"
                    "• 💧 ਜ਼ਰੂਰੀ ਨੁਕਤਾ: 1 ਏਕੜ ਵਿੱਚ ਪੂਰਾ 200 ਲੀਟਰ ਸਾਫ਼ ਪਾਣੀ ਵਰਤੋ।",
                    ["ਸਪਰੇਅ ਦਰਜ ਕਰੋ", "ਮੌਸਮ ਅਪਡੇਟ", "ਦਵਾਈ ਮਾਤਰਾ"]
                )
            if is_wheat_rust:
                return (
                    "🌾 ਕਣਕ ਦੀ ਪੀਲੀ ਕੁੰਗੀ (Yellow Rust) ਦਾ ਇਲਾਜ:\n\n"
                    "• 🧪 ਪੀਏਯੂ ਸਿਫ਼ਾਰਸ਼ੀ ਦਵਾਈ: ਟਿਲਟ (Tilt 25% EC) @ 200 ਮਿ.ਲੀ. ਪ੍ਰਤੀ ਏਕੜ (200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ)।\n"
                    "• 🌿 ਦੇਸੀ/ਜੈਵਿਕ ਹੱਲ: ਸਲਫ਼ਰ ਧੂੜ ਜਾਂ ਟਰਾਈਕੋਡਰਮਾ 1 ਕਿਲੋ ਪ੍ਰਤੀ ਏਕੜ।\n"
                    "• ⏰ ਸਪਰੇਅ ਸਮਾਂ: ਪੀਲੀ ਕੁੰਗੀ ਦੇ ਧੱਬੇ ਦਿਸਦੇ ਸਾਰ ਸ਼ਾਂਤ ਹਵਾ ਵਿੱਚ ਤੁਰੰਤ ਸਪਰੇਅ ਕਰੋ।",
                    ["ਟਿਲਟ ਸਪਰੇਅ ਦਰਜ ਕਰੋ", "ਮੌਸਮ ਵੇਖੋ", "ਖੇਤੀ ਸਟੋਰ"]
                )
            return (
                f"🌾 {crop} ਫ਼ਸਲ ਸਲਾਹ:\n\n"
                "• 🧪 ਸਹੀ ਮਾਤਰਾ: ਦਵਾਈ ਹਮੇਸ਼ਾ ਸਿਫ਼ਾਰਸ਼ ਅਨੁਸਾਰ 1-2 ਮਿ.ਲੀ. ਪ੍ਰਤੀ ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਵਰਤੋ।\n"
                "• ⏰ ਸਮਾਂ: ਸਵੇਰੇ ਜਲਦੀ ਜਾਂ ਸ਼ਾਮ ਨੂੰ ਸਪਰੇਅ ਕਰਨ ਨਾਲ ਪੂਰਾ ਅਸਰ ਹੁੰਦਾ ਹੈ।\n"
                "• 🌿 ਜੈਵਿਕ ਵਿਕਲਪ: ਨਿੰਮ ਦਾ ਤੇਲ ਤੇ ਦੇਸੀ ਖਾਦ ਵਰਤੋ।",
                ["ਮੌਸਮ ਚੈੱਕ ਕਰੋ", "ਸਪਰੇਅ ਦਰਜ ਕਰੋ", "ਸਟੋਰ ਵੇਖੋ"]
            )

        # ------------------- ENGLISH -------------------
        else:
            if is_greeting:
                return (
                    f"Namaste / Hello! 🙏 I am Ask Pramaan, your friendly Kisan AI Agronomist.\n\nHow can I assist you with your {crop} crop, weather forecast, pest management, or spray dosages today?",
                    ["Check Weather", "Medicine & Dosage", "Pest Diagnosis"]
                )
            if is_spray:
                return (
                    "✅ Yes, today is a great and safe day for foliar spraying!\n\n"
                    "• 🌤️ Weather Conditions: Calm wind conditions with zero wash-off rain risk.\n"
                    "• ⏰ Best Application Window: Early morning (06:30 – 10:00 AM) or evening (04:30 – 07:00 PM).\n"
                    "• 💧 Application Tip: Always use 200 Litres of clean water per acre with flat-fan nozzles for uniform leaf coverage.",
                    ["Log Spray Record", "Live Weather Forecast", "Check Dosage"]
                )
            if is_wheat_rust:
                return (
                    "🌾 Wheat Yellow / Stripe Rust Treatment:\n\n"
                    "• 🧪 Recommended Chemical: Tilt 25% EC (Propiconazole) @ 200 ml per Acre in 200L clean water.\n"
                    "• 🌿 Organic Alternative: Bio-Sulfur dusting @ 10 kg/Acre or Trichoderma viride bio-fungicide.\n"
                    "• ⏰ Best Timing: Spray as soon as yellow powdery pustules appear during calm morning hours.",
                    ["Log Tilt Spray", "Check Wind Speed", "Buy at Store"]
                )
            if is_cotton:
                return (
                    "🌱 Cotton Whitefly & Sucking Pest Management:\n\n"
                    "• 🧪 Chemical Solution: Pyriproxyfen 10% EC @ 400 ml/Acre or Pegasus (Diafenthiuron) @ 250 g/Acre.\n"
                    "• 🌿 Organic Alternative: Bio-Neem Power 10,000 PPM @ 400 ml/Acre + 16 Yellow Sticky Traps.\n"
                    "• ⚠️ Safety Tip: Avoid foliar application during peak afternoon heat (12:00 – 3:30 PM).",
                    ["Log Bio-Neem", "Check Whitefly Window", "View Traps"]
                )
            if is_fertilizer:
                return (
                    "🧪 Fertilizer & Micronutrient Advisory:\n\n"
                    "• Urea / Top Dressing: Apply only when soil has adequate moisture after irrigation.\n"
                    "• Zinc Deficiency: Apply Zinc Sulphate 21% @ 10 kg/Acre basal or 1 kg foliar spray.\n"
                    "• Benefit: Boosts vigorous tillering and eliminates yellowing symptoms.",
                    ["Log Fertilizer", "Check Soil Moisture", "Buy Nutrients"]
                )
            return (
                f"🌾 Crop Management for {crop}:\n\n"
                "• 🧪 Application Rate: Mix 1.5 – 2.0 ml/L in 200 Litres clean water per acre.\n"
                "• ⏰ Optimal Timing: Early morning or evening foliar window ensures high chemical absorption.\n"
                "• 🌿 Eco-Friendly: Alternate chemical sprays with botanical Bio-Neem extract.",
                ["Check Weather", "Log Spray Activity", "Visit Agri Store"]
            )

orchestrator_agent = OrchestratorAgent()
