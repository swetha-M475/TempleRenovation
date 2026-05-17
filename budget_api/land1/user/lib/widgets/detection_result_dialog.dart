import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/temple_detection_result.dart';
import 'detection_painter.dart';

/// Bottom sheet that displays temple object detection results for a single image.
///
/// Shows:
/// - The image with bounding boxes drawn via [DetectionPainter]
/// - List of detected objects with confidence percentages
/// - Approval or rejection status
/// - Accept or retry button
class DetectionResultDialog extends StatelessWidget {
  final String imagePath;
  final TempleDetectionResult result;

  const DetectionResultDialog({
    super.key,
    required this.imagePath,
    required this.result,
  });

  // Theme colors (consistent with CreateProjectScreen)
  static const Color _bgTop = Color(0xFFFFFDF5);
  static const Color _primary = Color(0xFF5D4037);
  static const Color _textDark = Color(0xFF3E2723);
  static const Color _textMid = Color(0xFF8D6E63);
  static const Color _cardBg = Color(0xFFEFE6D5);
  static const Color _approvedGreen = Color(0xFF2D6A4F);
  static const Color _rejectedRed = Color(0xFFC0392B);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: _bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    color: _primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temple Detection',
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    Text(
                      '${result.processingTimeMs}ms • ${result.detectionCount} detection(s)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _textMid,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Image with bounding boxes
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildImageWithDetections(),
                  const SizedBox(height: 16),
                  _buildDetectionsList(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  _buildQualityWarnings(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Action buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  /// Image with bounding box overlay
  Widget _buildImageWithDetections() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: result.isApproved
                ? _approvedGreen.withOpacity(0.5)
                : _rejectedRed.withOpacity(0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Base image
                  Image.file(
                    File(imagePath),
                    width: constraints.maxWidth,
                    fit: BoxFit.fitWidth,
                  ),

                  // Bounding boxes overlay
                  if (result.detections.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DetectionPainter(
                          detections: result.detections,
                          imageWidth: result.imageWidth,
                          imageHeight: result.imageHeight,
                        ),
                      ),
                    ),

                  // Approval badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: result.isApproved
                            ? _approvedGreen
                            : _rejectedRed,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            result.isApproved
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            result.isApproved ? 'APPROVED' : 'REJECTED',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// List of detected objects with confidence bars
  Widget _buildDetectionsList() {
    if (result.detections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _rejectedRed.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _rejectedRed.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, color: _rejectedRed, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No heritage elements detected',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _rejectedRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detected Elements',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        ...result.detections.map((det) => _buildDetectionTile(det)),
      ],
    );
  }

  /// Single detection tile with confidence bar
  Widget _buildDetectionTile(DetectedObject det) {
    final color =
        DetectionPainter.classColors[det.className] ?? const Color(0xFFBDC3C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Class name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  det.className,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                if (det.className != det.rawClassName)
                  Text(
                    det.rawClassName,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _textMid,
                    ),
                  ),
              ],
            ),
          ),

          // Confidence bar + percentage
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: det.confidence,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  det.confidencePercent,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Status card with summary message
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: result.isApproved
            ? _approvedGreen.withOpacity(0.08)
            : _rejectedRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isApproved
              ? _approvedGreen.withOpacity(0.3)
              : _rejectedRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.isApproved
                ? Icons.verified_rounded
                : Icons.info_outline_rounded,
            color: result.isApproved ? _approvedGreen : _rejectedRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.summaryMessage,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: result.isApproved ? _approvedGreen : _rejectedRed,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// List of quality warnings and extra domain insights
  Widget _buildQualityWarnings() {
    final warnings = result.quality?.warnings ?? [];
    final orientation = result.orientation;
    final domainInterp = result.domainInterpretation;
    
    if (warnings.isEmpty && orientation == null && domainInterp == null) return const SizedBox.shrink();

    return Column(
      children: [
        ...warnings.map((warning) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    warning,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        // Advanced Insights
        if (orientation != null || domainInterp != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Advanced AI Insights",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (orientation != null)
                  Text("• Orientation: ${orientation[0].toUpperCase()}${orientation.substring(1)}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900)),
                if (domainInterp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("• Architecture: $domainInterp", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Action buttons at the bottom
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _cardBg)),
      ),
      child: result.isApproved
          ? SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                  'Accept & Add Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _approvedGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                  'Try Another Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rejectedRed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
    );
  }
}
