"""
Temple Heritage Monitoring — Production Flask REST API

Serves a Flutter mobile application with endpoints:
  POST /api/analyze         — Single image analysis with persistence
  POST /api/compare         — Two-image or lookup-based comparison
  GET  /api/health          — System health & readiness check
  GET  /api/history         — List recent analysis activities
  GET  /api/activity/<id>   — Retrieve a stored activity
  GET  /                    — Frontend (index.html)

All responses are JSON-serializable for Flutter's http package.
Numpy types are automatically converted via NumpyEncoder.
"""

import os
import sys
import json
import base64
import traceback
import uuid
from datetime import datetime, timezone

import cv2
import numpy as np
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

# Add parent to path for engine imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from engine import quality, detector, similarity, change_detector, orientation, domain
import database


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  JSON Encoder — handles numpy, datetime, UUID types
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class NumpyEncoder(json.JSONEncoder):
    """Custom JSON encoder that handles numpy, datetime, and UUID types."""

    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        elif isinstance(obj, np.floating):
            return float(obj)
        elif isinstance(obj, np.bool_):
            return bool(obj)
        elif isinstance(obj, np.str_):
            return str(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, datetime):
            return obj.isoformat()
        elif isinstance(obj, uuid.UUID):
            return str(obj)
        elif isinstance(obj, bytes):
            return base64.b64encode(obj).decode("utf-8")
        return super().default(obj)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  App Setup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FRONTEND_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "frontend"
)

app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path="")
app.json.encoder = NumpyEncoder
app.config["MAX_CONTENT_LENGTH"] = 32 * 1024 * 1024  # 32 MB

CORS(app)

# Allowed MIME types for mobile uploads
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

# Default inference resolution (can be overridden per-request)
DEFAULT_MAX_DIMENSION = 640


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Startup — load model & init DB
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
print("[app] Loading engine modules...")
print(f"[app] Model loaded: {detector.model_loaded}")
print(f"[app] Classes: {detector.get_model_classes()}")

database.init_db()
print("[app] Database initialized")


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Helpers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def _error_response(message: str, error_code: str, status_code: int = 400):
    """Build a consistent error JSON response."""
    return jsonify({
        "status": "error",
        "error": message,
        "error_code": error_code,
    }), status_code


def _timestamp():
    return datetime.now(timezone.utc).isoformat()


def _read_image(file_storage) -> np.ndarray | None:
    """Read an uploaded file into an OpenCV BGR image."""
    file_bytes = file_storage.read()
    if not file_bytes or len(file_bytes) == 0:
        return None
    arr = np.frombuffer(file_bytes, np.uint8)
    # Try standard OpenCV decode first
    image = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    
    if image is None:
        # Fallback for HEIC/HEIF formats using pillow_heif
        try:
            from PIL import Image
            import pillow_heif
            
            # Register HEIF opener with PIL
            pillow_heif.register_heif_opener()
            
            # Read bytes using PIL
            import io
            pil_img = Image.open(io.BytesIO(file_bytes))
            
            # Convert to numpy array
            arr_img = np.array(pil_img)
            
            # Convert RGB to BGR for OpenCV
            if len(arr_img.shape) == 3 and arr_img.shape[2] >= 3:
                image = cv2.cvtColor(arr_img, cv2.COLOR_RGB2BGR)
            else:
                # If grayscale, convert to BGR
                image = cv2.cvtColor(arr_img, cv2.COLOR_GRAY2BGR)
        except Exception as e:
            print(f"Fallback decode failed: {e}")
            return None
            
    return image


def _encode_image_b64(img_bgr: np.ndarray, quality_val: int = 85) -> str:
    """Encode a BGR image to Base64 JPEG string."""
    _, buf = cv2.imencode(".jpg", img_bgr, [cv2.IMWRITE_JPEG_QUALITY, quality_val])
    return base64.b64encode(buf).decode("utf-8")


def validate_upload(file_storage) -> tuple:
    """
    Validate an uploaded image file for mobile compatibility.

    Returns:
        (img_bgr, None) on success
        (None, error_response_tuple) on failure
    """
    # 1. Null / empty check
    if file_storage is None:
        return None, _error_response(
            "No image file provided.", "NULL_IMAGE"
        )

    filename = file_storage.filename or ""

    # 2. Check file has content
    file_storage.seek(0, 2)  # Seek to end
    file_size = file_storage.tell()
    file_storage.seek(0)  # Reset

    if file_size == 0:
        return None, _error_response(
            "Uploaded file is empty (0 bytes).", "NULL_IMAGE"
        )

    # 3. Extension / format check
    ext = os.path.splitext(filename)[1].lower() if filename else ""
    # Removed HEIC block to allow pillow-heif to process it

    content_type = file_storage.content_type or ""
    if content_type and content_type not in ALLOWED_MIME_TYPES:
        # Be lenient — only reject if it's clearly not an image
        if not content_type.startswith("image/"):
            return None, _error_response(
                f"Unsupported file type: {content_type}. "
                f"Accepted formats: JPEG, PNG, WebP.",
                "UNSUPPORTED_FORMAT",
            )

    # 4. Attempt decode
    img = _read_image(file_storage)
    if img is None:
        return None, _error_response(
            "Cannot decode image. The file may be corrupt or in an "
            "unsupported format.",
            "CORRUPT_IMAGE",
        )

    # 5. Minimum size check
    h, w = img.shape[:2]
    if h < 50 or w < 50:
        return None, _error_response(
            f"Image is too small ({w}×{h}px). Minimum size is 50×50 pixels.",
            "TOO_SMALL",
        )

    return img, None


def _get_max_dimension(request_obj) -> int:
    """Get max inference dimension from query param or default."""
    try:
        val = int(request_obj.args.get("resolution", DEFAULT_MAX_DIMENSION))
        if val in (640, 1024):
            return val
    except (ValueError, TypeError):
        pass
    return DEFAULT_MAX_DIMENSION


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Static Frontend
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route("/")
def serve_index():
    return send_from_directory(app.static_folder, "index.html")


@app.route("/<path:path>")
def serve_static(path):
    return send_from_directory(app.static_folder, path)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GET /api/health — System health check
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route("/api/health", methods=["GET"])
def health():
    activity_count = 0
    db_status = "unknown"
    try:
        activity_count = database.get_activity_count()
        db_status = "connected"
    except Exception:
        db_status = "error"

    return jsonify({
        "status": "ok",
        "model_loaded": detector.model_loaded,
        "classes": detector.get_model_classes(),
        "database": {
            "status": db_status,
            "activity_count": activity_count,
        },
        "preprocessing": {
            "default_max_dimension": DEFAULT_MAX_DIMENSION,
            "supported_resolutions": [640, 1024],
        },
        "max_upload_mb": 32,
        "supported_formats": list(ALLOWED_EXTENSIONS),
    })


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  POST /api/analyze — Single image analysis
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route("/api/analyze", methods=["POST"])
def analyze():
    """
    Analyze a single temple image.

    Expects: multipart/form-data with field 'image'
    Optional query param: ?resolution=640 or ?resolution=1024

    Returns: JSON with session_id, image_hash, detections,
             quality, orientation, annotated_image_base64
    """
    try:
        if "image" not in request.files:
            return _error_response(
                "No image file provided. Use field name 'image'.",
                "NULL_IMAGE",
            )

        file = request.files["image"]

        # ── Validate upload ──────────────────────────────
        img, error = validate_upload(file)
        if error:
            return error

        # ── Generate identifiers ─────────────────────────
        session_id = database.generate_session_id()
        image_hash = detector.compute_image_hash(img)

        # ── Preprocess for mobile latency ────────────────
        max_dim = _get_max_dimension(request)
        preprocessed_img, scale_factor, original_size = quality.preprocess_for_inference(
            img, max_dimension=max_dim
        )

        # ── Store original image as Base64 (for future SSIM comparisons)
        original_b64 = _encode_image_b64(img, quality_val=90)

        # ── 1. Quality assessment (on preprocessed) ──────
        quality_result = quality.assess(preprocessed_img)
        quality_gate = quality.check_quality_gate(quality_result)

        # ── 2. Object detection ──────────────────────────
        detection_result = detector.detect(preprocessed_img, quality_result)

        # ── 3. Domain validation ─────────────────────────
        validated_result = domain.validate(detection_result)

        # ── 4. Orientation (on original) ─────────────────
        orient_result = orientation.check(img)

        # ── 5. Store in database ─────────────────────────
        annotated_b64 = validated_result.get("annotated_image_base64", "")
        orig_w, orig_h = original_size

        database.store_activity(
            session_id=session_id,
            image_hash=image_hash,
            detection_results=validated_result,
            quality_results=quality_result,
            orientation_results=orient_result,
            domain_results=validated_result,
            annotated_image_b64=annotated_b64,
            original_image_b64=original_b64,
            image_width=orig_w,
            image_height=orig_h,
        )

        # ── Build response ───────────────────────────────
        response = {
            "status": "success",
            "session_id": session_id,
            "image_hash": image_hash,
            "quality": quality_result,
            "quality_gate": quality_gate,
            "detections": validated_result,
            "orientation": orient_result,
            "annotated_image_base64": annotated_b64,
            "preprocessing": {
                "original_size": {"width": orig_w, "height": orig_h},
                "inference_resolution": max_dim,
                "scale_factor": round(scale_factor, 4),
            },
            "timestamp": _timestamp(),
        }

        return jsonify(response)

    except Exception as e:
        traceback.print_exc()
        return _error_response(
            f"Analysis failed: {str(e)}", "INTERNAL_ERROR", 500
        )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  POST /api/compare — Two-image comparison
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route("/api/compare", methods=["POST"])
def compare():
    """
    Compare two temple images.

    Two modes:
      A) Two images:  fields 'image1' and 'image2'
      B) Lookup mode: field 'image' (current) + form field 'previous_activity_id'

    Optional query param: ?resolution=640 or ?resolution=1024

    Returns: JSON with SSIM, changes, diff_image_base64, detections for both
    """
    try:
        max_dim = _get_max_dimension(request)
        img1 = None
        img2 = None
        previous_activity = None

        # ── Mode B: Lookup via previous_activity_id ──────
        previous_activity_id = request.form.get("previous_activity_id", "").strip()

        if previous_activity_id:
            # Lookup mode: one current image + previous from DB
            if "image" not in request.files:
                return _error_response(
                    "Lookup mode requires a 'image' field (current image) "
                    "and 'previous_activity_id' form field.",
                    "NULL_IMAGE",
                )

            # Validate current image
            file_current = request.files["image"]
            img2, error = validate_upload(file_current)
            if error:
                return error

            # Fetch previous activity from database
            previous_activity = database.get_activity(previous_activity_id)
            if previous_activity is None:
                return _error_response(
                    f"No activity found with ID '{previous_activity_id}'. "
                    f"The activity may have been deleted or the ID is invalid.",
                    "ACTIVITY_NOT_FOUND",
                    404,
                )

            # Reconstruct previous image from stored Base64
            prev_b64 = previous_activity.get("original_image_b64", "")
            if not prev_b64:
                prev_b64 = previous_activity.get("annotated_image_b64", "")

            if not prev_b64:
                return _error_response(
                    "Previous activity exists but has no stored image data. "
                    "Cannot perform comparison.",
                    "MISSING_DATA",
                )

            img1_bytes = base64.b64decode(prev_b64)
            img1_arr = np.frombuffer(img1_bytes, np.uint8)
            img1 = cv2.imdecode(img1_arr, cv2.IMREAD_COLOR)

            if img1 is None:
                return _error_response(
                    "Failed to decode the stored previous image.",
                    "CORRUPT_IMAGE",
                )

        # ── Mode A: Two uploaded images ──────────────────
        else:
            if "image1" not in request.files or "image2" not in request.files:
                return _error_response(
                    "Two images required. Use field names 'image1' and 'image2'. "
                    "OR use 'image' + 'previous_activity_id' for lookup mode.",
                    "NULL_IMAGE",
                )

            file1 = request.files["image1"]
            file2 = request.files["image2"]

            img1, error1 = validate_upload(file1)
            if error1:
                return error1

            img2, error2 = validate_upload(file2)
            if error2:
                return error2

        # ── Preprocess both images ───────────────────────
        img1_proc, _, _ = quality.preprocess_for_inference(img1, max_dim)
        img2_proc, _, _ = quality.preprocess_for_inference(img2, max_dim)

        # ── 1. Quality assessment ────────────────────────
        q1 = quality.assess(img1_proc)
        q2 = quality.assess(img2_proc)

        # ── Quality gate warnings ────────────────────────
        gate1 = quality.check_quality_gate(q1)
        gate2 = quality.check_quality_gate(q2)
        comparison_warnings = gate1.get("warnings", []) + gate2.get("warnings", [])

        # ── 2. Object detection ──────────────────────────
        if previous_activity and "detection_results" in previous_activity:
            # Reuse stored detections for the previous image
            det1 = previous_activity["detection_results"]
        else:
            det1 = detector.detect(img1_proc, q1)

        det2 = detector.detect(img2_proc, q2)

        # ── 3. SSIM similarity ───────────────────────────
        ssim_result = similarity.compare(img1_proc, img2_proc)

        # ── 4. Change detection ──────────────────────────
        change_result = change_detector.analyze(det1, det2, ssim_result)

        # ── 5. Duplicate check ───────────────────────────
        dup_result = orientation.check_duplicate(img1_proc, img2_proc)

        # ── Build response ───────────────────────────────
        response = {
            "status": "success",
            "ssim": {
                "ssim_score": ssim_result.get("ssim_score"),
                "ssim_pct": ssim_result.get("ssim_pct"),
                "similarity_label": ssim_result.get("similarity_label"),
                "structural_change_regions": ssim_result.get("structural_change_regions"),
                "illumination_change_regions": ssim_result.get("illumination_change_regions"),
                "interpretation": ssim_result.get("interpretation"),
            },
            "changes": change_result,
            "diff_image_base64": ssim_result.get("diff_image_base64", ""),
            "image1_quality": q1,
            "image2_quality": q2,
            "image1_detections": det1,
            "image2_detections": det2,
            "duplicate_check": dup_result,
            "comparison_warnings": comparison_warnings,
            "timestamp": _timestamp(),
        }

        # Add lookup metadata if applicable
        if previous_activity_id:
            response["lookup_mode"] = True
            response["previous_activity_id"] = previous_activity_id

        return jsonify(response)

    except Exception as e:
        traceback.print_exc()
        return _error_response(
            f"Comparison failed: {str(e)}", "INTERNAL_ERROR", 500
        )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GET /api/history — List recent activities
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route("/api/history", methods=["GET"])
def history():
    """
    List recent analysis activities.

    Query params:
        limit  — max records to return (default 50, max 200)
        offset — pagination offset (default 0)

    Returns: JSON list of activity summaries (without heavy Base64 fields)
    """
    try:
        limit = min(int(request.args.get("limit", 50)), 200)
        offset = max(int(request.args.get("offset", 0)), 0)
    except (ValueError, TypeError):
        limit = 50
        offset = 0

    try:
        activities = database.list_activities(limit=limit, offset=offset)
        total = database.get_activity_count()

        return jsonify({
            "status": "success",
            "total": total,
            "limit": limit,
            "offset": offset,
            "activities": activities,
        })
    except Exception as e:
        traceback.print_exc()
        return _error_response(
            f"Failed to retrieve history: {str(e)}", "INTERNAL_ERROR", 500
        )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GET /api/activity/<id> — Retrieve a specific activity
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@app.route("/api/activity/<activity_id>", methods=["GET"])
def get_activity(activity_id):
    """
    Retrieve a stored activity by its session_id.

    Returns: Full activity JSON including detection results,
             quality metrics, and annotated image Base64.
    """
    try:
        activity = database.get_activity(activity_id)
        if activity is None:
            return _error_response(
                f"Activity '{activity_id}' not found.",
                "ACTIVITY_NOT_FOUND",
                404,
            )

        return jsonify({
            "status": "success",
            "activity": activity,
        })
    except Exception as e:
        traceback.print_exc()
        return _error_response(
            f"Failed to retrieve activity: {str(e)}", "INTERNAL_ERROR", 500
        )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
