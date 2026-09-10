from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.app.core.config import settings
from backend.app.routes import (
    orchestrator,
    voice,
    vision,
    validation,
    efficacy,
    weather,
    report,
    farm,
    adk_route,
    farmer_db,
    auth
)
from backend.app.database.mongodb import mongo_db

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="2.0.0",
    description="Multi-Agent AgTech Evidence Verification & Agronomy Platform API"
)

@app.on_event("startup")
async def startup_event():
    await mongo_db.connect()

@app.on_event("shutdown")
async def shutdown_event():
    await mongo_db.close()

# Enable CORS for Flutter Web & Mobile dev clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Router modules
app.include_router(auth.router, prefix="/api/auth")
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth")
app.include_router(orchestrator.router, prefix=settings.API_V1_STR)
app.include_router(voice.router, prefix=settings.API_V1_STR)
app.include_router(vision.router, prefix=settings.API_V1_STR)
app.include_router(validation.router, prefix=settings.API_V1_STR)
app.include_router(efficacy.router, prefix=settings.API_V1_STR)
app.include_router(weather.router, prefix=settings.API_V1_STR)
app.include_router(report.router, prefix=settings.API_V1_STR)
app.include_router(farm.router, prefix=settings.API_V1_STR)
app.include_router(adk_route.router, prefix=settings.API_V1_STR)
app.include_router(farmer_db.router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {
        "app": settings.PROJECT_NAME,
        "version": "2.0.0",
        "status": "online",
        "agents": [
            "Orchestrator Agent",
            "Voice Agent",
            "Vision Agent",
            "Validation Agent",
            "Efficacy Agent",
            "Weather Agent",
            "Report Agent"
        ]
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "pramaan-fastapi"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=True)
