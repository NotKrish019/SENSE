import 'package:flutter/material.dart';

/// Authoritative SENSE Colour System from design.md & UI Toolkit Board.
class SenseColors {
  // Brand Foundation Palette
  static const Color navy900 = Color(0xFF012F5F);      // Primary text, headings, brand anchor
  static const Color blue800 = Color(0xFF02549B);      // Secondary brand blue, active nav, hero gradient
  static const Color blue600 = Color(0xFF059BE0);      // Primary action, links, chart series
  static const Color cyan500 = Color(0xFF07CCFC);      // Small highlights, focus accents, chart points
  static const Color cyan300 = Color(0xFF58E2F9);      // Soft decorative accents, secondary details

  // Canvas & Surfaces
  static const Color background = Color(0xFFE6F6FF);   // App canvas / cool icy blue
  static const Color surface = Color(0xFFF4F7F7);      // Main card and control surface
  static const Color white = Color(0xFFFFFFFF);        // Raised surfaces, inputs, high clarity
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF082B52);  // Primary headings & body on light background
  static const Color textSecondary = Color(0xFF496784);// Supporting text, section subtitles, labels
  static const Color textMuted = Color(0xFF607B93);    // Captions, timestamps, metadata
  static const Color textOnDark = Color(0xFFFFFFFF);   // White text on navy/blue hero panels

  // Borders & Separators
  static const Color border = Color(0xFFD6E7F2);       // Subtle card & input outlines
  static const Color borderFocused = Color(0xFF059BE0);// Active focus border

  // Semantic Status Colors
  static const Color success = Color(0xFF087F6E);      // Complete, positive trend, good status
  static const Color warning = Color(0xFF9A5B00);      // Caution, elevated stress indicator
  static const Color danger = Color(0xFFB42332);       // Crisis alert or error state only

  // Gradients
  static const LinearGradient primaryActionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059BE0), Color(0xFF02549B)],
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF02549B), Color(0xFF012F5F)],
  );

  static const LinearGradient cyanHighlightGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF07CCFC), Color(0xFF059BE0)],
  );

  static const LinearGradient chartAreaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x6607CCFC), Color(0x00E6F6FF)],
  );
}

