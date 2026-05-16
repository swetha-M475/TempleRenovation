"""
Orientation & Duplication Detection Module

Handles:
- Single image orientation detection (portrait/landscape/square)
- Rotation detection via ORB feature matching with homography
- Duplicate image detection via perceptual hashing (pHash)
"""

import cv2
import numpy as np
import imagehash
from PIL import Image


def check(img_bgr: np.ndarray) -> dict:
    """
    Determine image orientation and detect rotation artifacts.

    Uses ORB feature matching against a 90-degree rotated copy
    to detect if the image contains rotation > 5 degrees.

    Returns:
        {orientation, rotation_detected, width, height}
    """
    h, w = img_bgr.shape[:2]

    # Orientation classification
    if h > w:
        orientation = "portrait"
    elif w > h:
        orientation = "landscape"
    else:
        orientation = "square"

    # Rotation detection via ORB
    rotation_detected = False
    try:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

        # Create a 90-degree rotated copy
        rotated_90 = cv2.rotate(gray, cv2.ROTATE_90_CLOCKWISE)
        # Resize rotated to match original dimensions for feature matching
        rotated_90 = cv2.resize(rotated_90, (w, h))

        orb = cv2.ORB_create(nfeatures=500)
        kp1, des1 = orb.detectAndCompute(gray, None)
        kp2, des2 = orb.detectAndCompute(rotated_90, None)

        if (
            des1 is not None
            and des2 is not None
            and len(des1) >= 10
            and len(des2) >= 10
        ):
            bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
            matches = bf.match(des1, des2)
            matches = sorted(matches, key=lambda m: m.distance)

            if len(matches) >= 10:
                good = matches[: min(50, len(matches))]
                src_pts = np.float32(
                    [kp1[m.queryIdx].pt for m in good]
                ).reshape(-1, 1, 2)
                dst_pts = np.float32(
                    [kp2[m.trainIdx].pt for m in good]
                ).reshape(-1, 1, 2)

                M, mask = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC, 5.0)
                if M is not None:
                    angle = abs(np.degrees(np.arctan2(M[1, 0], M[0, 0])))
                    if angle > 5.0:
                        rotation_detected = True
    except Exception:
        pass

    return {
        "orientation": orientation,
        "rotation_detected": bool(rotation_detected),
        "width": int(w),
        "height": int(h),
    }


def check_duplicate(img1_bgr: np.ndarray, img2_bgr: np.ndarray) -> dict:
    """
    Check if two images are duplicates using perceptual hashing.

    Computes pHash for each image and compares Hamming distance.
    Distance < 10 → duplicate.

    Returns:
        {is_duplicate, phash_distance}
    """
    # Convert BGR → RGB → PIL
    pil1 = Image.fromarray(cv2.cvtColor(img1_bgr, cv2.COLOR_BGR2RGB))
    pil2 = Image.fromarray(cv2.cvtColor(img2_bgr, cv2.COLOR_BGR2RGB))

    hash1 = imagehash.phash(pil1)
    hash2 = imagehash.phash(pil2)

    hamming_distance = int(abs(hash1 - hash2))
    is_duplicate = hamming_distance < 10

    return {
        "is_duplicate": is_duplicate,
        "phash_distance": hamming_distance,
    }
