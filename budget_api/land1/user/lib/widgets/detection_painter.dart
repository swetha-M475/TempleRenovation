import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/temple_detection_result.dart';

/// CustomPainter that draws bounding boxes and labels on detected objects.
///
/// Colors match the Python engine's CLASS_COLORS for visual consistency.
class DetectionPainter extends CustomPainter {
  final List<DetectedObject> detections;
  final int imageWidth;
  final int imageHeight;

  /// Color map matching the Python engine's CLASS_COLORS
  static const Map<String, Color> classColors = {
    'Lingam': Color(0xFF2ECC71),               // Green
    'Nandhi': Color(0xFF3498DB),               // Blue
    'Temple Structure': Color(0xFFFF8C00),     // Orange
    'Shed': Color(0xFFE6C619),                 // Yellow
    'Avudaiyar': Color(0xFF9B59B6),            // Purple
  };

  static const Color _defaultColor = Color(0xFFBDC3C7); // Grey

  DetectionPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    // Scale factors from original image coords to display coords
    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    for (final det in detections) {
      final color = classColors[det.className] ?? _defaultColor;
      final bbox = det.boundingBox;

      // Scale bounding box to display coordinates
      final displayRect = Rect.fromLTRB(
        bbox.left * scaleX,
        bbox.top * scaleY,
        bbox.right * scaleX,
        bbox.bottom * scaleY,
      );

      // Draw bounding box
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRect(displayRect, boxPaint);

      // Draw semi-transparent fill
      final fillPaint = Paint()
        ..color = color.withOpacity(0.10)
        ..style = PaintingStyle.fill;
      canvas.drawRect(displayRect, fillPaint);

      // Draw label background + text
      final label = '${det.className} ${det.confidencePercent}';
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      final labelWidth = textPainter.width + 10;
      final labelHeight = textPainter.height + 6;

      // Position label above the box, or inside if near top edge
      final labelY = displayRect.top > labelHeight
          ? displayRect.top - labelHeight
          : displayRect.top;

      // Label background
      final labelBgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(displayRect.left, labelY, labelWidth, labelHeight),
        const Radius.circular(4),
      );
      final labelBgPaint = Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(labelBgRect, labelBgPaint);

      // Label text
      textPainter.paint(
        canvas,
        Offset(displayRect.left + 5, labelY + 3),
      );

      // Draw corner markers for a polished look
      _drawCornerMarkers(canvas, displayRect, color);
    }
  }

  /// Draw small corner markers on the bounding box for a modern look.
  void _drawCornerMarkers(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const len = 12.0; // Length of corner marker

    // Top-left
    canvas.drawLine(rect.topLeft, Offset(rect.left + len, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + len), paint);

    // Top-right
    canvas.drawLine(rect.topRight, Offset(rect.right - len, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + len), paint);

    // Bottom-left
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + len, rect.bottom), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - len), paint);

    // Bottom-right
    canvas.drawLine(rect.bottomRight, Offset(rect.right - len, rect.bottom), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - len), paint);
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
