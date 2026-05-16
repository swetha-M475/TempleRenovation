import 'package:flutter/material.dart';

class AppColors {
  // Core Colors
  static const Color primary = Color(0xFFE9E1F2); // Light lavender background
  static const Color secondary = Color(0xFF000000); // Black
  static const Color white = Color(0xFFFFFFFF);     // White
  static const Color greyDark = Color(0xFF222222);  // Dark grey
  static const Color greyLight = Color(0xFF888888); // Light grey
  
  // Accent Colors
  static const Color aqua = Color(0xFF9BF0E1);   // Aqua highlight
  static const Color pink = Color(0xFFF9C7E5);   // Soft pink
  static const Color mint = Color(0xFFB2F2E8);   // Mint tone
  
  // Gradient (pastel rainbow-like in first screen)
  static const Gradient gradient = LinearGradient(
    colors: [
      Color(0xFF9BF0E1), // Aqua
      Color(0xFFF9C7E5), // Pink
      Color(0xFFD4BFFF), // Soft purple
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // UI Specific
  static const Color cardBackground = Color(0xFFF5F5F7); // light background for cards
  static const Color success = Color(0xFF4CAF50);        // Green for success
  static const Color warning = Color(0xFFFFC107);        // Amber for warning
  static const Color error = Color(0xFFF44336);          // Red for error
}