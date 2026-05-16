"""
YOLOv8 Object Detection Engine

Handles:
- Model loading and caching (module-level singleton)
- Preprocessing with CLAHE enhancement
- Test-Time Augmentation (TTA) with 3 passes
- NMS via torchvision
- Avudaiyar spatial inference from Lingam positions
- Annotated image rendering with per-class colors
- Perceptual hash computation for image identity
"""

import cv2
import numpy as np
import base64
import torch
import torchvision
import imagehash
from PIL import Image
from pathlib import Path

# ─── Global model cache ────────────────────────────────────
_model = None
model_loaded = False

# Class display name mapping
CLASS_MAP = {
    "old Temple": "Temple Structure",
    "shed": "Shed / Auxiliary Structure",
    "lingam": "Lingam",
    "nandhi": "Nandhi",
}

# Colors per class (BGR)
CLASS_COLORS = {
    "Lingam": (0, 200, 100),
    "Nandhi": (200, 100, 0),
    "Temple Structure": (0, 120, 255),
    "Shed / Auxiliary Structure": (180, 180, 0),
    "Avudaiyar": (130, 0, 200),
}


def _display_name(raw_class: str) -> str:
    """Map raw model class name to display name."""
    return CLASS_MAP.get(raw_class, raw_class)


def _load_model():
    """Load YOLO model once at module level."""
    global _model, model_loaded
    if _model is not None:
        return _model
    try:
        from ultralytics import YOLO
        model_path = str(Path(__file__).parent.parent / "models" / "best.pt")
        _model = YOLO(model_path)
        model_loaded = True
        print(f"[detector] Model loaded from {model_path}")
    except Exception as e:
        model_loaded = False
        print(f"[detector] Failed to load model: {e}")
    return _model


# Eagerly load on import
_load_model()


def get_model_classes():
    """Return list of class names the model can detect."""
    if _model is not None and hasattr(_model, "names"):
        return list(_model.names.values())
    return []


def compute_image_hash(img_bgr: np.ndarray) -> str:
    """
    Compute a perceptual hash (pHash) for the given BGR image.

    Returns:
        Hex string of the perceptual hash (e.g., "a1b2c3d4e5f6a7b8")
    """
    pil_img = Image.fromarray(cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB))
    phash = imagehash.phash(pil_img)
    return str(phash)


def detect(img_bgr: np.ndarray, quality_result: dict) -> dict:
    """
    Full detection pipeline on a single image.

    Steps:
      1. Preprocess (resize 640x640 + CLAHE)
      2. TTA: original + horizontal flip + vertical flip
      3. Merge detections, remap flipped coords
      4. NMS via torchvision
      5. Multiply confidences by quality multiplier
      6. Avudaiyar spatial inference
      7. Scale boxes back to original dimensions
      8. Draw annotated image → base64
    """
    model = _load_model()
    if model is None:
        return {
            "model_loaded": False,
            "detection_count": 0,
            "detections": [],
            "annotated_image_base64": "",
            "tta_used": False,
        }

    orig_h, orig_w = img_bgr.shape[:2]
    conf_mult = quality_result.get("confidence_multiplier", 1.0)

    # ── 1. Preprocess ───────────────────────────────────────
    resized = cv2.resize(img_bgr, (640, 640), interpolation=cv2.INTER_LANCZOS4)

    # CLAHE on L channel of LAB
    lab = cv2.cvtColor(resized, cv2.COLOR_BGR2LAB)
    l_ch, a_ch, b_ch = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l_ch = clahe.apply(l_ch)
    lab = cv2.merge([l_ch, a_ch, b_ch])
    preprocessed = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    # ── 2. TTA — 3 inference passes ─────────────────────────
    img_w, img_h = 640, 640
    all_raw = []

    def _run_inference(image):
        results = model.predict(image, conf=0.25, iou=0.45, imgsz=640, verbose=False)
        dets = []
        for r in results:
            if r.boxes is None:
                continue
            for box in r.boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                cls_id = int(box.cls[0])
                conf = float(box.conf[0])
                class_name = model.names[cls_id]
                dets.append((x1, y1, x2, y2, conf, class_name))
        return dets

    # Pass A: Original
    for x1, y1, x2, y2, conf, cls in _run_inference(preprocessed):
        all_raw.append((x1, y1, x2, y2, conf, cls))

    # Pass B: Horizontal flip
    h_flip = cv2.flip(preprocessed, 1)
    for x1, y1, x2, y2, conf, cls in _run_inference(h_flip):
        # Remap x coords
        x1_orig = img_w - x2
        x2_orig = img_w - x1
        all_raw.append((x1_orig, y1, x2_orig, y2, conf, cls))

    # Pass C: Vertical flip
    v_flip = cv2.flip(preprocessed, 0)
    for x1, y1, x2, y2, conf, cls in _run_inference(v_flip):
        # Remap y coords
        y1_orig = img_h - y2
        y2_orig = img_h - y1
        all_raw.append((x1, y1_orig, x2, y2_orig, conf, cls))

    # ── 3. Merge all detections ─────────────────────────────
    if len(all_raw) == 0:
        return _build_result([], img_bgr, orig_w, orig_h, conf_mult)

    boxes_tensor = torch.tensor(
        [[d[0], d[1], d[2], d[3]] for d in all_raw], dtype=torch.float32
    )
    scores_tensor = torch.tensor(
        [d[4] for d in all_raw], dtype=torch.float32
    )

    # ── 4. NMS via torchvision ──────────────────────────────
    keep_indices = torchvision.ops.nms(boxes_tensor, scores_tensor, iou_threshold=0.5)
    keep_indices = keep_indices.tolist()

    nms_dets = []
    for idx in keep_indices:
        x1, y1, x2, y2, conf, cls = all_raw[idx]
        adjusted_conf = conf * conf_mult
        display = _display_name(cls)
        nms_dets.append({
            "class_name": display,
            "confidence": round(float(adjusted_conf), 4),
            "confidence_pct": f"{adjusted_conf * 100:.1f}%",
            "bbox": [float(x1), float(y1), float(x2), float(y2)],  # still in 640x640 space
            "inferred": False,
        })

    # ── 5. Avudaiyar spatial inference ──────────────────────
    avudaiyar_dets = []
    for det in nms_dets:
        if det["class_name"] == "Lingam":
            lx1, ly1, lx2, ly2 = det["bbox"]
            l_height = ly2 - ly1
            av_x1 = lx1
            av_x2 = lx2
            av_y1 = ly2
            av_y2 = min(ly2 + l_height * 0.4, img_h)
            av_conf = det["confidence"] * 0.8
            avudaiyar_dets.append({
                "class_name": "Avudaiyar",
                "confidence": round(float(av_conf), 4),
                "confidence_pct": f"{av_conf * 100:.1f}%",
                "bbox": [float(av_x1), float(av_y1), float(av_x2), float(av_y2)],
                "inferred": True,
            })

    all_dets = nms_dets + avudaiyar_dets

    # ── 6. Scale bounding boxes back to original dimensions ─
    sx = orig_w / 640.0
    sy = orig_h / 640.0
    for det in all_dets:
        bx1, by1, bx2, by2 = det["bbox"]
        det["bbox"] = [
            int(round(bx1 * sx)),
            int(round(by1 * sy)),
            int(round(bx2 * sx)),
            int(round(by2 * sy)),
        ]

    # ── 7. Draw annotated image ─────────────────────────────
    annotated = img_bgr.copy()
    for det in all_dets:
        x1, y1, x2, y2 = det["bbox"]
        color = CLASS_COLORS.get(det["class_name"], (180, 180, 180))
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)

        label = f"{det['class_name']} {det['confidence_pct']}"
        font = cv2.FONT_HERSHEY_SIMPLEX
        scale = 0.55
        thickness = 2
        (tw, th), baseline = cv2.getTextSize(label, font, scale, thickness)
        cv2.rectangle(
            annotated,
            (x1, max(y1 - th - 10, 0)),
            (x1 + tw + 4, y1),
            color,
            -1,
        )
        cv2.putText(
            annotated,
            label,
            (x1 + 2, max(y1 - 4, th + 4)),
            font,
            scale,
            (255, 255, 255),
            thickness,
            cv2.LINE_AA,
        )

    # ── 8. Encode to base64 JPEG ────────────────────────────
    _, buf = cv2.imencode(".jpg", annotated, [cv2.IMWRITE_JPEG_QUALITY, 88])
    annotated_b64 = base64.b64encode(buf).decode("utf-8")

    return {
        "model_loaded": model_loaded,
        "detection_count": len(all_dets),
        "detections": all_dets,
        "annotated_image_base64": annotated_b64,
        "tta_used": True,
    }


def _build_result(dets, img_bgr, orig_w, orig_h, conf_mult):
    """Build result dict when there are no detections."""
    _, buf = cv2.imencode(".jpg", img_bgr, [cv2.IMWRITE_JPEG_QUALITY, 88])
    annotated_b64 = base64.b64encode(buf).decode("utf-8")
    return {
        "model_loaded": model_loaded,
        "detection_count": 0,
        "detections": [],
        "annotated_image_base64": annotated_b64,
        "tta_used": True,
    }
