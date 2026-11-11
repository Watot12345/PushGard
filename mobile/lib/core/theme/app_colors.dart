import 'package:flutter/material.dart';

/// Official PushGard Brand Palette extracted from `Pushgard — Logo & App Icon.pdf`.
class AppColors {
  // Deep Carbon Black & Slate Card Surfaces (Pages 1–6 of PDF)
  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF1B1A26);
  static const Color surfaceElevated = Color(0xFF242333);
  static const Color border = Color(0xFF2C2B3C);
  static const Color borderHighlight = Color(0xFF3E3D52);

  // Official PushGard Shield & Primary Brand Accents (Pages 1–6 of PDF)
  static const Color volt = Color(0xFFD4FF2A);
  static const Color voltBright = Color(0xFFE0FF5C);
  static const Color voltOlive = Color(0xFF6E7F29); // Top chevron inside shield
  static const Color shieldCarbon = Color(0xFF101114); // Bottom chevron inside shield

  // Feedback & Status Accents (Page 4 of PDF: PASS in Volt, FIX in Coral Salmon)
  static const Color coralFix = Color(0xFFFF8A7A);

  // Semantic aliases used across screens & spike harness
  static const Color apexGold = Color(0xFFD4FF2A);
  static const Color apexGoldBright = Color(0xFFE0FF5C);
  static const Color apexGoldDark = Color(0xFF6E7F29);
  static const Color goldGlow = Color(0x33D4FF2A);

  static const Color crimson = Color(0xFFFF5C4D);
  static const Color crimsonBright = Color(0xFFFF8A7A);
  static const Color crimsonDark = Color(0xFF6E1E18);
  static const Color crimsonGlow = Color(0x33FF8A7A);

  static const Color telemetryCyan = Color(0xFFD4FF2A);
  static const Color telemetryGreen = Color(0xFFD4FF2A);
  static const Color telemetryWarning = Color(0xFFFF8A7A);
  static const Color telemetryHazard = Color(0xFFFF5C4D);

  // Typography (Pages 3–6 of PDF)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA09FB1);
  static const Color textMuted = Color(0xFF7C7B8E);
  static const Color textDim = Color(0xFF5A596B);
}
