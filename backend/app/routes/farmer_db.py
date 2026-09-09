from fastapi import APIRouter, HTTPException, Query, Body
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from backend.app.database.mongodb import mongo_db

router = APIRouter(prefix="/farmer-db", tags=["MongoDB Farmer & Offline Sync"])

class FarmerLoginRequest(BaseModel):
    name: str = Field(..., description="Farmer full name")
    phone: str = Field(..., description="10-digit mobile number")
    district: Optional[str] = "Nashik"
    village: Optional[str] = "Nashik"
    state: Optional[str] = "Maharashtra"
    primary_crop: Optional[str] = "Cotton"
    crop: Optional[str] = None
    acres: Optional[float] = 10.0

class BatchSyncRequest(BaseModel):
    phone: Optional[str] = None
    logs: List[Dict[str, Any]] = Field(..., description="List of offline field logs created without internet")

class SingleEvidenceLog(BaseModel):
    id: Optional[str] = None
    phone: str = Field(..., description="Farmer mobile number")
    title: str
    description: Optional[str] = ""
    evidence_type: str = "SPRAY_LOG"
    product_name: Optional[str] = ""
    dosage: Optional[str] = ""
    crop: Optional[str] = "Wheat"
    district: Optional[str] = "Ludhiana"
    media_url: Optional[str] = None
    verification_status: Optional[str] = "VERIFIED"
    verification_score: Optional[float] = 1.0

# ----------------------------------------------------
# 1. FARMER AUTH & PROFILE
# ----------------------------------------------------
@router.post("/login")
async def farmer_login(req: FarmerLoginRequest):
    """
    Authenticate or register a farmer using their phone number in MongoDB.
    """
    try:
        farmer = await mongo_db.get_or_create_farmer(
            phone=req.phone,
            name=req.name,
            district=req.district or req.village or "Nashik",
            state=req.state or "Maharashtra",
            crop=req.crop or req.primary_crop or "Cotton",
            acres=req.acres or 10.0,
        )
        return {
            "status": "success",
            "message": f"Welcome {farmer.get('name', req.name)}! Connected to PRAMAAN MongoDB.",
            "farmer": farmer,
            "database": "mongodb" if mongo_db.is_connected else "local_resilient_cache",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ----------------------------------------------------
# 2. OFFLINE BATCH SYNC
# ----------------------------------------------------
@router.post("/sync-batch")
async def sync_offline_batch_logs(req: BatchSyncRequest):
    """
    Synchronizes an entire queue of logs recorded offline in the field directly into MongoDB.
    """
    try:
        result = await mongo_db.save_batch_logs(req.logs)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Batch sync failed: {e}")

# ----------------------------------------------------
# 3. SAVE SINGLE FIELD EVIDENCE
# ----------------------------------------------------
@router.post("/log")
async def create_evidence_log(log: Dict[str, Any] = Body(...)):
    """
    Persist an individual spray, crop scan, or QR audit log to MongoDB.
    """
    try:
        saved = await mongo_db.save_evidence_log(log)
        return {
            "status": "success",
            "log": saved,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ----------------------------------------------------
# 4. GET FARMER'S FIELD LOGS
# ----------------------------------------------------
@router.get("/logs/{phone}")
async def get_farmer_logs(phone: str, limit: int = Query(50, ge=1, le=200)):
    """
    Retrieve all verified spray and crop logs for a specific farmer.
    """
    try:
        logs = await mongo_db.get_farmer_logs(phone=phone, limit=limit)
        return {
            "status": "success",
            "phone": phone,
            "count": len(logs),
            "logs": logs,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ----------------------------------------------------
# 5. COMMUNITY AUDIT FEED
# ----------------------------------------------------
@router.get("/community")
async def get_community_logs(
    crop: Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    limit: int = Query(40, ge=1, le=100),
):
    """
    Returns public verified farmer evidence logs from MongoDB with optional crop and district filtering.
    """
    try:
        feed = await mongo_db.get_community_feed(crop=crop, district=district, limit=limit)
        return {
            "status": "success",
            "count": len(feed),
            "records": feed,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ----------------------------------------------------
# 6. DB HEALTH STATUS
# ----------------------------------------------------
@router.get("/status")
async def get_database_status():
    """
    Returns live MongoDB connectivity status and statistics.
    """
    return {
        "mongodb_connected": mongo_db.is_connected,
        "database_engine": "MongoDB Atlas / Engine" if mongo_db.is_connected else "Local High-Speed Cache",
        "offline_sync_ready": True,
    }
