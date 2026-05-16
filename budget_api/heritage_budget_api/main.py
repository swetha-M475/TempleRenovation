from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional
from utils.rag_helper import setup_chromadb, fetch_district_rates, get_work_details
from utils.gemini_helper import analyze_damage_photo_bytes, analyze_damage_photo, standardize_work_description, generate_work_summary
from utils.budget_calculator import calculate_budget
import shutil, os, uuid
import httpx                          # ← for calling Object Detection API
import base64

app = FastAPI(title="Heritage Budget Sanctioning API")

# ── Object Detection API base URL ─────────────────────────────────────
OD_API_BASE = "https://objectdetection-5.onrender.com"

@app.on_event("startup")
async def startup_event():
    setup_chromadb()
    print("✅ API is ready!")

# ─── Helper: Call Object Detection API ───────────────────────────────
async def call_object_detection(image_bytes: bytes, filename: str = "image.jpg") -> dict:
    """
    Sends image to the Object Detection API and returns:
    - detections (list of labels + confidence)
    - quality (blur, brightness, contrast)
    - orientation
    - annotated_image_base64
    - session_id
    - is_valid_temple (our derived flag)
    - invalid_reason (if invalid)
    """
    try:
        print(f"🔍 Calling Object Detection API...")
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{OD_API_BASE}/api/analyze",
                files={"image": (filename, image_bytes, "image/jpeg")},
            )

        if response.status_code != 200:
            print(f"⚠️ OD API returned {response.status_code}: {response.text}")
            # Don't block the pipeline if OD API fails — log and continue
            return {
                "detections": [],
                "quality": {},
                "orientation": "unknown",
                "annotated_image_base64": None,
                "session_id": None,
                "is_valid_temple": True,   # fail-open so budget still generates
                "invalid_reason": None,
                "od_error": f"OD API error {response.status_code}",
            }

        data = response.json()
        print(f"✅ OD API response received. Detections: {len(data.get('detections', []))}")

        # ── Validate: check if image contains temple-related objects ──
        detections     = data.get("detections", [])
        quality        = data.get("quality", {})
        orientation    = data.get("orientation", "unknown")
        session_id     = data.get("session_id")
        annotated_b64  = data.get("annotated_image_base64")

        # Temple-related labels from YOLOv8 model
        TEMPLE_LABELS = {
            "lingam", "nandhi", "nandi", "temple", "gopuram",
            "mandapam", "statue", "idol", "shivalingam",
            "compound_wall", "temple_structure", "kovil",
        }

        detected_labels = {d.get("label", "").lower() for d in detections}
        high_conf_labels = {
            d.get("label", "").lower()
            for d in detections
            if d.get("confidence", 0) >= 0.4
        }

        is_valid = bool(detected_labels & TEMPLE_LABELS) or bool(high_conf_labels & TEMPLE_LABELS)

        # Quality checks
        blur_score = quality.get("blur", 1.0)
        is_blurry  = blur_score < 0.15    # low blur score = blurry image

        invalid_reason = None
        if is_blurry:
            is_valid       = False
            invalid_reason = f"Image appears blurry (blur score: {blur_score:.2f}). Please upload a clearer photo."
        elif not is_valid:
            invalid_reason = (
                f"No temple structures detected in this image. "
                f"Detected objects: {', '.join(detected_labels) if detected_labels else 'none'}. "
                f"Please upload a photo of the damaged temple or statue."
            )

        print(f"  Detected labels: {detected_labels}")
        print(f"  Is valid temple image: {is_valid}")
        if invalid_reason:
            print(f"  Invalid reason: {invalid_reason}")

        return {
            "detections":             detections,
            "quality":                quality,
            "orientation":            orientation,
            "annotated_image_base64": annotated_b64,
            "session_id":             session_id,
            "is_valid_temple":        is_valid,
            "invalid_reason":         invalid_reason,
            "od_error":               None,
        }

    except httpx.TimeoutException:
        print("⚠️ OD API timeout — continuing without validation")
        return {
            "detections": [], "quality": {}, "orientation": "unknown",
            "annotated_image_base64": None, "session_id": None,
            "is_valid_temple": True, "invalid_reason": None,
            "od_error": "OD API timeout",
        }
    except Exception as e:
        print(f"⚠️ OD API exception: {e}")
        return {
            "detections": [], "quality": {}, "orientation": "unknown",
            "annotated_image_base64": None, "session_id": None,
            "is_valid_temple": True, "invalid_reason": None,
            "od_error": str(e),
        }


# ─── Helper: Build work description from detections ──────────────────
def enrich_work_description(work_description: str, detections: list) -> str:
    """
    Enriches the user's work description with detected object labels
    so the RAG retrieval is more accurate.
    """
    if not detections:
        return work_description

    detected_labels = list({d.get("label", "").lower() for d in detections if d.get("confidence", 0) >= 0.4})
    if not detected_labels:
        return work_description

    enriched = work_description
    label_str = ", ".join(detected_labels)

    # Only append if not already mentioned
    if not any(label in work_description.lower() for label in detected_labels):
        enriched = f"{work_description}. Detected elements: {label_str}"

    print(f"  Enriched description: {enriched}")
    return enriched


# ─── Option 1: JSON with image URL ───────────────────────────────────
class DamageReport(BaseModel):
    image_url: str
    sqft: float
    work_description: str
    district: str

@app.post("/analyze-damage")
async def analyze_damage(report: DamageReport):
    try:
        print(f"📸 Analyzing photo for {report.district}...")
        vision_result = await analyze_damage_photo(report.image_url)

        print("🧠 Understanding work description...")
        work_types = await standardize_work_description(
            report.work_description, vision_result
        )

        print(f"📦 Fetching {report.district} rates from ChromaDB...")
        fetch_district_rates(report.district, report.work_description)

        print("💰 Calculating budget...")
        budget = calculate_budget(report.district, work_types, report.sqft)

        print("📝 Generating work summary...")
        summary = await generate_work_summary(
            vision_result, work_types, budget["breakdown"], report.district
        )

        return {
            "status": "success",
            "district": report.district,
            "damage_analysis": vision_result,
            "work_types_identified": work_types,
            "work_summary": summary,
            "budget_breakdown": budget["breakdown"],
            "total_sanction": budget["total_sanction"],
            "sqft": report.sqft
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── Option 2: Form with image file upload ───────────────────────────
@app.post("/analyze-damage-upload")
async def analyze_damage_upload(
    file: UploadFile = File(...),
    sqft: float = Form(...),
    work_description: str = Form(...),
    district: str = Form(...)
):
    try:
        print(f"📸 Reading uploaded file for {district}...")
        image_bytes = await file.read()

        # ── STEP 1: Object Detection API ──────────────────────────
        print("🤖 Step 1: Object Detection...")
        od_result = await call_object_detection(image_bytes, file.filename or "image.jpg")

        # If image is invalid (wrong image / blurry) → return early with flag
        if not od_result["is_valid_temple"]:
            return {
                "status": "invalid_image",
                "is_invalid_image": True,
                "invalid_reason": od_result["invalid_reason"],
                "detections": od_result["detections"],
                "annotated_image_base64": od_result["annotated_image_base64"],
                "session_id": od_result["session_id"],
                "damage_analysis": {
                    "IS_INVALID_IMAGE": True,
                    "DAMAGE_TYPE": "NOT_A_TEMPLE",
                    "SEVERITY": "N/A",
                    "MATERIAL": "N/A",
                    "AFFECTED_AREA": "N/A",
                    "DESCRIPTION": od_result["invalid_reason"],
                },
                "budget_breakdown": {},
                "total_sanction": 0,
                "work_summary": "",
                "district": district,
                "sqft": sqft,
            }

        # ── STEP 2: Vision AI — damage analysis ───────────────────
        print("🔍 Step 2: Analyzing damage with Vision AI...")
        vision_result = await analyze_damage_photo_bytes(image_bytes)

        # ── STEP 3: Enrich work description with detections ───────
        print("✍️  Step 3: Enriching work description with detections...")
        enriched_description = enrich_work_description(
            work_description, od_result["detections"]
        )

        # ── STEP 4: RAG — standardize work types ──────────────────
        print("🧠 Step 4: Understanding work description via RAG...")
        work_types = await standardize_work_description(
            enriched_description, vision_result
        )

        # ── STEP 5: Fetch district rates from ChromaDB ────────────
        print(f"📦 Step 5: Fetching {district} rates from ChromaDB...")
        fetch_district_rates(district, enriched_description)

        # ── STEP 6: Calculate budget ───────────────────────────────
        print("💰 Step 6: Calculating budget...")
        budget = calculate_budget(district, work_types, sqft)

        # ── STEP 7: Generate work summary ─────────────────────────
        print("📝 Step 7: Generating work summary...")
        summary = await generate_work_summary(
            vision_result, work_types, budget["breakdown"], district
        )

        return {
            "status": "success",
            "district": district,
            # OD results
            "detections":             od_result["detections"],
            "annotated_image_base64": od_result["annotated_image_base64"],
            "session_id":             od_result["session_id"],
            "image_quality":          od_result["quality"],
            "orientation":            od_result["orientation"],
            # RAG results
            "damage_analysis":        vision_result,
            "work_types_identified":  work_types,
            "work_summary":           summary,
            "budget_breakdown":       budget["breakdown"],
            "total_sanction":         budget["total_sanction"],
            "sqft":                   sqft,
            "is_invalid_image":       False,
        }

    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
def health_check():
    return {"status": "Heritage Budget API is running ✅"}


@app.get("/od-health")
async def check_od_health():
    """Check if Object Detection API is reachable"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{OD_API_BASE}/api/health")
        return response.json()
    except Exception as e:
        return {"status": "error", "detail": str(e)}