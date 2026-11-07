import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Colour treatments of the SENSE mark. All share one geometry.
enum SenseLogoVariant {
  /// Rounded-square gradient tile with a white mark (app icon, splash, headers).
  badge,

  /// Ocean Blue mark with an Electric Blue centre node, for light surfaces.
  onLight,

  /// White mark with a Soft Cyan centre node, for navy surfaces.
  onDark,

  /// One colour throughout ([SenseLogoMark.color], default Navy).
  mono,
}

/// The SENSE symbol: a geometric "S" made of two signal paths that meet at a
/// central node, with a node at each end ("networked signals converging on
/// one person").
///
/// Geometry mirrors `tool/generate_brand_assets.py`, which writes the SVG
/// source files in `assets/branding/` and the web icons. Keep them in sync.
///
/// The mark is decorative: screens show the "SENSE" wordmark as real text, so
/// the mark is excluded from the semantics tree unless [semanticLabel] is set.
class SenseLogoMark extends StatelessWidget {
  final double size;
  final SenseLogoVariant variant;
  final Color? color;
  final String? semanticLabel;

  const SenseLogoMark({
    super.key,
    this.size = 40,
    this.variant = SenseLogoVariant.badge,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      size: Size.square(size),
      painter: _SenseMarkPainter(variant: variant, monoColor: color ?? SenseColors.navy900),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: painted);
    return Semantics(image: true, label: semanticLabel, child: painted);
  }
}

/// Primary horizontal lockup: badge + "SENSE" wordmark (Poppins SemiBold).
/// The wordmark is real text, so it scales with the user's text settings.
class SenseLogo extends StatelessWidget {
  final double markSize;
  final Color wordmarkColor;
  final double fontSize;

  const SenseLogo({
    super.key,
    this.markSize = 36,
    this.wordmarkColor = SenseColors.navy900,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SenseLogoMark(size: markSize),
        SizedBox(width: markSize * 0.28),
        Flexible(
          child: Text(
            'SENSE',
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: SenseTypography.labelBold.copyWith(
              fontSize: fontSize,
              letterSpacing: fontSize * 0.1,
              color: wordmarkColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Geometry (100 x 100 design box; see generate_brand_assets.py) ---------
const double _r = 15.5;
const Offset _c1 = Offset(50, 34.5);
const Offset _c2 = Offset(50, 65.5);
const double _startDeg = -15;
const double _endDeg = 165;
const double _stroke = 9;
const double _terminalR = 7;
const double _centreR = 8.5;
const double _centreGap = 3;
const double _badgeMarkScale = 0.84;
const double _badgeRadius = 22;

/// Gradient midpoint of the badge tile, used for the centre-node ring.
const Color _badgeRingColor = SenseColors.blue700;

class _SenseMarkPainter extends CustomPainter {
  final SenseLogoVariant variant;
  final Color monoColor;

  _SenseMarkPainter({required this.variant, required this.monoColor});

  static Offset _pt(Offset c, double deg) {
    final a = deg * math.pi / 180;
    return Offset(c.dx + _r * math.cos(a), c.dy + _r * math.sin(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  void _paintMark(Canvas canvas, Color stroke, Color centre, Color? gap) {
    final start = _pt(_c1, _startDeg);
    final end = _pt(_c2, _endDeg);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      // Upper arc: anticlockwise over the top to the centre node.
      ..arcTo(Rect.fromCircle(center: _c1, radius: _r), _rad(_startDeg), _rad(-255), false)
      // Lower arc: clockwise round the bottom to the lower terminal.
      ..arcTo(Rect.fromCircle(center: _c2, radius: _r), _rad(-90), _rad(255), false);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    final fill = Paint()..color = stroke;
    canvas.drawCircle(start, _terminalR, fill);
    canvas.drawCircle(end, _terminalR, fill);
    if (gap != null) {
      canvas.drawCircle(const Offset(50, 50), _centreR + _centreGap, Paint()..color = gap);
    }
    canvas.drawCircle(const Offset(50, 50), _centreR, Paint()..color = centre);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (variant) {
      case SenseLogoVariant.badge:
        final tile = RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(_badgeRadius));
        canvas.drawRRect(
          tile,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [SenseColors.blue600, SenseColors.blue800],
            ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
        );
        const t = 50 * (1 - _badgeMarkScale);
        canvas.translate(t, t);
        canvas.scale(_badgeMarkScale);
        _paintMark(canvas, SenseColors.white, SenseColors.cyan300, _badgeRingColor);
      case SenseLogoVariant.onLight:
        _paintMark(canvas, SenseColors.blue800, SenseColors.blue600, SenseColors.white);
      case SenseLogoVariant.onDark:
        _paintMark(canvas, SenseColors.white, SenseColors.cyan300, SenseColors.navy900);
      case SenseLogoVariant.mono:
        _paintMark(canvas, monoColor, monoColor, null);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SenseMarkPainter old) =>
      old.variant != variant || old.monoColor != monoColor;
}
