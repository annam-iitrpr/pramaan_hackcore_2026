from fastapi import APIRouter, HTTPException
from typing import List, Dict, Any, Optional
from backend.app.models.schemas import BuyerPricingRequest, BuyerPricingResponse
from backend.app.database.db import db

router = APIRouter(prefix="/farm", tags=["Farms, Products, Journal & Pricing"])

@router.get("/farms", response_model=List[Dict[str, Any]])
def list_farms():
    return db.get_all_farms()

@router.get("/farms/{farm_id}", response_model=Dict[str, Any])
def get_farm(farm_id: str):
    farm = db.get_farm_by_id(farm_id)
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found")
    return farm

@router.get("/products", response_model=List[Dict[str, Any]])
def list_products():
    return db.get_all_products()

@router.get("/products/lookup/{code}", response_model=Dict[str, Any])
def lookup_product(code: str):
    prod = db.find_product_by_code(code)
    if not prod:
        raise HTTPException(status_code=404, detail=f"Product with code '{code}' not registered")
    return prod

@router.get("/journal", response_model=List[Dict[str, Any]])
def get_season_journal(farm_id: Optional[str] = "farm-101"):
    return db.get_journal(farm_id)

@router.post("/journal/create")
def add_journal_entry(entry: Dict[str, Any]):
    return db.add_journal_entry(entry)

@router.get("/notifications", response_model=List[Dict[str, Any]])
def get_notifications():
    return db.get_notifications()

@router.post("/buyer-pricing", response_model=BuyerPricingResponse)
def calculate_buyer_pricing(request: BuyerPricingRequest):
    base_mandi = 7400.0 if request.crop.lower() == "cotton" else 2275.0 # MSP Wheat
    
    # Premium scaling based on compliance score
    if request.compliance_score >= 95.0:
        premium = 450.0
        grade = "Grade A+ (Export / Zero Residue Compliant)"
    elif request.compliance_score >= 85.0:
        premium = 250.0
        grade = "Grade A (Traceable Quality Assured)"
    else:
        premium = 0.0
        grade = "Standard Commercial"

    total_rate = base_mandi + premium
    lot_val = total_rate * request.quantity_quintals

    advantages = [
        "100% Cryptographically verified Pre-Harvest Interval (PHI) logs.",
        "Zero prohibited agrochemical residue risk.",
        "Traceable directly to plot coordinates with timestamped evidence.",
        "Instant issuance of tamper-proof blockchain audit certificate."
    ]

    return BuyerPricingResponse(
        base_mandi_price_per_qtl=base_mandi,
        pramaan_verified_premium_per_qtl=premium,
        total_rate_per_qtl=total_rate,
        total_lot_value_inr=lot_val,
        purity_grade=grade,
        traceability_seal_url="/assets/images/pramaan_seal.png",
        buyer_advantages=advantages
    )
