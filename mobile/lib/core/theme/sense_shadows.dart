import 'package:flutter/material.dart';

/// Neumorphic Elevation & Dual Shadows from design.md.
class SenseShadows {
  // Soft ambient card shadow with subtle top-left light source
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14012F5F), // rgba(1, 47, 95, 0.08)
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0xBFFFFFFF), // rgba(255, 255, 255, 0.75) upper highlight
      offset: Offset(-2, -2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  // Stronger elevation for floating actions or interactive quick action tiles
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1F012F5F), // rgba(1, 47, 95, 0.12)
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0xD9FFFFFF),
      offset: Offset(-3, -3),
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];

  // Gentle inset/subdued treatment for inputs and selected states
  static const List<BoxShadow> recessed = [
    BoxShadow(
      color: Color(0x0F012F5F),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> none = [];
}

