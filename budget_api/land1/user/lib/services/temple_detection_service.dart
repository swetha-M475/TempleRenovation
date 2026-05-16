import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/temple_detection_result.dart';

/// Remote temple heritage object detection using the local Python Flask API.
///
/// Detects: Lingam, Nandhi, Temple Structure, Shed
/// Used to validate images before upload in project proposals.
///
/// Usage:
/// ```dart
/// final service = TempleDetectionService();
/// await service.loadModel(); // No-op for API
/// final result = await service.detectFromFile(File('path/to/image.jpg'));
/// if (result.isApproved) { /* add image */ }
/// ```
class TempleDetectionService {
  // ─── Singleton ─────────────────────────────────────────────
  static final TempleDetectionService _instance = TempleDetectionService._();
  factory TempleDetectionService() => _instance;
  TempleDetectionService._();

  // ─── Configuration ─────────────────────────────────────────
  
  // NOTE: If testing on a physical device, 127.0.0.1 won't work.
  // Replace with your laptop's local IP address (e.g., '192.168.1.5').
  // For Android emulator, '10.0.2.2' maps to the host's localhost.
  static const String _apiUrl = 'http://192.168.225.51:5000/api/analyze';

  /// Minimum confidence for a detection to count as valid
  static const double minConfidenceThreshold = 0.20;

  // ─── State ─────────────────────────────────────────────────
  bool _isLoaded = true; // Always true for API

  bool get isLoaded => _isLoaded;

  // ─── Load Model ────────────────────────────────────────────

  /// Load model (No-op since we use a REST API)
  Future<void> loadModel() async {
    _isLoaded = true;
    print('[TempleDetection] Using REST API at $_apiUrl');
  }

  // ─── Detect from File ──────────────────────────────────────

  /// Run object detection on a single image file via REST API.
  ///
  /// Returns [TempleDetectionResult] with detections and approval status.
  Future<TempleDetectionResult> detectFromFile(File imageFile) async {
    final stopwatch = Stopwatch()..start();

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', 
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        )
      );

      print('[TempleDetection] Sending request to $_apiUrl...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      stopwatch.stop();

      if (response.statusCode != 200) {
        print('[TempleDetection] API Error: ${response.statusCode} - ${response.body}');
        return TempleDetectionResult.error('API Error: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'success') {
        return TempleDetectionResult.error(data['message'] ?? 'Unknown API error');
      }

      return _parseApiResponse(data, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      print('[TempleDetection] Detection error: $e');
      return TempleDetectionResult.error(e.toString());
    }
  }

  // ─── Result Builder ────────────────────────────────────────

  TempleDetectionResult _parseApiResponse(Map<String, dynamic> data, int processingTimeMs) {
    final qualityData = data['quality'] ?? {};
    final qualityGate = data['quality_gate'] ?? {};
    final detectionsData = data['detections'] ?? {};

    // 1. Build Quality Result
    final double blurScore = (qualityData['varianceLaplacian'] ?? 0.0).toDouble();
    final String blurLevel = qualityData['blur_level'] ?? 'unknown';
    final double brightness = (qualityData['meanBrightness'] ?? 0.0).toDouble();
    final String brightnessLevel = qualityData['brightness_level'] ?? 'unknown';
    final double confidenceMultiplier = (qualityData['confidence_multiplier'] ?? 1.0).toDouble();
    final bool passesQualityGate = qualityGate['passed'] ?? true;
    
    final List<String> warnings = [];
    if (qualityGate['message'] != null && qualityGate['message'].toString().isNotEmpty) {
      warnings.add(qualityGate['message']);
    }

    final quality = ImageQualityResult(
      blurScore: blurScore,
      blurLevel: blurLevel,
      brightness: brightness,
      brightnessLevel: brightnessLevel,
      reliability: blurLevel == 'low' ? 'high' : 'medium',
      confidenceMultiplier: confidenceMultiplier,
      passesQualityGate: passesQualityGate,
      warnings: warnings,
    );

    // 2. Parse Diffs & Image Size
    final preprocessing = data['preprocessing'] ?? {};
    final originalSize = preprocessing['original_size'] ?? {};
    final int origWidth = originalSize['width'] ?? 640;
    final int origHeight = originalSize['height'] ?? 640;
    final double scaleFactor = (preprocessing['scale_factor'] ?? 1.0).toDouble();

    // 3. Build Detections
    final List<dynamic> rawDetections = detectionsData['detections'] ?? [];
    final detections = <DetectedObject>[];

    for (final det in rawDetections) {
      final String className = det['class_name'] ?? 'Unknown';
      final double confidence = (det['confidence'] ?? 0.0).toDouble();
      final List<dynamic> bbox = det['bbox'] ?? [0.0, 0.0, 0.0, 0.0];

      // API returns bbox in scaled inference resolution space (640x640 typically)
      // We must scale it back to original image size
      final double x1 = (bbox[0] as num).toDouble() / scaleFactor;
      final double y1 = (bbox[1] as num).toDouble() / scaleFactor;
      final double x2 = (bbox[2] as num).toDouble() / scaleFactor;
      final double y2 = (bbox[3] as num).toDouble() / scaleFactor;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);

      if (confidence >= minConfidenceThreshold) {
        detections.add(DetectedObject(
          className: className,
          rawClassName: className,
          confidence: confidence,
          boundingBox: rect,
        ));
      }
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    // 4. Build Final Result
    if (!passesQualityGate) {
      return TempleDetectionResult(
        isApproved: false,
        highestConfidence: 0.0,
        bestClass: null,
        detections: [],
        summaryMessage: qualityGate['message'] ?? 'Image quality is too poor.',
        imageWidth: origWidth,
        imageHeight: origHeight,
        processingTimeMs: processingTimeMs,
        quality: quality,
      );
    }

    if (detections.isEmpty) {
      return TempleDetectionResult(
        isApproved: false,
        highestConfidence: 0.0,
        bestClass: null,
        detections: [],
        summaryMessage:
            'No temple or heritage elements detected in this image. '
            'Please upload a clear photo of a temple, lingam, nandhi, or related structure.',
        imageWidth: origWidth,
        imageHeight: origHeight,
        processingTimeMs: processingTimeMs,
        quality: quality,
      );
    }

    final best = detections.first;
    final classNames = detections.map((d) => d.className).toSet().toList();

    return TempleDetectionResult(
      isApproved: true,
      highestConfidence: best.confidence,
      bestClass: best.className,
      detections: detections,
      summaryMessage: 'Detected ${detections.length} heritage element(s): '
          '${classNames.join(", ")}. '
          'Highest confidence: ${best.confidencePercent} (${best.className}).',
      imageWidth: origWidth,
      imageHeight: origHeight,
      processingTimeMs: processingTimeMs,
      quality: quality,
    );
  }

  /// Release model resources
  void dispose() {
    _isLoaded = false;
  }
}

