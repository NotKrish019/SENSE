import 'package:flutter/material.dart';

/// SENSE "Restorative Nature / Illustrated Journal" design tokens.
///
/// PROTOTYPE (redesign stage 3). Used only by the Home preview
/// (`lib/main_redesign_preview.dart`); the live app still uses
/// `core/theme/`. Values and contrast ratios are documented in
/// `docs/sense_visual_redesign.md` and asserted in
/// `test/redesign_home_preview_test.dart`.
class NatureColors {
  NatureColors._();

  // ---- Palette (sampled from and tuned against the reference images) ------
  static const Color parchment = Color(0xFFF3EBDD); // app background
  static const Color paper = Color(0xFFFAF7EF); // primary surfaces
  static const Color paleSage = Color(0xFFDFE7D9); // quiet secondary panels
  static const Color eucalyptus = Color(0xFFA8BDB0); // illustration: far hills
  static const Color meadow = Color(0xFF7FA08A); // illustration: middle hills
  static const Color skyTeal = Color(0xFF78AAA5); // illustration accent
  static const Color sky = Color(0xFFDCE7E1); // illustration: sky wash
  static const Color forest = Color(0xFF3F6556); // primary actions
  static const Color forestDeep = Color(0xFF2F5245); // pressed / strong accent
  static const Color sunOchre = Color(0xFFE5AE56); // illustration highlight
  static const Color dustyCoral = Color(0xFFD88D83); // illustration warmth
  static const Color riverBlue = Color(0xFF789EA5); // illustration water
  static const Color ink = Color(0xFF293A35); // primary text
  static const Color inkMuted = Color(0xFF5A685F); // secondary text (was #64736A: 4.2:1)
  static const Color cream = Color(0xFFF7EEDC); // illustration: clouds
  static const Color mistRange = Color(0xFFC6D5CC); // illustration: distant hills
  static const Color skyHigh = Color(0xFFCFE1DB); // illustration: upper sky
  static const Color skyHorizon = Color(0xFFF1E7D4); // illustration: warm horizon haze
  static const Color sunGlow = Color(0xFFF0C985); // illustration: sun rays and halo
  static const Color sunlitRock = Color(0xFFD9AE98); // illustration: sunlit mountain faces
  static const Color pineMid = Color(0xFF5B7F6C); // illustration: middle-distance pines

  // Text-safe variants of the accent hues (>= 4.5:1 on parchment and paper).
  static const Color ochreInk = Color(0xFF8A5B14);
  static const Color coralInk = Color(0xFF9A4A3F);
  static const Color skyInk = Color(0xFF3E6E6A);

  // ---- Semantic tokens ------------------------------------------------------
  static const Color background = parchment;
  static const Color surface = paper;
  static const Color surfaceQuiet = paleSage;
  static const Color primary = forest;
  static const Color primaryForeground = paper; // 6.1:1 on forest
  static const Color textPrimary = ink; // 10.1:1 on parchment
  static const Color textSecondary = inkMuted; // 4.95:1 on parchment
  static const Color border = Color(0xFFD8CCB6); // decorative hairlines only
  static const Color borderStrong = Color(0xFF8C7F69); // control outlines, >= 3:1
  static const Color divider = Color(0xFFE2D8C6);
  static const Color focus = ink; // focus ring, 10:1 on parchment
  static const Color success = forest;
  static const Color warning = ochreInk;
  static const Color error = coralInk;
}

/// Radii: small for controls, medium for surfaces, a single large radius for
/// illustrated panels. Not everything is a pill.
class NatureRadii {
  NatureRadii._();
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 22;
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
}

/// Layout breakpoints (logical px).
class NatureBreakpoints {
  NatureBreakpoints._();
  static const double tablet = 600; // content column narrows and centres
  static const double desktop = 1024; // two columns, top navigation
  static const double maxContent = 1200;
  static const double maxReading = 640;
}

/// Motion: slow, ambient, and switched off when the platform asks for
/// reduced motion (MediaQuery.disableAnimations).
class NatureMotion {
  NatureMotion._();
  static const Duration ambientCycle = Duration(seconds: 60);
  static const Duration selection = Duration(milliseconds: 180);
  static const Duration press = Duration(milliseconds: 110);
  static const Curve ease = Curves.easeOutCubic;
}

/// Spacing scale (4 dp base), as in design.md.
class NatureSpace {
  NatureSpace._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 40;
  static const double gutter = 20;
}

/// Type scale: Poppins, lighter and calmer than the current UI (no heavy
/// display weights, sentence case, no extra letter spacing).
class NatureType {
  NatureType._();
  static const String family = 'Poppins';

  static const TextStyle greeting = TextStyle(
      fontFamily: family, fontSize: 26, height: 1.25, fontWeight: FontWeight.w500,
      color: NatureColors.textPrimary, letterSpacing: -0.2);
  static const TextStyle sectionTitle = TextStyle(
      fontFamily: family, fontSize: 18, height: 1.35, fontWeight: FontWeight.w600,
      color: NatureColors.textPrimary);
  static const TextStyle statusTitle = TextStyle(
      fontFamily: family, fontSize: 21, height: 1.3, fontWeight: FontWeight.w500,
      color: NatureColors.textPrimary);
  static const TextStyle body = TextStyle(
      fontFamily: family, fontSize: 15, height: 1.55, fontWeight: FontWeight.w400,
      color: NatureColors.textPrimary);
  static const TextStyle bodyMuted = TextStyle(
      fontFamily: family, fontSize: 14, height: 1.5, fontWeight: FontWeight.w400,
      color: NatureColors.textSecondary);
  static const TextStyle label = TextStyle(
      fontFamily: family, fontSize: 15, height: 1.35, fontWeight: FontWeight.w500,
      color: NatureColors.textPrimary);
  static const TextStyle eyebrow = TextStyle(
      fontFamily: family, fontSize: 13, height: 1.3, fontWeight: FontWeight.w500,
      color: NatureColors.skyInk);
  static const TextStyle button = TextStyle(
      fontFamily: family, fontSize: 16, height: 1.3, fontWeight: FontWeight.w500,
      color: NatureColors.primaryForeground);
  static const TextStyle link = TextStyle(
      fontFamily: family, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500,
      color: NatureColors.forest, decoration: TextDecoration.underline,
      decorationColor: NatureColors.forest);
}
