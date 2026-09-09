from fastapi import APIRouter, HTTPException, Query, Body, BackgroundTasks
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
# 1. FARMER AUTH & PROFILE (LOGIN / REGISTRATION)
# ----------------------------------------------------
@router.post("/login")
async def farmer_login(req: FarmerLoginRequest, background_tasks: BackgroundTasks):
    """
    Authenticate or register a farmer using their phone number directly in MongoDB Atlas.
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
        # Trigger background sync with sheets
        background_tasks.add_task(mongo_db.sync_with_google_sheets)
        
        return {
            "status": "success",
            "message": f"Welcome {farmer.get('name', req.name)}! Connected to PRAMAAN MongoDB.",
            "farmer": farmer,
            "database": "mongodb" if mongo_db.is_connected else "local_resilient_cache",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ----------------------------------------------------
# 2. GET ALL REGISTERED FARMERS / TEAMMATES
# ----------------------------------------------------
@router.get("/farmers")
async def get_all_registered_farmers():
    """
    Retrieves all registered farmer / teammate accounts persisted in MongoDB Atlas.
    """
    try:
        farmers = await mongo_db.get_all_farmers()
        return {
            "status": "success",
            "count": len(farmers),
            "farmers": farmers,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ----------------------------------------------------
# 3. MANUAL / AUTOMATED GOOGLE SHEETS <-> MONGODB SYNC
# ----------------------------------------------------
@router.get("/sync-sheets")
@router.post("/sync-sheets")
async def trigger_sheets_sync():
    """
    Triggers an immediate bidirectional sync between Google Sheets and MongoDB Atlas.
    """
    try:
        result = await mongo_db.sync_with_google_sheets()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sync failed: {e}")

# ----------------------------------------------------
# 4. OFFLINE BATCH SYNC
# ----------------------------------------------------
@router.post("/sync-batch")
async def sync_offline_batch_logs(req: BatchSyncRequest):
    """
    Synchronizes an entire queue of logs recorded offline in the field directly into MongoDB Atlas.
    """
    try:
        result = await mongo_db.save_batch_logs(req.logs)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Batch sync failed: {e}")

# ----------------------------------------------------
# 5. SAVE SINGLE FIELD EVIDENCE
# ----------------------------------------------------
@router.post("/log")
async def create_evidence_log(log: Dict[str, Any] = Body(...)):
    """
    Persist an individual spray, crop scan, or QR audit log to MongoDB Atlas.
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
# 6. GET FARMER'S FIELD LOGS
# ----------------------------------------------------
@router.get("/logs/{phone}")
async def get_farmer_logs(phone: str, limit: int = Query(50, ge=1, le=200)):
    """
    Retrieve all verified spray and crop logs for a specific farmer / teammate.
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
# 7. COMMUNITY AUDIT FEED
# ----------------------------------------------------
@router.get("/community")
async def get_community_logs(
    crop: Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
):
    """
    Returns public verified farmer evidence logs from MongoDB Atlas with optional crop and district filtering.
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
# 8. DB HEALTH STATUS
# ----------------------------------------------------
@router.get("/status")
async def get_database_status():
    """
    Returns live MongoDB Atlas connectivity status and statistics.
    """
    farmers_count = 0
    logs_count = 0
    if mongo_db.is_connected and mongo_db.db is not None:
        try:
            farmers_count = await mongo_db.db.farmers.count_documents({})
            logs_count = await mongo_db.db.evidence_logs.count_documents({})
        except Exception:
            pass

    return {
        "mongodb_connected": mongo_db.is_connected,
        "database_engine": "MongoDB Atlas Cluster" if mongo_db.is_connected else "Local High-Speed Cache",
        "total_farmers": farmers_count,
        "total_evidence_logs": logs_count,
        "offline_sync_ready": True,
    }
