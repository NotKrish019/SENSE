// Living Landscapes design system: PRODUCTION code (Phase 2).
//
// A quiet, static landscape band for reading pages (Insights, Insight
// detail, Profile): layered meadow ridges engraved with contour lines, a low
// sun, a few pines and, optionally, a path winding into the hills. Original
// artwork drawn in code; decorative (excluded from semantics).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';

class MeadowBand extends StatelessWidget {
  /// Shapes the ridges, so each page has its own (stable) horizon.
  final int seed;

  /// Horizontal position of the sun (fraction of the width).
  final double sunX;

  /// Engraved contour lines on the ridges (Insights: a nod to change over time).
  final bool contours;

  /// A pale path winding into the hills (Profile).
  final bool path;

  /// Tear the bottom edge into the page colour (desktop, where the band meets
  /// bare page).
  final bool tornBottom;

  const MeadowBand({
    super.key,
    this.seed = 3,
    this.sunX = 0.74,
    this.contours = true,
    this.path = false,
    this.tornBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MeadowPainter(seed, sunX, contours, path, tornBottom),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  final int seed;
  final double sunX;
  final bool contours;
  final bool path;
  final bool tornBottom;
  const _MeadowPainter(this.seed, this.sunX, this.contours, this.path, this.tornBottom);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Sky, warming towards the horizon.
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NatureColors.skyHigh, NatureColors.skyHorizon],
          ).createShader(rect));

    // Low sun with a soft halo and an off-register plate.
    final r = math.min(h * 0.1, 28.0);
    final sun = Offset(w * sunX, h * (tornBottom ? 0.3 : 0.36));
    canvas.drawCircle(sun, r * 2.5, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.26));
    canvas.drawCircle(sun, r * 1.6, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.36));
    canvas.drawCircle(sun + const Offset(1.5, 1.5), r, Paint()..color = NatureColors.sunOchre);
    canvas.drawCircle(
        sun,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = NatureColors.ochreInk.withValues(alpha: 0.7));

    // Three ridges, far to near, each a cut-paper plane with a lit edge.
    final layers = [
      (base: h * 0.62, amp: h * 0.2, color: NatureColors.mistRange, step: 0.09),
      (base: h * 0.78, amp: h * 0.16, color: NatureColors.eucalyptus, step: 0.12),
      (base: h * 0.95, amp: h * 0.13, color: NatureColors.meadow, step: 0.16),
    ];
    Path? near;
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      final ridge = _ridge(size, seed * 7 + i * 13, l.base, l.amp, l.step);
      canvas.drawShadow(ridge, NatureColors.ink, 2.5, false);
      canvas.drawPath(ridge, Paint()..color = l.color);
      canvas.drawPath(
          ridge,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = NatureColors.paper.withValues(alpha: 0.4));
      if (contours) {
        // Engraved contour lines following the ridge line, clipped to it.
        canvas.save();
        canvas.clipPath(ridge);
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = NatureColors.paper.withValues(alpha: i == 2 ? 0.22 : 0.3);
        for (var k = 1; k <= 4; k++) {
          canvas.drawPath(ridge.shift(Offset(0, k * (5.5 + i * 1.5))), line);
        }
        canvas.restore();
      }
      if (i == 2) near = ridge;
    }

    final rnd = math.Random(seed);
    // A few pines on the near ridge.
    final pine = Paint()..color = NatureColors.forest;
    for (var k = 0; k < 6; k++) {
      final x = w * (0.04 + rnd.nextDouble() * 0.28) + (k > 2 ? w * 0.6 : 0);
      final base = _ridgeY(size, seed * 7 + 2 * 13, layers[2].base, layers[2].amp, layers[2].step, x) + 3;
      final ph = 14 + rnd.nextDouble() * 14;
      canvas.drawPath(
          Path()
            ..moveTo(x, base - ph)
            ..lineTo(x + ph * 0.32, base)
            ..lineTo(x - ph * 0.32, base)
            ..close(),
          pine);
    }

    if (path && near != null) {
      // A pale path from the bottom edge winding up into the hills.
      final p = Path()
        ..moveTo(w * 0.5 - 18, h)
        ..quadraticBezierTo(w * 0.42, h * 0.9, w * 0.52, h * 0.82)
        ..quadraticBezierTo(w * 0.6, h * 0.76, w * 0.56, h * 0.7)
        ..lineTo(w * 0.565, h * 0.7)
        ..quadraticBezierTo(w * 0.62, h * 0.77, w * 0.55, h * 0.83)
        ..quadraticBezierTo(w * 0.47, h * 0.9, w * 0.5 + 18, h)
        ..close();
      canvas.save();
      canvas.clipPath(near);
      canvas.drawPath(p, Paint()..color = NatureColors.skyHorizon);
      canvas.restore();
    }

    if (tornBottom) {
      final tr = math.Random(8);
      final edge = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 6) {
        edge.lineTo(x, h - 12 + tr.nextDouble() * 6 + math.sin(x / 41) * 2.5);
      }
      edge
        ..lineTo(w, h)
        ..close();
      canvas.drawShadow(edge, NatureColors.ink, 5, false);
      canvas.drawPath(edge, Paint()..color = NatureColors.background);
    }
  }

  // Smooth ridge heights from a seeded random walk.
  List<double> _heights(int s, double step) {
    final rnd = math.Random(s);
    final n = (1 / step).ceil() + 2;
    return [for (var i = 0; i < n; i++) 0.35 + rnd.nextDouble() * 0.65];
  }

  double _ridgeY(Size size, int s, double base, double amp, double step, double x) {
    final hs = _heights(s, step);
    final t = (x / size.width) / step;
    final i = t.floor().clamp(0, hs.length - 2);
    final f = t - i;
    final e = f * f * (3 - 2 * f);
    return base - amp * (hs[i] + (hs[i + 1] - hs[i]) * e);
  }

  Path _ridge(Size size, int s, double base, double amp, double step) {
    final p = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 4; x += 4) {
      p.lineTo(x, _ridgeY(size, s, base, amp, step, x));
    }
    p
      ..lineTo(size.width, size.height)
      ..close();
    return p;
  }

  @override
  bool shouldRepaint(_MeadowPainter old) =>
      old.seed != seed ||
      old.sunX != sunX ||
      old.contours != contours ||
      old.path != path ||
      old.tornBottom != tornBottom;
}
