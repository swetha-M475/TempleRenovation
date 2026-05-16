# 🛕 South Indian Temple Heritage Monitoring & Structural Analysis System

AI-powered computer vision system for monitoring and analyzing South Indian temple heritage sites. Detect key structural elements, compare inspection images over time, and identify anomalies or structural changes.

---

## 🏗️ Project Structure

```
temple-monitor/
├── backend/
│   ├── app.py                    # Flask API server
│   ├── engine/
│   │   ├── __init__.py
│   │   ├── detector.py           # YOLOv8 detection with TTA
│   │   ├── quality.py            # Image quality assessment
│   │   ├── similarity.py         # SSIM comparison
│   │   ├── change_detector.py    # Object-level change detection
│   │   ├── orientation.py        # Orientation & duplicate detection
│   │   └── domain.py             # Temple domain validation
│   ├── models/
│   │   └── best.pt               # YOLOv8 custom model (not included in repo)
│   └── requirements.txt
├── frontend/
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       ├── app.js
│       ├── upload.js
│       └── results.js
└── README.md
```

---

## 🚀 Setup Instructions

### Prerequisites

- Python 3.10+
- pip

### 1. Place the Model File

Copy your trained YOLOv8 model to:

```
backend/models/best.pt
```

The model should be trained on temple-related classes: `lingam`, `nandhi`, `old Temple`, `shed`.

### 2. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 3. Run the Server

```bash
cd backend
python app.py
```

The server starts at **http://localhost:5000**. The frontend is served automatically.

---

## 📡 API Endpoints

### `GET /api/health`

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "model_loaded": true,
  "classes": ["lingam", "nandhi", "old Temple", "shed"]
}
```

---

### `POST /api/analyze`

Analyze a single temple image.

**Request:** `multipart/form-data` with field `image`

**Response:**
```json
{
  "status": "success",
  "quality": {
    "blur_score": 234.5,
    "blur_level": "low",
    "brightness": 128.3,
    "brightness_level": "normal",
    "noise_score": 18.7,
    "reliability": "high",
    "confidence_multiplier": 1.0
  },
  "detections": {
    "model_loaded": true,
    "detection_count": 3,
    "detections": [
      {
        "class_name": "Lingam",
        "confidence": 0.8732,
        "confidence_pct": "87.3%",
        "bbox": [120, 150, 280, 310],
        "inferred": false,
        "domain_flags": []
      }
    ],
    "annotated_image_base64": "...",
    "tta_used": true,
    "domain_interpretation": "..."
  },
  "orientation": {
    "orientation": "landscape",
    "rotation_detected": false,
    "width": 1920,
    "height": 1080
  },
  "timestamp": "2024-01-01T00:00:00+00:00"
}
```

---

### `POST /api/compare`

Compare two temple images.

**Request:** `multipart/form-data` with fields `image1` and `image2`

**Response:**
```json
{
  "status": "success",
  "image1_quality": { "..." },
  "image2_quality": { "..." },
  "image1_detections": { "..." },
  "image2_detections": { "..." },
  "similarity": {
    "ssim_score": 0.8745,
    "ssim_pct": "87.5%",
    "similarity_label": "Very similar",
    "structural_change_regions": 2,
    "illumination_change_regions": 5,
    "diff_image_base64": "...",
    "interpretation": "..."
  },
  "changes": {
    "new_objects": [],
    "removed_objects": [],
    "shifted_objects": [],
    "stable_objects": ["Lingam", "Nandhi"],
    "anomalies": [],
    "change_level": "minor",
    "change_summary": "..."
  },
  "duplicate_check": {
    "is_duplicate": false,
    "phash_distance": 14
  },
  "timestamp": "2024-01-01T00:00:00+00:00"
}
```

---

## 🔬 Detection Classes

| Model Class | Display Name | Description |
|---|---|---|
| `lingam` | Lingam | Shiva Lingam — sacred cylindrical stone |
| `nandhi` | Nandhi | Sacred bull, vehicle of Lord Shiva |
| `old Temple` | Temple Structure | Main temple architectural elements |
| `shed` | Shed / Auxiliary Structure | Supporting structures |
| *(inferred)* | Avudaiyar | Base platform inferred below Lingam |

---

## 🖼️ Screenshots

<!-- Add screenshots of the running application here -->

| Analyze | Compare | About |
|---|---|---|
| ![Analyze](screenshots/analyze.png) | ![Compare](screenshots/compare.png) | ![About](screenshots/about.png) |

---

## 🏛️ Domain Rules

1. **Lingam Elevation**: Lingam should be positioned above the image midpoint (it sits on an elevated Avudaiyar)
2. **Nandhi Proximity**: Nandhi should be within 40% of the image width from Lingam (they face each other)
3. **Temple Scale**: Temple Structure bounding box should cover >10% of image area

These rules add **flags** to detections — they never remove detections.

---

## ⚙️ Technical Stack

- **Backend**: Flask 3.0.3, OpenCV, scikit-image, PyTorch, Ultralytics YOLOv8
- **Frontend**: Vanilla HTML/CSS/JS (zero external frameworks)
- **Detection**: Custom YOLOv8 with 3-pass Test-Time Augmentation + torchvision NMS
- **Similarity**: SSIM with structural vs illumination change classification
- **Hashing**: pHash via imagehash for duplicate detection

---

## 📜 License

This project is for educational and heritage preservation purposes.
