import 'dart:ui';

/// Represents a single detected object from YOLOv8 inference.
class DetectedObject {
  /// Class name (e.g., "Lingam", "Nandhi", "Temple Structure", "Shed")
  final String className;

  /// Raw model class name (e.g., "lingam", "nandhi", "old Temple", "shed")
  final String rawClassName;

  /// Detection confidence score (0.0 – 1.0)
  final double confidence;

  /// Formatted confidence string (e.g., "87.3%")
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Bounding box in original image coordinates [x1, y1, x2, y2]
  final Rect boundingBox;

  const DetectedObject({
    required this.className,
    required this.rawClassName,
    required this.confidence,
    required this.boundingBox,
  });

  @override
  String toString() =>
      'DetectedObject($className $confidencePercent @ $boundingBox)';
}

/// Image Quality Assessment Results
class ImageQualityResult {
  final double blurScore;
  final String blurLevel;
  final double brightness;
  final String brightnessLevel;
  final String reliability;
  final double confidenceMultiplier;
  final bool passesQualityGate;
  final List<String> warnings;

  const ImageQualityResult({
    required this.blurScore,
    required this.blurLevel,
    required this.brightness,
    required this.brightnessLevel,
    required this.reliability,
    required this.confidenceMultiplier,
    required this.passesQualityGate,
    required this.warnings,
  });
}

/// Result of running temple object detection on a single image.
class TempleDetectionResult {
  /// Whether the image passes the temple validation gate
  final bool isApproved;

  /// Highest detection confidence across all detections
  final double highestConfidence;

  /// Class name with the highest confidence (null if no detections)
  final String? bestClass;

  /// All detected objects
  final List<DetectedObject> detections;

  /// Human-readable summary message
  final String summaryMessage;

  /// Original image dimensions
  final int imageWidth;
  final int imageHeight;

  /// Image Quality Assessment (Blur, Brightness)
  final ImageQualityResult? quality;

  /// Processing time in milliseconds
  final int processingTimeMs;

  const TempleDetectionResult({
    required this.isApproved,
    required this.highestConfidence,
    required this.bestClass,
    required this.detections,
    required this.summaryMessage,
    required this.imageWidth,
    required this.imageHeight,
    this.quality,
    this.processingTimeMs = 0,
  });

  /// Number of detected objects
  int get detectionCount => detections.length;

  /// Get detections grouped by class name
  Map<String, List<DetectedObject>> get detectionsByClass {
    final map = <String, List<DetectedObject>>{};
    for (final det in detections) {
      map.putIfAbsent(det.className, () => []).add(det);
    }
    return map;
  }

  /// Factory for when the model is not loaded
  factory TempleDetectionResult.modelNotLoaded() {
    return const TempleDetectionResult(
      isApproved: false,
      highestConfidence: 0.0,
      bestClass: null,
      detections: [],
      summaryMessage: 'Detection model is not loaded. Please ensure the model file is in assets/models/.',
      imageWidth: 0,
      imageHeight: 0,
      quality: null,
    );
  }

  /// Factory for when detection fails
  factory TempleDetectionResult.error(String errorMsg) {
    return TempleDetectionResult(
      isApproved: false,
      highestConfidence: 0.0,
      bestClass: null,
      detections: [],
      summaryMessage: 'Detection failed: $errorMsg',
      imageWidth: 0,
      imageHeight: 0,
      quality: null,
    );
  }
}
