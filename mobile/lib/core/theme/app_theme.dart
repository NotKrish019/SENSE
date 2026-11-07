import 'package:flutter/material.dart';
import 'sense_colors.dart';
import 'sense_typography.dart';
import 'sense_spacing.dart';

export 'sense_colors.dart';
export 'sense_typography.dart';
export 'sense_spacing.dart';
export 'sense_shadows.dart';

/// Central Material 3 Theme definition for SENSE.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: SenseTypography.fontFamily,
      fontFamilyFallback: SenseTypography.fontFallbacks,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: SenseColors.blue600,
        onPrimary: SenseColors.white,
        secondary: SenseColors.blue800,
        onSecondary: SenseColors.white,
        tertiary: SenseColors.cyan500,
        onTertiary: SenseColors.navy900,
        error: SenseColors.danger,
        onError: SenseColors.white,
        surface: SenseColors.surface,
        onSurface: SenseColors.textPrimary,
        outline: SenseColors.border,
      ),
      scaffoldBackgroundColor: SenseColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SenseColors.navy900,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: SenseTypography.h3.copyWith(
          color: SenseColors.navy900,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(
          color: SenseColors.navy900,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: SenseColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SenseRadii.lgBorder,
          side: const BorderSide(color: SenseColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SenseColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: SenseRadii.mdBorder,
          borderSide: const BorderSide(color: SenseColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SenseRadii.mdBorder,
          borderSide: const BorderSide(color: SenseColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SenseRadii.mdBorder,
          borderSide: const BorderSide(color: SenseColors.blue600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: SenseRadii.mdBorder,
          borderSide: const BorderSide(color: SenseColors.danger, width: 1.5),
        ),
        hintStyle: SenseTypography.bodySecondary.copyWith(color: SenseColors.textMuted),
        labelStyle: SenseTypography.label,
      ),
    );
  }
}
