"""
Temple Domain Knowledge & Spatial Validation

Applies South Indian Shiva temple structural rules to detection results:
1. Lingam elevation rule (should be above image midpoint)
2. Nandhi–Lingam proximity rule (should be within 40% of image width)
3. Temple structure scale rule (bbox area > 10% of image)

Does NOT hard-remove any detections — only adds domain_flags.
Adds domain_interpretation to the overall result.
"""


def validate(detection_result: dict) -> dict:
    """
    Apply domain-specific validation rules to detection results.

    Rules (flag only, do NOT remove detections):
      1. Lingam bottom edge should be above image midpoint if confidence < 0.45
      2. Nandhi center_x should be within 40% of Lingam center_x
      3. Temple Structure bbox area should be > 10% of image area

    Args:
        detection_result: dict from detector.detect()

    Returns:
        Same dict with 'domain_flags' added to each detection
        and top-level 'domain_interpretation' string added.
    """
    detections = detection_result.get("detections", [])

    # We need image dims to apply rules. Estimate from bbox extents if not provided.
    # Use the annotated image dimensions if available.
    # Since we don't have explicit dims, we'll use bbox maxima as a proxy.
    max_x = 1
    max_y = 1
    for d in detections:
        bbox = d.get("bbox", [0, 0, 0, 0])
        if bbox[2] > max_x:
            max_x = bbox[2]
        if bbox[3] > max_y:
            max_y = bbox[3]

    # Use larger estimates (detection boxes may not cover full image)
    img_w = max(max_x * 1.1, 640)
    img_h = max(max_y * 1.1, 640)
    img_midpoint_y = img_h / 2
    img_area = img_w * img_h

    # Collect class-specific detections
    lingams = [d for d in detections if d.get("class_name") == "Lingam"]
    nandhis = [d for d in detections if d.get("class_name") == "Nandhi"]
    temples = [
        d
        for d in detections
        if d.get("class_name") == "Temple Structure"
    ]

    # Initialize domain_flags for every detection
    for d in detections:
        d["domain_flags"] = []

    interpretation_parts = []
    total_detected = len(detections)
    inferred_count = sum(1 for d in detections if d.get("inferred", False))
    real_count = total_detected - inferred_count

    # ── Rule 1: Lingam elevation ───────────────────────────
    for ling in lingams:
        bbox = ling["bbox"]
        bottom_edge = bbox[3]
        conf = ling.get("confidence", 1.0)

        if bottom_edge > img_midpoint_y and conf < 0.45:
            ling["domain_flags"].append({
                "rule": "lingam_elevation",
                "status": "uncertain",
                "message": (
                    "Lingam bottom edge is below image midpoint with low "
                    "confidence — detection may be unreliable."
                ),
            })

    # ── Rule 2: Nandhi–Lingam proximity ────────────────────
    for nandhi in nandhis:
        n_bbox = nandhi["bbox"]
        n_cx = (n_bbox[0] + n_bbox[2]) / 2

        for ling in lingams:
            l_bbox = ling["bbox"]
            l_cx = (l_bbox[0] + l_bbox[2]) / 2
            distance_x = abs(n_cx - l_cx)
            threshold = img_w * 0.4

            if distance_x > threshold:
                nandhi["domain_flags"].append({
                    "rule": "nandhi_facing",
                    "status": "warning",
                    "message": (
                        f"Nandhi is far from Lingam (horizontal distance "
                        f"{distance_x:.0f}px, threshold {threshold:.0f}px). "
                        f"They typically face each other in Shiva temples."
                    ),
                })

    # ── Rule 3: Temple structure scale ─────────────────────
    for temple in temples:
        bbox = temple["bbox"]
        t_area = (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])
        area_ratio = t_area / img_area if img_area > 0 else 0

        if area_ratio < 0.10:
            temple["domain_flags"].append({
                "rule": "temple_scale",
                "status": "uncertain",
                "message": (
                    f"Temple Structure covers only {area_ratio * 100:.1f}% "
                    f"of the image (expected >10%). Detection may be a "
                    f"false positive or a distant view."
                ),
            })

    # ── Domain interpretation ──────────────────────────────
    if real_count == 0:
        interpretation_parts.append(
            "No temple-related objects were detected in this image."
        )
        interpretation_parts.append(
            "The image may not contain a recognizable temple structure, "
            "or quality is insufficient for reliable detection."
        )
    else:
        class_names = list(
            set(d["class_name"] for d in detections if not d.get("inferred"))
        )
        interpretation_parts.append(
            f"Detected {real_count} object(s): {', '.join(class_names)}."
        )

        # Check for any flagged detections
        flagged = [d for d in detections if len(d.get("domain_flags", [])) > 0]
        if flagged:
            interpretation_parts.append(
                f"{len(flagged)} detection(s) have domain-rule flags — "
                f"review recommended for accuracy."
            )
        else:
            interpretation_parts.append(
                "All detections pass domain validation. "
                "The temple structure appears consistent with expected patterns."
            )

    detection_result["domain_interpretation"] = " ".join(interpretation_parts)

    return detection_result
