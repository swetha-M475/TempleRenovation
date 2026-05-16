"""End-to-end API test script for the Temple Heritage Monitor Flask API."""
import requests
import json
import sys
import os
import numpy as np
import cv2

BASE = "http://127.0.0.1:5000"

def test_health():
    print("=" * 60)
    print("TEST: /api/health")
    r = requests.get(f"{BASE}/api/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["model_loaded"] == True
    assert data["database"]["status"] == "connected"
    print(f"  ✅ Health OK — Model loaded, DB connected, {data['database']['activity_count']} activities")

def test_analyze_with_image():
    print("=" * 60)
    print("TEST: /api/analyze (with test image)")
    
    # Create a simple test image
    img = np.random.randint(50, 200, (480, 640, 3), dtype=np.uint8)
    _, buf = cv2.imencode(".jpg", img)
    
    r = requests.post(
        f"{BASE}/api/analyze",
        files={"image": ("test.jpg", buf.tobytes(), "image/jpeg")},
    )
    assert r.status_code == 200, f"Status {r.status_code}: {r.text}"
    data = r.json()
    
    assert data["status"] == "success"
    assert "session_id" in data
    assert "image_hash" in data
    assert "quality" in data
    assert "detections" in data
    assert "annotated_image_base64" in data
    assert "preprocessing" in data
    
    session_id = data["session_id"]
    print(f"  ✅ Analyze OK — session_id={session_id[:8]}...")
    print(f"     Quality: blur={data['quality']['blur_level']}, brightness={data['quality']['brightness_level']}")
    print(f"     Detections: {data['detections']['detection_count']}")
    print(f"     Preprocessing: {data['preprocessing']}")
    print(f"     Image hash: {data['image_hash']}")
    
    return session_id

def test_analyze_error_no_image():
    print("=" * 60)
    print("TEST: /api/analyze (no image → error)")
    r = requests.post(f"{BASE}/api/analyze")
    assert r.status_code == 400
    data = r.json()
    assert data["status"] == "error"
    assert data["error_code"] == "NULL_IMAGE"
    print(f"  ✅ Error handling OK — {data['error_code']}: {data['error']}")

def test_analyze_error_empty():
    print("=" * 60)
    print("TEST: /api/analyze (empty file → error)")
    r = requests.post(
        f"{BASE}/api/analyze",
        files={"image": ("empty.jpg", b"", "image/jpeg")},
    )
    assert r.status_code == 400
    data = r.json()
    assert data["error_code"] == "NULL_IMAGE"
    print(f"  ✅ Error handling OK — {data['error_code']}: {data['error']}")

def test_analyze_error_corrupt():
    print("=" * 60)
    print("TEST: /api/analyze (corrupt file → error)")
    r = requests.post(
        f"{BASE}/api/analyze",
        files={"image": ("corrupt.jpg", b"not-an-image-at-all", "image/jpeg")},
    )
    assert r.status_code == 400
    data = r.json()
    assert data["error_code"] == "CORRUPT_IMAGE"
    print(f"  ✅ Error handling OK — {data['error_code']}: {data['error']}")

def test_analyze_error_tiny():
    print("=" * 60)
    print("TEST: /api/analyze (tiny image → error)")
    tiny = np.zeros((10, 10, 3), dtype=np.uint8)
    _, buf = cv2.imencode(".jpg", tiny)
    r = requests.post(
        f"{BASE}/api/analyze",
        files={"image": ("tiny.jpg", buf.tobytes(), "image/jpeg")},
    )
    assert r.status_code == 400
    data = r.json()
    assert data["error_code"] == "TOO_SMALL"
    print(f"  ✅ Error handling OK — {data['error_code']}: {data['error']}")

def test_activity_lookup(session_id):
    print("=" * 60)
    print(f"TEST: /api/activity/{session_id[:8]}...")
    r = requests.get(f"{BASE}/api/activity/{session_id}")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "success"
    assert data["activity"]["id"] == session_id
    print(f"  ✅ Activity lookup OK — found activity with hash={data['activity']['image_hash']}")

def test_history():
    print("=" * 60)
    print("TEST: /api/history")
    r = requests.get(f"{BASE}/api/history")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "success"
    assert data["total"] >= 1
    print(f"  ✅ History OK — {data['total']} activities, showing {len(data['activities'])}")

def test_compare_two_images():
    print("=" * 60)
    print("TEST: /api/compare (two images)")
    
    img1 = np.random.randint(50, 200, (480, 640, 3), dtype=np.uint8)
    img2 = img1.copy()
    img2[100:200, 100:200] = 0  # Create a difference
    
    _, buf1 = cv2.imencode(".jpg", img1)
    _, buf2 = cv2.imencode(".jpg", img2)
    
    r = requests.post(
        f"{BASE}/api/compare",
        files={
            "image1": ("img1.jpg", buf1.tobytes(), "image/jpeg"),
            "image2": ("img2.jpg", buf2.tobytes(), "image/jpeg"),
        },
    )
    assert r.status_code == 200, f"Status {r.status_code}: {r.text}"
    data = r.json()
    
    assert data["status"] == "success"
    assert "ssim" in data
    assert "changes" in data
    assert "diff_image_base64" in data
    
    print(f"  ✅ Compare OK — SSIM={data['ssim']['ssim_pct']}, change_level={data['changes']['change_level']}")
    print(f"     Structural regions: {data['ssim']['structural_change_regions']}")
    print(f"     Duplicate: {data['duplicate_check']['is_duplicate']}")

def test_compare_lookup_mode(session_id):
    print("=" * 60)
    print(f"TEST: /api/compare (lookup mode with activity {session_id[:8]}...)")
    
    img = np.random.randint(80, 220, (480, 640, 3), dtype=np.uint8)
    _, buf = cv2.imencode(".jpg", img)
    
    r = requests.post(
        f"{BASE}/api/compare",
        files={"image": ("current.jpg", buf.tobytes(), "image/jpeg")},
        data={"previous_activity_id": session_id},
    )
    assert r.status_code == 200, f"Status {r.status_code}: {r.text}"
    data = r.json()
    
    assert data["status"] == "success"
    assert data.get("lookup_mode") == True
    assert data.get("previous_activity_id") == session_id
    
    print(f"  ✅ Lookup compare OK — SSIM={data['ssim']['ssim_pct']}")
    print(f"     Used stored activity as baseline")

def test_compare_invalid_activity():
    print("=" * 60)
    print("TEST: /api/compare (invalid previous_activity_id → 404)")
    
    img = np.random.randint(50, 200, (480, 640, 3), dtype=np.uint8)
    _, buf = cv2.imencode(".jpg", img)
    
    r = requests.post(
        f"{BASE}/api/compare",
        files={"image": ("current.jpg", buf.tobytes(), "image/jpeg")},
        data={"previous_activity_id": "nonexistent-id-12345"},
    )
    assert r.status_code == 404
    data = r.json()
    assert data["error_code"] == "ACTIVITY_NOT_FOUND"
    print(f"  ✅ Error handling OK — {data['error_code']}")


if __name__ == "__main__":
    print("\n🧪 Temple Heritage Monitor — API Test Suite\n")
    
    try:
        test_health()
        test_analyze_error_no_image()
        test_analyze_error_empty()
        test_analyze_error_corrupt()
        test_analyze_error_tiny()
        sid = test_analyze_with_image()
        test_activity_lookup(sid)
        test_history()
        test_compare_two_images()
        test_compare_lookup_mode(sid)
        test_compare_invalid_activity()
        
        print("\n" + "=" * 60)
        print("🎉 ALL TESTS PASSED!")
        print("=" * 60)
    except AssertionError as e:
        print(f"\n❌ TEST FAILED: {e}")
        sys.exit(1)
    except requests.ConnectionError:
        print("\n❌ Cannot connect to server. Make sure Flask is running on port 5000.")
        sys.exit(1)
