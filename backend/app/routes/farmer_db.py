from fastapi import APIRouter, HTTPException, Query, Body
from typing import List, Dict, Any, Optional
from backend.app.database.mongodb import mongo_db

router = APIRouter(prefix="/farmer", tags=["Farmer MongoDB Database & Offline Sync"])

@router.post("/auth")
async def farmer_auth(payload: Dict[str, Any] = Body(...)):
    """
    Farmer passwordless login or auto-registration stored in MongoDB Atlas.
    """
    phone = str(payload.get("phone") or payload.get("farmer_phone", "")).strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Farmer phone number is required")

    farmer = await mongo_db.save_or_update_farmer(payload)
    logs = await mongo_db.get_farmer_logs(phone)
    
    return {
        "status": "success",
        "is_new_farmer": False,
        "farmer": farmer,
        "logs": logs
    }

@router.get("/logs")
async def get_farmer_logs(
    phone: str = Query(..., description="Farmer phone number"),
    name: Optional[str] = Query(None, description="Farmer name")
):
    """
    Fetch all verified agricultural compliance & foliar logs for a specific farmer.
    """
    logs = await mongo_db.get_farmer_logs(phone)
    return {
        "status": "success",
        "farmer_phone": phone,
        "total_logs": len(logs),
        "logs": logs
    }

@router.post("/log-entry")
async def add_farmer_log_entry(payload: Dict[str, Any] = Body(...)):
    """
    Save a new voice observation, crop scan, or product application log to MongoDB Atlas.
    """
    saved_log = await mongo_db.save_evidence_log(payload)
    return {
        "status": "success",
        "message": "Log saved to MongoDB Atlas",
        "log": saved_log
    }

@router.get("/community-feed")
async def get_community_feed(limit: int = Query(50, ge=1, le=200)):
    """
    Fetch live community verified logs across all farmers from MongoDB Atlas.
    """
    logs = await mongo_db.get_community_feed(limit=limit)
    return {
        "status": "success",
        "total_logs": len(logs),
        "logs": logs
    }

@router.post("/sync-batch")
async def sync_offline_batch(payload: Dict[str, Any] = Body(...)):
    """
    Drains the offline queue from the mobile app and upserts all pending logs in bulk.
    """
    logs = payload.get("logs") or payload.get("pending_logs") or []
    if not isinstance(logs, list):
        raise HTTPException(status_code=400, detail="Invalid logs payload; expected list.")

    result = await mongo_db.sync_batch_logs(logs)
    return result
