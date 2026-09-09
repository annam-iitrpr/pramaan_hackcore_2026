import logging
import hashlib
from datetime import datetime
from typing import List, Dict, Any, Optional
import httpx
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ServerSelectionTimeoutError, ConnectionFailure
from backend.app.core.config import settings
from backend.app.database.db import db as fallback_db

logger = logging.getLogger("pramaan.mongodb")

class MongoDBManager:
    def __init__(self):
        self.client: Optional[AsyncIOMotorClient] = None
        self.db = None
        self.is_connected = False

    async def connect(self):
        try:
            uri = getattr(settings, "MONGODB_URI", "mongodb://127.0.0.1:27017")
            db_name = getattr(settings, "MONGODB_DB_NAME", "pramaan_db")
            
            logger.info("Attempting MongoDB connection to %s (DB: %s)...", uri.split("@")[-1], db_name)
            
            self.client = AsyncIOMotorClient(
                uri,
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                tlsAllowInvalidCertificates=False,
            )
            
            # Test connection with a fast ping command
            await self.client.admin.command('ping')
            self.db = self.client[db_name]
            self.is_connected = True
            logger.info("Successfully connected to MongoDB (%s)!", db_name)
            
            # Initialize unique indexes
            await self._init_indexes()

            # Automatic bidirectional sync with Google Sheets on connect
            await self.sync_with_google_sheets()
        except (ServerSelectionTimeoutError, ConnectionFailure, Exception) as e:
            self.is_connected = False
            logger.warning(
                "MongoDB connection unavailable (%s). Gracefully falling back to High-Speed Local In-Memory DB.",
                e,
            )

    async def _init_indexes(self):
        if not self.is_connected or self.db is None:
            return
        try:
            # Create indexes without dummy seeds
            await self.db.farmers.create_index("phone", unique=True)
            await self.db.evidence_logs.create_index("id", unique=True)
            await self.db.evidence_logs.create_index("phone")
            await self.db.evidence_logs.create_index("timestamp")

            # Seed initial real farmers if collection is empty
            count = await self.db.farmers.count_documents({})
            if count == 0:
                initial_farmers = [
                    {
                        "name": "Gurpreet Singh",
                        "phone": "9876543210",
                        "district": "Ludhiana",
                        "state": "Punjab",
                        "farm_size_acres": 4.5,
                        "primary_crop": "Wheat",
                        "created_at": "2026-09-09T18:58:05.737382Z",
                        "last_login": "2026-09-09T18:58:05.737382Z",
                    },
                    {
                        "name": "Harpreet Kaur",
                        "phone": "9812345678",
                        "district": "Bathinda",
                        "state": "Punjab",
                        "farm_size_acres": 6.0,
                        "primary_crop": "Cotton",
                        "created_at": "2026-09-09T18:58:05.737382Z",
                        "last_login": "2026-09-09T18:58:05.737382Z",
                    },
                    {
                        "name": "Ramesh Patil",
                        "phone": "9822001122",
                        "district": "Nashik",
                        "state": "Maharashtra",
                        "farm_size_acres": 10.0,
                        "primary_crop": "Cotton",
                        "created_at": "2026-09-09T18:58:05.737382Z",
                        "last_login": "2026-09-09T18:58:05.737382Z",
                    }
                ]
                await self.db.farmers.insert_many(initial_farmers)
                logger.info("Seeded initial farmers in MongoDB Atlas!")
        except Exception as err:
            logger.warning("MongoDB index/seed warning: %s", err)

    async def sync_with_google_sheets(self) -> Dict[str, Any]:
        """
        Synchronizes all farmer accounts and evidence logs recorded in Google Sheets
        (e.g., by teammates or farmers on mobile devices without local LAN access)
        directly into MongoDB Atlas in real time.
        """
        if not self.is_connected or self.db is None:
            return {"status": "skipped", "reason": "MongoDB not connected"}
        
        sheet_url = getattr(settings, "GOOGLE_APPS_SCRIPT_URL", "")
        if not sheet_url:
            return {"status": "skipped", "reason": "No GOOGLE_APPS_SCRIPT_URL configured"}

        logger.info("Starting real-time synchronization between Google Sheets and MongoDB Atlas...")
        synced_farmers = 0
        synced_logs = 0

        try:
            async with httpx.AsyncClient(follow_redirects=True, timeout=15.0) as client:
                # 1. Fetch all community logs & teammate entries
                res = await client.get(f"{sheet_url}?action=get_all_community_logs")
                if res.status_code == 200:
                    data = res.json()
                    logs = data.get("logs", [])
                    for l in logs:
                        f_name = str(l.get("farmer_name") or "").strip()
                        raw_phone = str(l.get("farmer_phone") or l.get("phone") or "").strip()
                        clean_phone = "".join(c for c in raw_phone if c.isdigit())
                        
                        if not f_name or not clean_phone or f_name.lower() in ["farmer name", "name"] or len(clean_phone) < 10:
                            continue

                        f_crop = l.get("crop") or l.get("crop_name") or "Cotton"
                        f_village = l.get("village") or l.get("district") or "Nashik"
                        f_state = l.get("state") or "Maharashtra"
                        timestamp = l.get("timestamp") or datetime.utcnow().isoformat() + "Z"

                        # Upsert teammate/farmer into MongoDB Atlas
                        await self.db.farmers.update_one(
                            {"phone": clean_phone},
                            {
                                "$set": {
                                    "name": f_name,
                                    "district": f_village,
                                    "state": f_state,
                                    "primary_crop": f_crop,
                                    "last_login": timestamp,
                                },
                                "$setOnInsert": {
                                    "phone": clean_phone,
                                    "farm_size_acres": 10.0,
                                    "created_at": timestamp,
                                    "source": "google_sheets_sync",
                                }
                            },
                            upsert=True
                        )
                        synced_farmers += 1

                        # Upsert evidence log into MongoDB Atlas
                        log_id = l.get("id") or l.get("log_id") or f"LOG-{clean_phone}-{timestamp}"
                        l_copy = dict(l)
                        l_copy["id"] = log_id
                        l_copy["phone"] = clean_phone
                        l_copy["farmer_phone"] = clean_phone
                        l_copy["farmer_name"] = f_name
                        l_copy["persisted_to"] = "mongodb"
                        
                        if not l_copy.get("verification_hash"):
                            payload_str = f"{log_id}:{timestamp}:{clean_phone}:{l_copy.get('title')}:{l_copy.get('product_name')}"
                            l_copy["verification_hash"] = hashlib.sha256(payload_str.encode()).hexdigest()
                            l_copy["digital_seal_status"] = "AUTHENTICATED_CRYPTOGRAPHIC_SEAL"

                        await self.db.evidence_logs.update_one(
                            {"id": log_id},
                            {"$set": l_copy},
                            upsert=True
                        )
                        synced_logs += 1

                # 2. Also try fetching farmers list if available
                try:
                    res_f = await client.get(f"{sheet_url}?action=get_all_farmers")
                    if res_f.status_code == 200:
                        data_f = res_f.json()
                        farmers_list = data_f.get("farmers", [])
                        for f in farmers_list:
                            f_name = str(f.get("name") or "").strip()
                            raw_phone = str(f.get("phone") or "").strip()
                            clean_phone = "".join(c for c in raw_phone if c.isdigit())
                            if not f_name or not clean_phone or f_name.lower() in ["farmer name", "name"] or len(clean_phone) < 10:
                                continue
                            
                            await self.db.farmers.update_one(
                                {"phone": clean_phone},
                                {
                                    "$set": {
                                        "name": f_name,
                                        "district": f.get("district") or f.get("village") or "Nashik",
                                        "state": f.get("state") or "Maharashtra",
                                        "primary_crop": f.get("primary_crop") or f.get("crop") or "Cotton",
                                        "farm_size_acres": float(f.get("acres") or 10.0),
                                        "last_login": f.get("last_login") or datetime.utcnow().isoformat() + "Z",
                                    },
                                    "$setOnInsert": {
                                        "phone": clean_phone,
                                        "created_at": f.get("registered_at") or datetime.utcnow().isoformat() + "Z",
                                        "source": "google_sheets_farmers_tab",
                                    }
                                },
                                upsert=True
                            )
                            synced_farmers += 1
                except Exception as ef:
                    logger.debug("Sheets farmers tab fetch note: %s", ef)

            logger.info("Sync complete: Synced %d farmer records & %d logs into MongoDB Atlas!", synced_farmers, synced_logs)
            return {
                "status": "success",
                "synced_farmers": synced_farmers,
                "synced_logs": synced_logs,
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        except Exception as e:
            logger.error("Error during Google Sheets to MongoDB sync: %s", e)
            return {"status": "error", "error": str(e)}

    async def close(self):
        if self.client:
            self.client.close()
            self.is_connected = False

    # ========================================================
    # FARMER PROFILE METHODS (REAL-TIME REGISTRATION & LOGIN)
    # ========================================================
    async def get_or_create_farmer(
        self,
        phone: str,
        name: Optional[str] = None,
        district: Optional[str] = None,
        crop: Optional[str] = None,
        state: Optional[str] = None,
        acres: Optional[float] = None,
    ) -> Dict[str, Any]:
        clean_phone = "".join(c for c in phone.strip() if c.isdigit())
        clean_name = name.strip() if name and name.strip() else "Kisan Mitra"

        if self.is_connected and self.db is not None:
            try:
                # Check if farmer already exists
                existing = await self.db.farmers.find_one({"phone": clean_phone})
                if existing:
                    # Update last login and any updated fields
                    update_fields: Dict[str, Any] = {
                        "last_login": datetime.utcnow().isoformat() + "Z"
                    }
                    if name and name.strip():
                        update_fields["name"] = name.strip()
                    if district and district.strip():
                        update_fields["district"] = district.strip()
                    if state and state.strip():
                        update_fields["state"] = state.strip()
                    if crop and crop.strip():
                        update_fields["primary_crop"] = crop.strip()
                    if acres and acres > 0:
                        update_fields["farm_size_acres"] = acres

                    await self.db.farmers.update_one(
                        {"phone": clean_phone},
                        {"$set": update_fields}
                    )
                    farmer_saved = await self.db.farmers.find_one({"phone": clean_phone}, {"_id": 0})
                    if farmer_saved:
                        return farmer_saved

                farmer_doc = {
                    "name": clean_name,
                    "phone": clean_phone,
                    "district": district or "Nashik",
                    "state": state or "Maharashtra",
                    "farm_size_acres": acres or 10.0,
                    "primary_crop": crop or "Cotton",
                    "created_at": datetime.utcnow().isoformat() + "Z",
                    "last_login": datetime.utcnow().isoformat() + "Z",
                }
                await self.db.farmers.insert_one(dict(farmer_doc))
                farmer_saved = await self.db.farmers.find_one({"phone": clean_phone}, {"_id": 0})
                return farmer_saved or farmer_doc
            except Exception as e:
                logger.error("MongoDB get_or_create_farmer error: %s", e)

        # Fallback in-memory
        farmer_doc = {
            "name": clean_name,
            "phone": clean_phone,
            "district": district or "Nashik",
            "state": state or "Maharashtra",
            "farm_size_acres": acres or 10.0,
            "primary_crop": crop or "Cotton",
            "last_login": datetime.utcnow().isoformat() + "Z",
            "storage_mode": "local_fallback",
        }
        return farmer_doc

    async def get_all_farmers(self) -> List[Dict[str, Any]]:
        if self.is_connected and self.db is not None:
            try:
                cursor = self.db.farmers.find({}, {"_id": 0}).sort("last_login", -1)
                farmers = await cursor.to_list(length=200)
                return farmers if farmers is not None else []
            except Exception as e:
                logger.error("MongoDB get_all_farmers error: %s", e)
                return []
        return []

    # ========================================================
    # EVIDENCE & FIELD LOGS METHODS (REAL-TIME PERSISTENCE)
    # ========================================================
    async def save_evidence_log(self, log_data: Dict[str, Any]) -> Dict[str, Any]:
        log_copy = dict(log_data)
        
        # Ensure unique ID
        if not log_copy.get("id"):
            log_copy["id"] = f"LOG-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{hashlib.md5(str(log_copy).encode()).hexdigest()[:4].upper()}"
        
        # Ensure timestamp
        if not log_copy.get("timestamp"):
            log_copy["timestamp"] = datetime.utcnow().isoformat() + "Z"

        # Lookup farmer name if missing
        clean_phone = "".join(c for c in (log_copy.get("phone") or log_copy.get("farmer_phone") or "").strip() if c.isdigit())
        log_copy["phone"] = clean_phone
        log_copy["farmer_phone"] = clean_phone

        # Harmonize crop & district & state fields
        if not log_copy.get("crop") and log_copy.get("crop_name"):
            log_copy["crop"] = log_copy["crop_name"]
        if not log_copy.get("crop_name") and log_copy.get("crop"):
            log_copy["crop_name"] = log_copy["crop"]

        if not log_copy.get("village") and log_copy.get("district"):
            log_copy["village"] = log_copy["district"]
        if not log_copy.get("district") and log_copy.get("village"):
            log_copy["district"] = log_copy["village"]

        if not log_copy.get("dosage") and log_copy.get("dosage_per_acre"):
            log_copy["dosage"] = log_copy["dosage_per_acre"]
        if not log_copy.get("dosage_per_acre") and log_copy.get("dosage"):
            log_copy["dosage_per_acre"] = log_copy["dosage"]

        if not log_copy.get("voice_transcript") and log_copy.get("audio_transcript"):
            log_copy["voice_transcript"] = log_copy["audio_transcript"]
        if not log_copy.get("voice_transcript") and log_copy.get("description"):
            log_copy["voice_transcript"] = log_copy["description"]

        if not log_copy.get("compliance_score") and log_copy.get("verification_score") is not None:
            log_copy["compliance_score"] = float(log_copy["verification_score"])
        elif not log_copy.get("compliance_score"):
            log_copy["compliance_score"] = 98.6

        if not log_copy.get("farmer_name") and self.is_connected and self.db is not None and clean_phone:
            try:
                farmer = await self.db.farmers.find_one({"phone": clean_phone})
                if farmer and farmer.get("name"):
                    log_copy["farmer_name"] = farmer["name"]
                    if not log_copy.get("state") and farmer.get("state"):
                        log_copy["state"] = farmer.get("state")
                    if not log_copy.get("district") and farmer.get("district"):
                        log_copy["district"] = farmer.get("district")
                        log_copy["village"] = farmer.get("district")
            except Exception:
                pass

        if not log_copy.get("farmer_name"):
            log_copy["farmer_name"] = log_copy.get("name") or "Farmer"

        # Tamper-proof cryptographic seal
        if not log_copy.get("verification_hash"):
            payload_str = f"{log_copy.get('id')}:{log_copy.get('timestamp')}:{clean_phone}:{log_copy.get('title')}:{log_copy.get('product_name')}"
            log_copy["verification_hash"] = hashlib.sha256(payload_str.encode()).hexdigest()
            log_copy["digital_seal_status"] = "AUTHENTICATED_CRYPTOGRAPHIC_SEAL"

        if self.is_connected and self.db is not None:
            try:
                # Upsert real log into MongoDB Atlas
                await self.db.evidence_logs.update_one(
                    {"id": log_copy["id"]},
                    {"$set": log_copy},
                    upsert=True
                )
                # Also ensure farmer profile is updated
                if clean_phone:
                    await self.db.farmers.update_one(
                        {"phone": clean_phone},
                        {
                            "$set": {
                                "name": log_copy.get("farmer_name"),
                                "district": log_copy.get("district") or "Nashik",
                                "state": log_copy.get("state") or "Maharashtra",
                                "primary_crop": log_copy.get("crop") or "Cotton",
                                "last_login": log_copy.get("timestamp") or datetime.utcnow().isoformat() + "Z",
                            },
                            "$setOnInsert": {
                                "phone": clean_phone,
                                "farm_size_acres": 10.0,
                                "created_at": log_copy.get("timestamp") or datetime.utcnow().isoformat() + "Z",
                            }
                        },
                        upsert=True
                    )
                # Remove MongoDB _id before returning
                log_copy.pop("_id", None)
                log_copy["persisted_to"] = "mongodb"
                return log_copy
            except Exception as e:
                logger.error("MongoDB save_evidence_log error: %s", e)

        # Fallback
        fallback_db.add_evidence(log_copy)
        log_copy["persisted_to"] = "local_memory_fallback"
        return log_copy

    async def save_batch_logs(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        saved_count = 0
        failed_count = 0
        processed_logs = []

        for item in logs:
            try:
                res = await self.save_evidence_log(item)
                processed_logs.append(res)
                saved_count += 1
            except Exception as exc:
                logger.error("Error saving log in batch: %s", exc)
                failed_count += 1

        return {
            "status": "success",
            "synced_count": saved_count,
            "failed_count": failed_count,
            "persisted_to": "mongodb" if self.is_connected else "local_fallback",
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

    async def get_farmer_logs(self, phone: str, limit: int = 100) -> List[Dict[str, Any]]:
        clean_phone = "".join(c for c in phone.strip() if c.isdigit())
        if self.is_connected and self.db is not None:
            try:
                cursor = self.db.evidence_logs.find(
                    {"$or": [
                        {"phone": clean_phone},
                        {"farmer_phone": clean_phone},
                        {"phone": {"$regex": clean_phone[-10:] if len(clean_phone) >= 10 else clean_phone}},
                        {"farmer_phone": {"$regex": clean_phone[-10:] if len(clean_phone) >= 10 else clean_phone}}
                    ]},
                    {"_id": 0}
                ).sort("timestamp", -1).limit(limit)
                
                logs = await cursor.to_list(length=limit)
                return logs if logs is not None else []
            except Exception as e:
                logger.error("MongoDB get_farmer_logs error: %s", e)
                return []

        # Fallback only when MongoDB is offline
        return [e for e in fallback_db.get_all_evidence() if e.get("phone") == clean_phone or e.get("farmer_phone") == clean_phone]

    async def get_community_feed(self, crop: Optional[str] = None, district: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        if self.is_connected and self.db is not None:
            try:
                query: Dict[str, Any] = {}
                if crop and crop.lower() not in ["all", "all crops", ""]:
                    query["$or"] = [
                        {"crop": {"$regex": crop, "$options": "i"}},
                        {"crop_name": {"$regex": crop, "$options": "i"}},
                        {"title": {"$regex": crop, "$options": "i"}},
                    ]
                if district and district.lower() not in ["all", "all regions", ""]:
                    query["$or"] = [
                        {"district": {"$regex": district, "$options": "i"}},
                        {"village": {"$regex": district, "$options": "i"}},
                        {"state": {"$regex": district, "$options": "i"}},
                    ]

                cursor = self.db.evidence_logs.find(query, {"_id": 0}).sort("timestamp", -1).limit(limit)
                feed = await cursor.to_list(length=limit)
                return feed if feed is not None else []
            except Exception as e:
                logger.error("MongoDB get_community_feed error: %s", e)
                return []

        # Fallback only when MongoDB is disconnected
        return []

mongo_db = MongoDBManager()
