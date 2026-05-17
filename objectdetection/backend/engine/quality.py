"""
Image Quality Assessment & Preprocessing Module

Provides:
- Mobile image preprocessing (auto-resize for inference)
- Blur detection via Laplacian variance
- Brightness analysis via mean grayscale intensity
- Noise estimation via Laplacian standard deviation
- Confidence multiplier for downstream detection
- Quality gate for comparison reliability
"""

import cv2
import numpy as np


# ─── Mobile Preprocessing ─────────────────────────────────
def preprocess_for_inference(
    img_bgr: np.ndarray,
    max_dimension: int = 640,
) -> tuple:
    """
    Resize high-resolution mobile photos for efficient inference.

    Downscales the image so its longest side equals `max_dimension`,
    preserving aspect ratio. Uses INTER_AREA for high-quality downscaling.

    Args:
        img_bgr: Input BGR image (any resolution)
        max_dimension: Target max dimension (640 or 1024)

    Returns:
        tuple of (resized_img, scale_factor, original_size)
        - resized_img: The resized BGR image
        - scale_factor: float ratio (original / resized) for bbox remapping
        - original_size: (orig_width, orig_height)
    """
    orig_h, orig_w = img_bgr.shape[:2]
    original_size = (orig_w, orig_h)

    longest_side = max(orig_w, orig_h)

    # No resize needed if image is already small enough
    if longest_side <= max_dimension:
        return img_bgr, 1.0, original_size

    # Compute scale to fit longest side into max_dimension
    scale = max_dimension / longest_side
    new_w = int(orig_w * scale)
    new_h = int(orig_h * scale)

    resized = cv2.resize(
        img_bgr, (new_w, new_h), interpolation=cv2.INTER_AREA
    )

    # scale_factor: multiply resized coords by this to get original coords
    scale_factor = 1.0 / scale

    return resized, scale_factor, original_size


# ─── Quality Assessment ───────────────────────────────────
def assess(img_bgr: np.ndarray) -> dict:
    """
    Run full image quality assessment on a BGR image.

    Returns dict with blur, brightness, noise metrics,
    reliability rating, and confidence multiplier.
    """
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # ── Blur detection ──────────────────────────────────────
    laplacian = cv2.Laplacian(gray, cv2.CV_64F)
    lap_var = float(laplacian.var())

    if lap_var < 50:
        blur_level = "high"
        reliability = "low"
        confidence_multiplier = 0.7
    elif lap_var < 150:
        blur_level = "medium"
        reliability = "medium"
        confidence_multiplier = 0.85
    else:
        blur_level = "low"
        reliability = "high"
        confidence_multiplier = 1.0

    # ── Brightness ──────────────────────────────────────────
    mean_brightness = float(gray.mean())

    if mean_brightness < 60:
        brightness_level = "dark"
    elif mean_brightness < 180:
        brightness_level = "normal"
    else:
        brightness_level = "bright"

    # ── Noise ───────────────────────────────────────────────
    noise_score = float(cv2.Laplacian(gray, cv2.CV_64F).std())

    # ── Resolution info ─────────────────────────────────────
    h, w = img_bgr.shape[:2]

    return {
        "blur_score": round(lap_var, 4),
        "blur_level": blur_level,
        "brightness": round(mean_brightness, 4),
        "brightness_level": brightness_level,
        "noise_score": round(noise_score, 4),
        "reliability": reliability,
        "confidence_multiplier": confidence_multiplier,
        "resolution": {"width": int(w), "height": int(h)},
    }


# ─── Quality Gate ─────────────────────────────────────────
def check_quality_gate(quality_result: dict) -> dict:
    """
    Evaluate whether image quality is sufficient for reliable analysis.

    Returns:
        dict with:
        - passes: bool — True if quality is acceptable
        - warnings: list of warning strings
        - comparison_reliable: bool — True if comparison results would be trustworthy
    """
    warnings = []
    passes = True
    comparison_reliable = True

    blur = quality_result.get("blur_score", 100)
    brightness = quality_result.get("brightness", 128)

    if blur < 20:
        passes = False
        comparison_reliable = False
        warnings.append(
            f"Extremely blurry image (blur_score={blur:.1f}). "
            "Please hold the camera steady."
        )
    elif blur < 50:
        comparison_reliable = False
        warnings.append(
            "Image blur is high. Comparison results may be unreliable."
        )

    if brightness < 30:
        passes = False
        comparison_reliable = False
        warnings.append(
            f"Very dark image (brightness={brightness:.1f}). "
            "Consider using better lighting."
        )

    if brightness > 240:
        warnings.append(
            f"Overexposed image (brightness={brightness:.1f}). "
            "Details may be washed out."
        )

    return {
        "passes": passes,
        "warnings": warnings,
        "comparison_reliable": comparison_reliable,
    }
