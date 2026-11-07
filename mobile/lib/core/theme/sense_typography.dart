import 'package:flutter/material.dart';
import 'sense_colors.dart';

/// Authoritative SENSE Typography Scale from design.md & UI Toolkit Board.
///
/// Poppins is bundled with the app (pubspec.yaml, weights 400/500/600/700/800;
/// SIL Open Font License), so it never depends on a network download. The
/// fallbacks only apply to glyphs Poppins lacks (e.g. emoji) or if the asset
/// fails to load.
class SenseTypography {
  static const String fontFamily = 'Poppins';
  static const List<String> fontFallbacks = [
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static TextStyle get display => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: SenseColors.navy900,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static TextStyle get h1 => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: SenseColors.navy900,
    letterSpacing: -0.4,
    height: 1.3,
  );

  static TextStyle get h2 => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: SenseColors.navy900,
    letterSpacing: -0.3,
    height: 1.35,
  );

  static TextStyle get h3 => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: SenseColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: SenseColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get body => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SenseColors.textPrimary,
    height: 1.45,
  );

  static TextStyle get bodySecondary => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SenseColors.textSecondary,
    height: 1.45,
  );

  static TextStyle get label => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: SenseColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get labelBold => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: SenseColors.navy900,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get caption => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: SenseColors.textMuted,
    height: 1.35,
  );

  static TextStyle get captionMedium => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: SenseColors.textSecondary,
    height: 1.35,
  );

  static TextStyle get buttonLabel => const TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: SenseColors.white,
    letterSpacing: 0.2,
  );
}

