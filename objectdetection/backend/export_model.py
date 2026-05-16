"""
ONNX Model Export Utility

    Exports the YOLOv8 model (best.pt) to various formats for inference.

Usage:
    python export_model.py                  # Export to ONNX (default)
    python export_model.py --format onnx    # Explicit ONNX export
    python export_model.py --format tflite  # TFLite export (for Flutter/Android)
    python export_model.py --format engine  # TensorRT export (requires NVIDIA GPU)

Benefits:
    ONNX:     2-3x CPU speedup, framework-agnostic, works everywhere
    TFLite:   On-device inference on Android/iOS via Flutter
    TensorRT: 5-10x GPU speedup, requires NVIDIA GPU + TensorRT SDK

After exporting:
    ONNX:   model = YOLO("models/best.onnx")
    TFLite: Copy best_float32.tflite to Flutter assets/models/
"""

import argparse
import sys
from pathlib import Path


def export_model(format_type: str = "onnx", imgsz: int = 640, simplify: bool = True):
    """
    Export YOLOv8 model to the specified format.

    Args:
        format_type: 'onnx' or 'engine' (TensorRT)
        imgsz: Input image size for the exported model
        simplify: Whether to simplify the ONNX graph (recommended)
    """
    try:
        from ultralytics import YOLO
    except ImportError:
        print("[export] Error: ultralytics not installed.")
        print("         Run: pip install ultralytics")
        sys.exit(1)

    model_path = Path(__file__).parent / "models" / "best.pt"
    if not model_path.exists():
        print(f"[export] Error: Model not found at {model_path}")
        sys.exit(1)

    print(f"[export] Loading model from {model_path}")
    model = YOLO(str(model_path))

    print(f"[export] Exporting to {format_type.upper()} (imgsz={imgsz})...")

    if format_type == "onnx":
        export_path = model.export(
            format="onnx",
            imgsz=imgsz,
            simplify=simplify,
            dynamic=False,        # Fixed input size for best performance
            opset=17,             # ONNX opset version
        )
        print(f"\n[export] ✅ ONNX model exported to: {export_path}")
        print(f"[export]    To use: model = YOLO('{export_path}')")
        print(f"[export]    Install runtime: pip install onnxruntime")

    elif format_type == "tflite":
        export_path = model.export(
            format="tflite",
            imgsz=imgsz,
            int8=False,           # Float32 for accuracy (use int8=True for speed)
        )
        print(f"\n[export] ✅ TFLite model exported to: {export_path}")
        print(f"[export]    Copy to Flutter: assets/models/best_float32.tflite")
        print(f"[export]    Also copy labels.txt with class names")
        # Print model classes for reference
        print(f"[export]    Classes: {list(model.names.values())}")

    elif format_type == "engine":
        print("[export] ⚠️  TensorRT export requires NVIDIA GPU + TensorRT SDK")
        try:
            export_path = model.export(
                format="engine",
                imgsz=imgsz,
                dynamic=False,
                half=True,  # FP16 for faster inference
            )
            print(f"\n[export] ✅ TensorRT model exported to: {export_path}")
        except Exception as e:
            print(f"\n[export] ❌ TensorRT export failed: {e}")
            print("[export]    Make sure TensorRT is installed and GPU is available.")
            sys.exit(1)

    else:
        print(f"[export] Unknown format: {format_type}")
        print("[export] Supported: onnx, engine")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export YOLOv8 model")
    parser.add_argument(
        "--format", "-f",
        choices=["onnx", "tflite", "engine"],
        default="onnx",
        help="Export format: onnx (server), tflite (Flutter/Android), engine (TensorRT)",
    )
    parser.add_argument(
        "--imgsz", "-s",
        type=int,
        default=640,
        help="Input image size (default: 640)",
    )
    parser.add_argument(
        "--no-simplify",
        action="store_true",
        help="Disable ONNX graph simplification",
    )

    args = parser.parse_args()
    export_model(
        format_type=args.format,
        imgsz=args.imgsz,
        simplify=not args.no_simplify,
    )
