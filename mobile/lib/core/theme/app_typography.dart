import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography system matching `Pushgard — Logo & App Icon.pdf`.
class AppTypography {
  // Bold Geometric Display Numbers & Headlines ("12,480", "Prop your phone side-on", "YOU WIN")
  static TextStyle heroTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: color,
      );

  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.15,
        color: color,
      );

  static TextStyle hudGiganticNumber({Color color = AppColors.volt}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 96,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.0,
        height: 0.92,
        color: color,
      );

  static TextStyle cardHeadline({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: color,
      );

  // Wide-tracked uppercase labels ("E G O  R A N K I N G", "G E T  R E A D Y", "B A T T L E  R E S U L T")
  static TextStyle trackedLabel({
    Color color = AppColors.volt,
    double fontSize = 12,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.2,
        color: color,
      );

  // Wordmark ("PUSHGARD" in PDF Page 1 & Page 3)
  static TextStyle brandWordmark({
    Color color = AppColors.textPrimary,
    double fontSize = 22,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
        color: color,
      );

  static TextStyle telemetryCode({
    Color color = AppColors.textSecondary,
    double fontSize = 11,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      );

  static TextStyle telemetryValue({
    Color color = AppColors.textPrimary,
    double fontSize = 14,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: color,
      );

  static TextStyle hudTimer({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.0,
        color: color,
      );

  static TextStyle body({
    Color color = AppColors.textSecondary,
    double fontSize = 14,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyBold({
    Color color = AppColors.textPrimary,
    double fontSize = 14,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle tacticalBadge({Color color = AppColors.volt}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: color,
      );
}
