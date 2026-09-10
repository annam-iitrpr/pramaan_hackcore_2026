# PRAMAAN AgTech Platform
## Verifiable Evidence Logging, AI Agronomy & Supply Chain Verification Platform

Pramaan is a full-stack AgTech platform combining mobile/web field logging, multi-agent AI verification, input product efficacy tracking, and tamper-proof buyer compliance certificates.

---

## 🌟 Key Capabilities
- **Multi-Modal Evidence Capture Suite**:
  - Voice logging in 6 Indian languages (Hindi, Marathi, Telugu, Punjabi, Gujarati, English) with real-time entity & slot parsing.
  - Guided crop camera with GPS HUD and automated disease/pest diagnostics via Google Gemini Vision AI.
  - QR & Barcode scanner for authenticating agrochemical batches and calculating Pre-Harvest Interval (PHI) compliance.
  - New observation & precision chemical application forms.
- **7-Agent AI Ensemble (FastAPI + Python)**:
  1. **Voice Agent**: Multilingual STT & intent extraction.
  2. **Vision Agent**: Crop pathology diagnosis, severity ranking, and active ingredient recommendations.
  3. **Validation Agent**: Cryptographic SHA-256 seal generator, geo-fence matching, and timestamp consistency checks.
  4. **Efficacy Agent**: Pre vs. Post application pest mortality & canopy vitality (NDVI proxy) compute.
  5. **Weather Agent**: Meteoblue weather intelligence & real-time spray window recommendations.
  6. **Report Agent**: Official tamper-evident PDF audit certificate & JSON proof generation.
  7. **Orchestrator Agent**: Multi-turn conversational agronomy assistant ("Ask Pramaan").
- **Supply Chain Traceability & Buyer Premium**:
  - Lot valuation calculator unlocking Grade A+ export price premiums (+₹450/Qtl) for certified sustainable harvests.
  - Geospatial field map with NDVI stress layer and evidence marker pins.
  - Offline sync center with local caching queue.
  - Continuous learning loop for agronomists to refine AI models.

---

## 🚀 Running the Platform

### 1. Start the FastAPI Backend
```bash
# From workspace root:
python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```
API Documentation available at: `http://127.0.0.1:8000/docs`

### 2. Launch the Flutter Client (Mobile & Web)
```bash
# Navigate to frontend directory:
cd frontend

# Run in Chrome / Web:
flutter run -d chrome

# Or run on connected Android/iOS device:
flutter run
```

---

## 📁 Repository Structure
```
├── backend/
│   ├── app/
│   │   ├── main.py                     # FastAPI Master Entrypoint & CORS
│   │   ├── core/                       # App Configuration & Env Loader
│   │   ├── models/schemas.py           # Pydantic Schemas
│   │   ├── database/                   # DB Manager & Seed Catalog
│   │   ├── ai/                         # 7 Specialized AI Agents
│   │   │   ├── orchestrator.py
│   │   │   ├── voice_agent.py
│   │   │   ├── vision_agent.py
│   │   │   ├── validation_agent.py
│   │   │   ├── efficacy_agent.py
│   │   │   ├── weather_agent.py
│   │   │   └── report_agent.py
│   │   └── routes/                     # REST API Endpoints
│   └── tests/                          # Backend Test Suite
├── frontend/
│   ├── lib/
│   │   ├── main.dart                   # Master Routes & Providers
│   │   ├── core/                       # Theme, Services & State Providers
│   │   ├── models/                     # Dart Domain Models
│   │   ├── widgets/                    # Custom Nav, Badges, Waveform
│   │   └── screens/                    # 24+ Screen Specifications
│   └── test/                           # Flutter Widget Tests
```
