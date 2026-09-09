import json
import hashlib
from typing import List, Dict, Any, Optional
from datetime import datetime
from backend.app.core.config import settings
from backend.app.database.seed_data import (
    SAMPLE_FARMS,
    SAMPLE_PRODUCTS,
    SAMPLE_EVIDENCE,
    SAMPLE_SEASON_JOURNAL,
    SAMPLE_NOTIFICATIONS,
)

class InMemoryDatabase:
    def __init__(self):
        self.farms: List[Dict[str, Any]] = list(SAMPLE_FARMS)
        self.products: List[Dict[str, Any]] = list(SAMPLE_PRODUCTS)
        self.evidence: List[Dict[str, Any]] = list(SAMPLE_EVIDENCE)
        self.journal: List[Dict[str, Any]] = list(SAMPLE_SEASON_JOURNAL)
        self.notifications: List[Dict[str, Any]] = list(SAMPLE_NOTIFICATIONS)
        self.learning_loop_feedback: List[Dict[str, Any]] = []

    def get_all_farms(self) -> List[Dict[str, Any]]:
        return self.farms

    def get_farm_by_id(self, farm_id: str) -> Optional[Dict[str, Any]]:
        for f in self.farms:
            if f["id"] == farm_id:
                return f
        return None

    def get_all_evidence(self, farm_id: Optional[str] = None) -> List[Dict[str, Any]]:
        if farm_id:
            return [e for e in self.evidence if e["farm_id"] == farm_id]
        return self.evidence

    def get_evidence_by_id(self, evidence_id: str) -> Optional[Dict[str, Any]]:
        for e in self.evidence:
            if e["id"] == evidence_id:
                return e
        return None

    def add_evidence(self, item: Dict[str, Any]) -> Dict[str, Any]:
        # Compute SHA-256 hash if not present
        if not item.get("verification_hash"):
            payload_str = f"{item.get('id')}:{item.get('timestamp')}:{item.get('farm_id')}:{item.get('title')}"
            item["verification_hash"] = hashlib.sha256(payload_str.encode()).hexdigest()
        self.evidence.insert(0, item)
        return item

    def update_evidence_status(self, evidence_id: str, status: str, score: float, reasons: List[str] = None) -> Optional[Dict[str, Any]]:
        for e in self.evidence:
            if e["id"] == evidence_id:
                e["verification_status"] = status
                e["verification_score"] = score
                if reasons:
                    e["flag_reasons"] = reasons
                return e
        return None

    def get_all_products(self) -> List[Dict[str, Any]]:
        return self.products

    def find_product_by_code(self, code: str) -> Optional[Dict[str, Any]]:
        for p in self.products:
            if p["qr_code"] == code or p["barcode"] == code:
                return p
        return None

    def get_journal(self, farm_id: Optional[str] = "farm-101") -> List[Dict[str, Any]]:
        return [j for j in self.journal if not farm_id or j.get("farm_id") == farm_id]

    def add_journal_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        self.journal.append(entry)
        return entry

    def get_notifications(self) -> List[Dict[str, Any]]:
        return self.notifications

    def add_feedback(self, feedback: Dict[str, Any]) -> Dict[str, Any]:
        feedback["timestamp"] = datetime.utcnow().isoformat() + "Z"
        self.learning_loop_feedback.append(feedback)
        return feedback

db = InMemoryDatabase()
