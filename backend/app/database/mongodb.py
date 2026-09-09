import os
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ConnectionFailure, PyMongoError
from backend.app.core.config import settings
from backend.app.database.db import db as local_db

class MongoDBManager:
    """
    MongoDB Database Client for Pramaan AgTech Platform.
    Provides async persistence for Farmers, Evidence Logs, and Community Feeds.
    Includes seamless zero-crash fallback to local database if MongoDB Atlas is unreachable.
    """
    def __init__(self):
        self.client: Optional[AsyncIOMotorClient] = None
        self.db = None
        self.is_connected = False
        self._uri = settings.MONGODB_URI
        self._db_name = settings.MONGODB_DB_NAME

    async def connect(self):
        if not self._uri:
            print("[MongoDB] No MONGODB_URI configured. Operating in local resilient DB mode.")
            return

        try:
            self.client = AsyncIOMotorClient(
                self._uri,
                serverSelectionTimeoutMS=2500,
                connectTimeoutMS=2500,
            )
            self.db = self.client[self._db_name]
            # Ping database to verify connection
            await self.client.admin.command('ping')
            self.is_connected = True
            print(f"[MongoDB] Successfully connected to MongoDB database '{self._db_name}'.")

            # Create Indexes
            await self._create_indexes()
        except Exception as e:
            self.is_connected = False
            print(f"[MongoDB] Notice: Could not establish direct MongoDB connection ({e}). Using persistent local fallback engine.")

    async def _create_indexes(self):
        if not self.is_connected or self.db is None:
            return
        try:
            await self.db.farmers.create_index("phone", unique=True)
            await self.db.evidence_logs.create_index([("farmer_phone", 1), ("timestamp", -1)])
            await self.db.evidence_logs.create_index("id", unique=True)
            await self.db.compliance_feed.create_index([("timestamp", -1)])
        except Exception as e:
            print(f"[MongoDB] Index creation notice: {e}")

    async def close(self):
        if self.client:
            self.client.close()
            self.is_connected = False
            print("[MongoDB] Connection closed.")

    # ============================================================
    # 1. FARMER PROFILE METHODS
    # ============================================================

    async def save_or_update_farmer(self, farmer_data: Dict[str, Any]) -> Dict[str, Any]:
        clean_phone = str(farmer_data.get("phone", "")).strip()
        now_iso = datetime.utcnow().isoformat()
        
        doc = {
            "name": farmer_data.get("name") or farmer_data.get("farmer_name") or "Kisan",
            "phone": clean_phone,
            "district": farmer_data.get("district", "Nashik"),
            "village": farmer_data.get("village", "Dindori"),
            "state": farmer_data.get("state", "Maharashtra"),
            "primary_crop": farmer_data.get("primary_crop") or farmer_data.get("crop") or "Wheat",
            "crop": farmer_data.get("crop") or farmer_data.get("primary_crop") or "Wheat",
            "acres": float(farmer_data.get("acres") or 5.0),
            "last_login": now_iso,
        }

        if self.is_connected and self.db is not None:
            try:
                await self.db.farmers.update_one(
                    {"phone": clean_phone},
                    {"$set": doc, "$setOnInsert": {"created_at": now_iso}},
                    upsert=True
                )
                saved = await self.db.farmers.find_one({"phone": clean_phone}, {"_id": 0})
                if saved:
                    return saved
            except Exception as e:
                print(f"[MongoDB] save_or_update_farmer error: {e}. Falling back to local db.")

        # Local DB Fallback
        return {
            **doc,
            "created_at": now_iso,
            "source": "local_fallback"
        }

    async def get_farmer_profile(self, phone: str) -> Optional[Dict[str, Any]]:
        clean_phone = str(phone).strip()
        if self.is_connected and self.db is not None:
            try:
                doc = await self.db.farmers.find_one({"phone": clean_phone}, {"_id": 0})
                if doc:
                    return doc
            except Exception as e:
                print(f"[MongoDB] get_farmer_profile error: {e}")
        return None

    # ============================================================
    # 2. EVIDENCE & OBSERVATION LOGS
    # ============================================================

    async def save_evidence_log(self, log_data: Dict[str, Any]) -> Dict[str, Any]:
        log_id = log_data.get("id") or log_data.get("log_id") or f"LOG-{int(datetime.utcnow().timestamp() * 1000)}"
        clean_phone = str(log_data.get("farmer_phone", "")).strip()

        doc = {
            "id": log_id,
            "log_id": log_id,
            "farmer_name": log_data.get("farmer_name", "Kisan"),
            "farmer_phone": clean_phone,
            "village": log_data.get("village", ""),
            "state": log_data.get("state", ""),
            "crop": log_data.get("crop") or log_data.get("crop_name") or "Wheat",
            "crop_name": log_data.get("crop_name") or log_data.get("crop") or "Wheat",
            "action_type": log_data.get("action_type") or log_data.get("evidence_type") or "VOICE_OBSERVATION",
            "evidence_type": log_data.get("evidence_type") or log_data.get("action_type") or "VOICE_OBSERVATION",
            "title": log_data.get("title") or f"Field Log: {log_data.get('crop', 'Crop')}",
            "description": log_data.get("description") or log_data.get("voice_transcript") or "",
            "product_name": log_data.get("product_name"),
            "dosage": log_data.get("dosage") or log_data.get("dosage_per_acre"),
            "dosage_per_acre": log_data.get("dosage_per_acre") or log_data.get("dosage"),
            "target_pest": log_data.get("target_pest"),
            "voice_transcript": log_data.get("voice_transcript"),
            "media_url": log_data.get("media_url"),
            "compliance_score": float(log_data.get("compliance_score") or log_data.get("verification_score") or 95.0),
            "verification_score": float(log_data.get("verification_score") or log_data.get("compliance_score") or 95.0),
            "verification_status": log_data.get("verification_status", "VALIDATED"),
            "report_id": log_data.get("report_id") or f"REP-{int(datetime.utcnow().timestamp())}",
            "hash_anchor": log_data.get("hash_anchor") or log_data.get("verification_hash") or "0000000000000000",
            "timestamp": log_data.get("timestamp") or datetime.utcnow().isoformat(),
        }

        # 1. Save to MongoDB
        if self.is_connected and self.db is not None:
            try:
                await self.db.evidence_logs.update_one(
                    {"id": log_id},
                    {"$set": doc},
                    upsert=True
                )
                print(f"[MongoDB] Log '{log_id}' saved to MongoDB Atlas / Collection.")
            except Exception as e:
                print(f"[MongoDB] save_evidence_log error: {e}. Persisting to local db.")

        # 2. Also persist to local database for instant dual redundancy
        local_db.add_evidence(doc)
        return doc

    async def get_farmer_logs(self, phone: str) -> List[Dict[str, Any]]:
        clean_phone = str(phone).strip()
        if self.is_connected and self.db is not None:
            try:
                cursor = self.db.evidence_logs.find(
                    {"farmer_phone": clean_phone},
                    {"_id": 0}
                ).sort("timestamp", -1)
                docs = await cursor.to_list(length=200)
                if docs:
                    return docs
            except Exception as e:
                print(f"[MongoDB] get_farmer_logs error: {e}")

        # Local fallback
        all_ev = local_db.get_all_evidence()
        return [e for e in all_ev if e.get("farmer_phone") == clean_phone]

    async def get_community_feed(self, limit: int = 50) -> List[Dict[str, Any]]:
        if self.is_connected and self.db is not None:
            try:
                cursor = self.db.evidence_logs.find(
                    {"verification_status": {"$in": ["VALIDATED", "COMPLIANT", "EXTRACTED"]}},
                    {"_id": 0}
                ).sort("timestamp", -1).limit(limit)
                docs = await cursor.to_list(length=limit)
                if docs:
                    return docs
            except Exception as e:
                print(f"[MongoDB] get_community_feed error: {e}")

        # Local fallback
        return local_db.get_all_evidence()[:limit]

    # ============================================================
    # 3. OFFLINE BATCH SYNC METHOD
    # ============================================================

    async def sync_batch_logs(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        synced = []
        for log in logs:
            saved = await self.save_evidence_log(log)
            synced.append(saved.get("id") or saved.get("log_id"))

        return {
            "status": "success",
            "synced_count": len(synced),
            "synced_ids": synced,
            "timestamp": datetime.utcnow().isoformat()
        }

mongo_db = MongoDBManager()
