"""
Change Detection Module

Compares detection results from two images to identify:
- New objects (in image 2 but not image 1)
- Removed objects (in image 1 but not image 2)
- Shifted objects (same class, low IoU)
- Stable objects (same class, high IoU)
- Anomaly detection (critical shifts of sacred objects)
- Overall change level classification
"""


def compute_iou(box1, box2):
    """Compute IoU between two [x1,y1,x2,y2] bounding boxes."""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    intersection = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union = area1 + area2 - intersection

    return intersection / union if union > 0 else 0.0


def analyze(det1: dict, det2: dict, ssim_result: dict) -> dict:
    """
    Compare detection results from two images.

    Args:
        det1: detector.detect() result for image 1
        det2: detector.detect() result for image 2
        ssim_result: similarity.compare() result

    Returns:
        Structured change analysis dict
    """
    detections1 = det1.get("detections", [])
    detections2 = det2.get("detections", [])

    # Build class sets
    classes1 = {}
    for d in detections1:
        cls = d["class_name"]
        if cls not in classes1:
            classes1[cls] = []
        classes1[cls].append(d)

    classes2 = {}
    for d in detections2:
        cls = d["class_name"]
        if cls not in classes2:
            classes2[cls] = []
        classes2[cls].append(d)

    all_classes = set(list(classes1.keys()) + list(classes2.keys()))

    new_objects = []
    removed_objects = []
    shifted_objects = []
    stable_objects = []
    anomalies = []
    critical_anomaly = False

    for cls in all_classes:
        in_det1 = cls in classes1
        in_det2 = cls in classes2

        if in_det2 and not in_det1:
            # New object
            new_objects.append(cls)
            continue

        if in_det1 and not in_det2:
            # Removed object
            removed_objects.append(cls)
            continue

        # Shared class — compare best-matching boxes
        dets_a = classes1[cls]
        dets_b = classes2[cls]

        for da in dets_a:
            best_iou = 0.0
            for db in dets_b:
                iou = compute_iou(da["bbox"], db["bbox"])
                if iou > best_iou:
                    best_iou = iou

            if best_iou < 0.3:
                shifted_objects.append({
                    "class": cls,
                    "iou": round(best_iou, 4),
                })
                # Check for critical anomaly
                if cls == "Lingam":
                    critical_anomaly = True
                    anomalies.append({
                        "type": "Lingam displacement",
                        "description": (
                            f"Lingam position has shifted significantly "
                            f"(IoU={best_iou:.3f}). This may indicate "
                            f"physical displacement or structural damage."
                        ),
                        "severity": "critical",
                    })
            else:
                if cls not in stable_objects:
                    stable_objects.append(cls)

    # Overall change level
    ssim_score = ssim_result.get("ssim_score", 1.0)

    if ssim_score < 0.60 or critical_anomaly:
        change_level = "major"
    elif ssim_score < 0.85 or new_objects or removed_objects:
        change_level = "moderate"
    else:
        change_level = "minor"

    # Change summary
    parts = []
    if new_objects:
        parts.append(f"{len(new_objects)} new object(s) detected")
    if removed_objects:
        parts.append(f"{len(removed_objects)} object(s) no longer visible")
    if shifted_objects:
        parts.append(f"{len(shifted_objects)} object(s) shifted in position")
    if stable_objects:
        parts.append(f"{len(stable_objects)} object(s) remain stable")

    if not parts:
        change_summary = "No significant object-level changes detected between the two images."
    else:
        change_summary = "; ".join(parts) + f" — overall change level: {change_level}."

    return {
        "new_objects": new_objects,
        "removed_objects": removed_objects,
        "shifted_objects": shifted_objects,
        "stable_objects": stable_objects,
        "anomalies": anomalies,
        "change_level": change_level,
        "change_summary": change_summary,
    }
