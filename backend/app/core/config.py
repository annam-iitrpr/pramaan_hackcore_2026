import os
from pathlib import Path
from dotenv import load_dotenv

# Search for .env in current directory or root workspace
env_path = Path(__file__).resolve().parent.parent.parent.parent / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
else:
    load_dotenv()

class Settings:
    PROJECT_NAME: str = "PRAMAAN AgTech AI Platform"
    API_V1_STR: str = "/api/v1"
    METEOBLUE_API_KEY: str = os.getenv("METEOBLUE_API_KEY", "")
    CEHUB_API_KEY: str = os.getenv("CEHUB_API_KEY", "")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GOOGLE_APPS_SCRIPT_URL: str = os.getenv(
        "GOOGLE_APPS_SCRIPT_URL",
        "https://script.google.com/macros/s/AKfycbyOODzqfRrLXNPV4BB7av2P4DncYniqln-Qy98CauxCsxeGiNe_zX1sF9_PmToi92QJ/exec"
    )
    MONGODB_URI: str = os.getenv(
        "MONGODB_URI",
        "mongodb://127.0.0.1:27017/pramaan_db"
    )
    MONGODB_DB_NAME: str = os.getenv("MONGODB_DB_NAME", "pramaan_db")
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")

    # Twilio Verify Settings
    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_VERIFY_SERVICE_SID: str = os.getenv("TWILIO_VERIFY_SERVICE_SID", "")

    DATA_DIR: Path = Path(__file__).resolve().parent.parent / "data"

settings = Settings()
settings.DATA_DIR.mkdir(parents=True, exist_ok=True)

