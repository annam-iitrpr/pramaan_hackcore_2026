from typing import List, Dict, Any
from datetime import datetime, timedelta

SAMPLE_FARMS = [
    {
        "id": "farm-101",
        "name": "Sahyadri Bio-Farms (Plot North-04)",
        "owner": "Ramesh Patil",
        "role": "FARMER",
        "village": "Dindori, Nashik",
        "state": "Maharashtra",
        "latitude": 20.1985,
        "longitude": 73.8322,
        "total_acres": 12.5,
        "primary_crops": ["Table Grapes", "Cotton", "Soybean"],
        "active_crop": "Cotton (Bt-II)",
        "sowing_date": "2026-06-15",
        "crop_stage": "Boll Formation / Flowering",
        "compliance_score": 96.4,
        "sync_pending_count": 0
    },
    {
        "id": "farm-102",
        "name": "Narmada Agri-Cluster (Block B)",
        "owner": "Suresh Verma",
        "role": "FARMER",
        "village": "Hoshangabad",
        "state": "Madhya Pradesh",
        "latitude": 22.7533,
        "longitude": 77.7249,
        "total_acres": 25.0,
        "primary_crops": ["Durum Wheat", "Paddy", "Chilli"],
        "active_crop": "Durum Wheat",
        "sowing_date": "2026-11-10",
        "crop_stage": "Tillering & Vegetative",
        "compliance_score": 92.8,
        "sync_pending_count": 1
    },
    {
        "id": "farm-103",
        "name": "Godavari Deltas Plot 3",
        "owner": "Venkatesh Rao",
        "role": "FARMER",
        "village": "Bhimavaram",
        "state": "Andhra Pradesh",
        "latitude": 16.5449,
        "longitude": 81.5212,
        "total_acres": 18.0,
        "primary_crops": ["Organic Paddy", "Black Gram"],
        "active_crop": "Organic Paddy (BPT-5204)",
        "sowing_date": "2026-07-01",
        "crop_stage": "Panicle Initiation",
        "compliance_score": 98.2,
        "sync_pending_count": 0
    },
    {
        "id": "farm-104",
        "name": "Punjab Kisan Adarsh Farm (PAU Model Plot)",
        "owner": "Gurpreet Singh Gill",
        "role": "FARMER",
        "village": "Jagraon, Ludhiana",
        "state": "Punjab",
        "latitude": 30.9010,
        "longitude": 75.8573,
        "total_acres": 22.0,
        "primary_crops": ["Wheat (PBW 826)", "Basmati Paddy (PR 126)", "Spring Maize", "Mustard"],
        "active_crop": "Wheat (PBW-826 High Yield)",
        "sowing_date": "2026-11-05",
        "crop_stage": "Active Tillering & Canopy Development",
        "compliance_score": 98.6,
        "sync_pending_count": 0
    },
    {
        "id": "farm-105",
        "name": "Malwa Golden Cotton & Wheat Cluster",
        "owner": "Harinder Pal Sandhu",
        "role": "FARMER",
        "village": "Talwandi Sabo, Bathinda",
        "state": "Punjab",
        "latitude": 30.2110,
        "longitude": 74.9455,
        "total_acres": 35.0,
        "primary_crops": ["Bt Cotton (RCH 659)", "Wheat (HD 3086)", "Kinnow Mandarin", "Mustard"],
        "active_crop": "Bt Cotton (RCH 659)",
        "sowing_date": "2026-05-20",
        "crop_stage": "Boll Maturation & Picking",
        "compliance_score": 96.8,
        "sync_pending_count": 0
    }
]


SAMPLE_PRODUCTS = [
    {
        "qr_code": "PRM-INP-88219-NEEM",
        "barcode": "8901234567890",
        "name": "Bio-Neem Power 10000 PPM",
        "manufacturer": "Kisan BioTech Ltd",
        "active_ingredient": "Azadirachtin 1.0% EC",
        "category": "Organic Bio-Pesticide",
        "recommended_dose": "2.5 ml per Litre (400 ml/Acre)",
        "target_pests": ["Whitefly", "Aphids", "Thrips", "Early Bollworm"],
        "pre_harvest_interval_days": 1,
        "toxicity_band": "Green (Safe/Organic)",
        "verified_batch_no": "BNP-2026-MAY-0441",
        "expiry_date": "2028-05-15",
        "genuine_verified": True
    },
    {
        "qr_code": "PRM-INP-99321-CORA",
        "barcode": "8909876543210",
        "name": "Coragen FMC Max",
        "manufacturer": "FMC Agro Chemicals",
        "active_ingredient": "Chlorantraniliprole 18.5% w/w SC",
        "category": "Targeted Insecticide",
        "recommended_dose": "60 ml per Acre in 200L water",
        "target_pests": ["Spotted Bollworm", "Helicoverpa", "Stem Borer"],
        "pre_harvest_interval_days": 14,
        "toxicity_band": "Blue (Moderately Toxic)",
        "verified_batch_no": "FMC-9921-AUG-01",
        "expiry_date": "2028-08-30",
        "genuine_verified": True
    },
    {
        "qr_code": "PRM-INP-44120-NANO-U",
        "barcode": "8904567890123",
        "name": "IFFCO Nano Urea Liquid",
        "manufacturer": "IFFCO Cooperative",
        "active_ingredient": "Nano-scale Nitrogen Particles (4%)",
        "category": "Nano Fertilizer",
        "recommended_dose": "4 ml per Litre (500 ml/Acre)",
        "target_pests": ["Nitrogen Deficiency", "Vegetative Stunting"],
        "pre_harvest_interval_days": 0,
        "toxicity_band": "Green (Eco-Safe)",
        "verified_batch_no": "IFF-NU-2026-092",
        "expiry_date": "2028-01-20",
        "genuine_verified": True
    },
    {
        "qr_code": "PRM-INP-77192-TRICHO",
        "barcode": "8907890123456",
        "name": "Trichoderma Viride Bio-Fungicide",
        "manufacturer": "Agrilife Solutions",
        "active_ingredient": "Trichoderma Viride 1.5% WP",
        "category": "Bio-Control Agent",
        "recommended_dose": "1.0 kg per Acre with FYM or foliar",
        "target_pests": ["Root Rot", "Wilt", "Damping Off", "Collar Rot"],
        "pre_harvest_interval_days": 0,
        "toxicity_band": "Green (Organic Certified)",
        "verified_batch_no": "TRC-V-8812-JUL",
        "expiry_date": "2027-12-31",
        "genuine_verified": True
    },
    {
        "qr_code": "PRM-INP-55310-TILT",
        "barcode": "8905544332211",
        "name": "Tilt 25% EC (Propiconazole)",
        "manufacturer": "Syngenta India / PAU Certified",
        "active_ingredient": "Propiconazole 25% EC",
        "category": "Systemic Fungicide",
        "recommended_dose": "1.0 ml per Litre (200 ml/Acre in 200L water)",
        "target_pests": ["Yellow / Stripe Rust (Puccinia striiformis)", "Karnal Bunt", "Leaf Blight"],
        "pre_harvest_interval_days": 30,
        "toxicity_band": "Blue (Moderately Toxic)",
        "verified_batch_no": "SYN-TLT-2026-PB01",
        "expiry_date": "2028-11-30",
        "genuine_verified": True
    },
    {
        "qr_code": "PRM-INP-66120-MANCO",
        "barcode": "8906655443322",
        "name": "Indofil M-45 (Mancozeb 75% WP)",
        "manufacturer": "Indofil Industries",
        "active_ingredient": "Mancozeb 75% WP",
        "category": "Contact Fungicide",
        "recommended_dose": "2.5 g per Litre (600 g/Acre)",
        "target_pests": ["Late Blight of Potato", "Early Blight", "Downy Mildew"],
        "pre_harvest_interval_days": 7,
        "toxicity_band": "Green (Safe/Eco-Compliant)",
        "verified_batch_no": "IND-M45-2026-JLR",
        "expiry_date": "2028-09-15",
        "genuine_verified": True
    }
]


SAMPLE_EVIDENCE = [
    {
        "id": "EV-2026-8810",
        "farm_id": "farm-101",
        "crop_name": "Cotton (Bt-II)",
        "crop_stage": "Flowering & Square Formation",
        "evidence_type": "PRODUCT_SCAN",
        "timestamp": "2026-08-28T07:45:00Z",
        "location": {
            "latitude": 20.1985,
            "longitude": 73.8322,
            "accuracy_meters": 3.2,
            "field_name": "Plot North-04",
            "village": "Dindori, Nashik"
        },
        "weather": {
            "temperature_c": 26.5,
            "humidity_percent": 68.0,
            "wind_speed_kmh": 6.2,
            "precipitation_prob": 10.0,
            "condition": "Partly Cloudy",
            "spray_suitability_score": 0.94,
            "spray_recommendation": "Optimal spray window: calm wind, no rain expected."
        },
        "title": "Bio-Neem Spray Batch Verified",
        "description": "Scanned QR code on Bio-Neem Power bottle before foliar application for whitefly control.",
        "media_url": "https://images.unsplash.com/photo-1592417817098-8f3d6eb22509?w=600&auto=format&fit=crop&q=80",
        "audio_transcript": "आज सकाळी आम्ही 400 मिली बायो-नीम 200 लिटर पाण्यात मिसळून संपूर्ण उत्तर प्लॉटवर फवारणी केली आहे.",
        "product_qr": "PRM-INP-88219-NEEM",
        "product_name": "Bio-Neem Power 10000 PPM",
        "dosage_per_acre": "400 ml in 200 L Water",
        "verification_status": "VERIFIED",
        "verification_score": 98.5,
        "verification_hash": "a8f5b4c9103982eef11082cba972e345b98a0021c32ff8812de4b21903fa7e41",
        "agent_verdicts": {
            "validation_agent": "Matched genuine batch PRM-INP-88219-NEEM from Kisan BioTech. Geo-fence valid.",
            "weather_agent": "Spray conditions were optimal (wind 6.2 km/h, humidity 68%). No wash-off risk.",
            "voice_agent": "Audio transcript in Marathi matches scanned input dosage and date."
        },
        "flag_reasons": []
    },
    {
        "id": "EV-2026-8811",
        "farm_id": "farm-101",
        "crop_name": "Cotton (Bt-II)",
        "crop_stage": "Flowering & Square Formation",
        "evidence_type": "CROP_IMAGE",
        "timestamp": "2026-08-25T16:20:00Z",
        "location": {
            "latitude": 20.1989,
            "longitude": 73.8320,
            "accuracy_meters": 4.1,
            "field_name": "Plot North-04 (Sector C)",
            "village": "Dindori, Nashik"
        },
        "weather": {
            "temperature_c": 31.0,
            "humidity_percent": 74.0,
            "wind_speed_kmh": 8.0,
            "precipitation_prob": 15.0,
            "condition": "Sunny / Warm",
            "spray_suitability_score": 0.88,
            "spray_recommendation": "Late afternoon spray safe."
        },
        "title": "Early Stage Whitefly & Leaf Curl Observation",
        "description": "Pre-treatment leaf undersides showed 12-15 nymphs per leaf with mild curling on apical foliage.",
        "media_url": "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=600&auto=format&fit=crop&q=80",
        "audio_transcript": "Cotton leaf undersides showing whitefly nymphs cluster. Triggering biological spray recommendation.",
        "product_qr": None,
        "product_name": None,
        "dosage_per_acre": None,
        "verification_status": "VERIFIED",
        "verification_score": 95.0,
        "verification_hash": "7cb41829e018a7b63f5819aa302194fbc8712aee4501239f8bc7102e3518bb39",
        "agent_verdicts": {
            "vision_agent": "Diagnosed Bemisia tabaci (Whitefly) infestation severity: 22%. Recommend organic Azadirachtin.",
            "validation_agent": "Image metadata timestamp and GPS coordinates strictly correlate with plot boundaries."
        },
        "flag_reasons": []
    },
    {
        "id": "EV-2026-8812",
        "farm_id": "farm-101",
        "crop_name": "Cotton (Bt-II)",
        "crop_stage": "Post-Spray Efficacy Check (Day 4)",
        "evidence_type": "CROP_IMAGE",
        "timestamp": "2026-08-29T10:15:00Z",
        "location": {
            "latitude": 20.1987,
            "longitude": 73.8324,
            "accuracy_meters": 2.8,
            "field_name": "Plot North-04 (Sector C)",
            "village": "Dindori, Nashik"
        },
        "weather": {
            "temperature_c": 27.2,
            "humidity_percent": 65.0,
            "wind_speed_kmh": 7.1,
            "precipitation_prob": 5.0,
            "condition": "Clear Sky",
            "spray_suitability_score": 0.96,
            "spray_recommendation": "Optimal weather."
        },
        "title": "Post-Treatment Recovery: 86% Whitefly Drop",
        "description": "Follow-up crop image after Bio-Neem application. Nymph count dropped to 1-2 per leaf. New flush foliage clean.",
        "media_url": "https://images.unsplash.com/photo-1586771107445-d3ca888129ff?w=600&auto=format&fit=crop&q=80",
        "audio_transcript": "फवारणीनंतर चार दिवसांनी पांढऱ्या माशीचे प्रमाण खूप कमी झाले आहे, झाडांची वाढ निरोगी दिसत आहे.",
        "product_qr": None,
        "product_name": "Bio-Neem Power 10000 PPM",
        "dosage_per_acre": "400 ml/Acre (Applied 2026-08-28)",
        "verification_status": "VERIFIED",
        "verification_score": 97.8,
        "verification_hash": "55e28a9b207f9c31405908da018dca467e2a90184bba02095f9c44510bc281ee",
        "agent_verdicts": {
            "efficacy_agent": "Pre vs. Post efficacy verified: 86.4% pest mortality. Canopy vitality index increased from 0.62 to 0.79.",
            "validation_agent": "Cryptographic link validated with Pre-Spray EV-2026-8811 and Application EV-2026-8810."
        },
        "flag_reasons": []
    },
    {
        "id": "EV-2026-8813",
        "farm_id": "farm-102",
        "crop_name": "Durum Wheat",
        "crop_stage": "Vegetative",
        "evidence_type": "VOICE_LOG",
        "timestamp": "2026-08-29T18:00:00Z",
        "location": {
            "latitude": 22.7533,
            "longitude": 77.7249,
            "accuracy_meters": 6.5,
            "field_name": "Block B",
            "village": "Hoshangabad"
        },
        "weather": {
            "temperature_c": 29.0,
            "humidity_percent": 82.0,
            "wind_speed_kmh": 14.5,
            "precipitation_prob": 65.0,
            "condition": "Overcast / Rain Threat",
            "spray_suitability_score": 0.35,
            "spray_recommendation": "High rain risk (65%) and gusty winds (14.5 km/h). DO NOT SPRAY."
        },
        "title": "Voice Log: Spray Delayed due to Rain Forecast",
        "description": "Farmer checked Meteoblue forecast through Pramaan and rescheduled Nano Urea spray to avoid runoff.",
        "media_url": None,
        "audio_transcript": "मौसम खराब है और बारिश की संभावना 65% है, इसलिए आज शाम का नैनो यूरिया छिड़काव कल सुबह तक टाल दिया है।",
        "product_qr": "PRM-INP-44120-NANO-U",
        "product_name": "IFFCO Nano Urea Liquid",
        "dosage_per_acre": "500 ml/Acre (Scheduled)",
        "verification_status": "VERIFIED",
        "verification_score": 96.0,
        "verification_hash": "2f91a039d01248083bfce47392a018bcdefa10294871239abcef1092837461aa",
        "agent_verdicts": {
            "weather_agent": "Weather advisory accurately matched: Rainfall expected within 3 hours. Good practice logged.",
            "validation_agent": "Voice record confirmed by Field Agent."
        },
        "flag_reasons": []
    }
]

SAMPLE_SEASON_JOURNAL = [
    {
        "id": "JRN-01",
        "farm_id": "farm-101",
        "date": "2026-06-15",
        "stage": "Land Prep & Sowing",
        "title": "Certified Bt-II Seed Sowing & Trichoderma Soil Treatment",
        "type": "SOWING",
        "status": "COMPLETED",
        "compliance_checked": True,
        "notes": "Treated seeds with Trichoderma Viride bio-fungicide before precision sowing."
    },
    {
        "id": "JRN-02",
        "farm_id": "farm-101",
        "date": "2026-07-05",
        "stage": "Seedling Emergence",
        "title": "Basal Organic Manure + Micro-Nutrient Application",
        "type": "FERTILIZER",
        "status": "COMPLETED",
        "compliance_checked": True,
        "notes": "Applied 5 tons well-decomposed FYM and zinc sulphate foliar booster."
    },
    {
        "id": "JRN-03",
        "farm_id": "farm-101",
        "date": "2026-08-25",
        "stage": "Vegetative & Squaring",
        "title": "Whitefly Detection & AI Diagnosis",
        "type": "OBSERVATION",
        "status": "COMPLETED",
        "compliance_checked": True,
        "notes": "Pramaan Vision AI detected early whitefly; recommended botanical insecticide."
    },
    {
        "id": "JRN-04",
        "farm_id": "farm-101",
        "date": "2026-08-28",
        "stage": "Vegetative & Squaring",
        "title": "Bio-Neem Spray Applied (Batch Verified)",
        "type": "APPLICATION",
        "status": "COMPLETED",
        "compliance_checked": True,
        "notes": "QR scanned bottle BNP-2026-MAY-0441; 400ml/Acre applied during calm weather."
    },
    {
        "id": "JRN-05",
        "farm_id": "farm-101",
        "date": "2026-08-29",
        "stage": "Flowering & Boll Formation",
        "title": "Efficacy Check: 86.4% Pest Reduction Verified",
        "type": "EFFICACY_REVIEW",
        "status": "COMPLETED",
        "compliance_checked": True,
        "notes": "NDVI vitality proxy restored to 0.79. Safe for upcoming flowering phase."
    },
    {
        "id": "JRN-06",
        "farm_id": "farm-101",
        "date": "2026-10-15",
        "stage": "Boll Bursting & Harvest",
        "title": "Target Harvest & Export Quality Batch Seal",
        "type": "HARVEST_ESTIMATE",
        "status": "UPCOMING",
        "compliance_checked": False,
        "notes": "Anticipated yield: 18.5 Quintals/Acre with Grade-A Purity Premium."
    }
]

SAMPLE_NOTIFICATIONS = [
    {
        "id": "notif-01",
        "title": "Spray Window Alert: Clear Skies Next 6 Hours",
        "message": "Wind speed 5.4 km/h, humidity 64%. Optimal window for foliar nutrient sprays in Dindori.",
        "type": "WEATHER",
        "timestamp": "10 mins ago",
        "is_read": False
    },
    {
        "id": "notif-02",
        "title": "Evidence EV-2026-8812 Cryptographically Verified",
        "message": "Field Agent approved Post-Treatment Efficacy record. Blockchain anchor SHA-256 updated.",
        "type": "VERIFICATION",
        "timestamp": "1 hour ago",
        "is_read": False
    },
    {
        "id": "notif-03",
        "title": "Buyer Quote Request: ITC Agri-Business",
        "message": "ITC Agri offered ₹7,850/Qtl (+₹450 Pramaan Organic Verified Premium) for Lot #CT-881.",
        "type": "BUYER",
        "timestamp": "3 hours ago",
        "is_read": True
    },
    {
        "id": "notif-04",
        "title": "Regional Pest Outbreak Warning: Pink Bollworm",
        "message": "Neighbouring plots reported light moth trap activity. Check pheromone traps daily.",
        "type": "PEST_ALERT",
        "timestamp": "1 day ago",
        "is_read": True
    }
]
