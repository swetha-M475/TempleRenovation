"""
SSIM Similarity Analysis Module

Computes structural similarity between two images:
- SSIM score with full difference map
- Structural vs illumination change classification
- Diff visualization with colored contour overlay
"""

import cv2
import numpy as np
import base64
from skimage.metrics import structural_similarity


def compare(img1_bgr: np.ndarray, img2_bgr: np.ndarray) -> dict:
    """
    Compare two BGR images using SSIM and generate diff visualization.

    Steps:
      1. Resize img2 to match img1 dimensions
      2. Convert both to grayscale
      3. Compute SSIM with full diff map
      4. Threshold + contour analysis for change regions
      5. Classify each region as structural or illumination
      6. Generate colored diff visualization
      7. Return structured result dict
    """
    # ── 1. Resize img2 to match img1 ───────────────────────
    h1, w1 = img1_bgr.shape[:2]
    img2_resized = cv2.resize(img2_bgr, (w1, h1), interpolation=cv2.INTER_AREA)

    # ── 2. Convert to grayscale ────────────────────────────
    gray1 = cv2.cvtColor(img1_bgr, cv2.COLOR_BGR2GRAY)
    gray2 = cv2.cvtColor(img2_resized, cv2.COLOR_BGR2GRAY)

    # ── 3. SSIM computation ────────────────────────────────
    # Determine appropriate win_size (must be odd and <= smallest dimension)
    min_dim = min(gray1.shape[0], gray1.shape[1])
    win_size = min(7, min_dim)
    if win_size % 2 == 0:
        win_size -= 1
    if win_size < 3:
        win_size = 3

    score, diff_map = structural_similarity(
        gray1, gray2, full=True, win_size=win_size, data_range=255
    )

    # ── 4. Difference map processing ───────────────────────
    diff_uint8 = ((1 - diff_map) * 255).astype(np.uint8)
    _, thresh = cv2.threshold(
        diff_uint8, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )
    contours, _ = cv2.findContours(
        thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    # Keep only significant contours (area > 200 pixels)
    significant_contours = [c for c in contours if cv2.contourArea(c) > 200]

    # ── 5. Classify each region ────────────────────────────
    structural_contours = []
    illumination_contours = []

    for contour in significant_contours:
        x, y, cw, ch = cv2.boundingRect(contour)
        # Clamp ROI to image bounds
        x2 = min(x + cw, w1)
        y2 = min(y + ch, h1)
        if x2 <= x or y2 <= y:
            illumination_contours.append(contour)
            continue

        roi1 = gray1[y:y2, x:x2]
        roi2 = gray2[y:y2, x:x2]

        if roi1.size == 0 or roi2.size == 0:
            illumination_contours.append(contour)
            continue

        # Edge density comparison
        edges1 = cv2.Canny(roi1, 50, 150)
        edges2 = cv2.Canny(roi2, 50, 150)
        ed1 = np.count_nonzero(edges1) / edges1.size if edges1.size > 0 else 0
        ed2 = np.count_nonzero(edges2) / edges2.size if edges2.size > 0 else 0
        edge_density_diff = abs(ed1 - ed2)

        if edge_density_diff > 0.15:
            structural_contours.append(contour)
        else:
            illumination_contours.append(contour)

    # ── 6. Generate diff visualization ─────────────────────
    vis = img1_bgr.copy()

    # Draw structural contours in red
    if structural_contours:
        cv2.drawContours(vis, structural_contours, -1, (0, 0, 255), 2)

    # Draw illumination contours in yellow
    if illumination_contours:
        cv2.drawContours(vis, illumination_contours, -1, (0, 220, 220), 1)

    # Semi-transparent orange heatmap overlay on structural regions
    if structural_contours:
        overlay = vis.copy()
        cv2.drawContours(overlay, structural_contours, -1, (0, 80, 255), -1)
        cv2.addWeighted(overlay, 0.35, vis, 0.65, 0, vis)

    _, diff_buf = cv2.imencode(".jpg", vis, [cv2.IMWRITE_JPEG_QUALITY, 90])
    diff_b64 = base64.b64encode(diff_buf).decode("utf-8")

    # ── 7. Similarity label ────────────────────────────────
    if score >= 0.97:
        similarity_label = "Identical"
    elif score >= 0.85:
        similarity_label = "Very similar"
    elif score >= 0.60:
        similarity_label = "Similar — notable differences"
    else:
        similarity_label = "Significantly different"

    # Human-readable interpretation
    struct_count = len(structural_contours)
    illum_count = len(illumination_contours)
    total_regions = struct_count + illum_count

    if total_regions == 0:
        interpretation = (
            f"The images are {similarity_label.lower()} with an SSIM of "
            f"{score:.2%}. No significant change regions were detected."
        )
    else:
        interpretation = (
            f"SSIM score of {score:.2%} indicates the images are "
            f"{similarity_label.lower()}. {struct_count} structural and "
            f"{illum_count} illumination change regions were identified."
        )

    return {
        "ssim_score": round(float(score), 4),
        "ssim_pct": f"{score * 100:.1f}%",
        "similarity_label": similarity_label,
        "structural_change_regions": struct_count,
        "illumination_change_regions": illum_count,
        "diff_image_base64": diff_b64,
        "interpretation": interpretation,
    }
