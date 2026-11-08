// Living Landscapes design system: PRODUCTION code (Phase 3).
//
// Three static landscape bands for the manual-entry screens, so each has its
// own place in the same world:
// * OrchardBand (Journal): a quiet morning, one broad folk-art tree on a low
//   rise, a few birds and a river drawn like a single line of handwriting;
// * DuskBand (Sleep): the last light of the evening, a crescent moon, a few
//   stars and dark layered hills with one lit window;
// * TerraceBand (Workload): a sunlit hillside cut into terraces with a
//   small cairn of balanced stones at the top.
// Original artwork drawn in code; decorative (excluded from semantics); no
// animation, so nothing changes with reduced motion.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';

Widget _band(CustomPainter painter) => ExcludeSemantics(
      child: RepaintBoundary(child: CustomPaint(painter: painter, size: Size.infinite)),
    );

/// Tears the bottom edge of a band into the page colour (desktop).
void _tear(Canvas canvas, Size size, int seed) {
  final w = size.width, h = size.height;
  final r = math.Random(seed);
  final edge = Path()..moveTo(0, h);
  for (var x = 0.0; x <= w; x += 6) {
    edge.lineTo(x, h - 12 + r.nextDouble() * 6 + math.sin(x / 41) * 2.5);
  }
  edge
    ..lineTo(w, h)
    ..close();
  canvas.drawShadow(edge, NatureColors.ink, 5, false);
  canvas.drawPath(edge, Paint()..color = NatureColors.background);
}

/// A cut-paper ridge with a lit upper edge.
void _ridge(Canvas canvas, Size size,
    {required int seed,
    required double base,
    required double amp,
    required Color color,
    double step = 0.14,
    Color? edge,
    double from = 0,
    double to = 1}) {
  final w = size.width;
  final rnd = math.Random(seed);
  final x0 = w * from, x1 = w * to;
  final path = Path()..moveTo(x0, size.height);
  var prev = Offset(x0, base - amp * (0.4 + rnd.nextDouble() * 0.5));
  path.lineTo(prev.dx, prev.dy);
  for (var t = step; t <= 1.0001; t += step) {
    final x = x0 + (x1 - x0) * t;
    final y = base - amp * (0.3 + rnd.nextDouble() * 0.7);
    final mid = Offset((prev.dx + x) / 2, math.min(prev.dy, y) - amp * 0.14);
    path.quadraticBezierTo(mid.dx, mid.dy, x, y);
    prev = Offset(x, y);
  }
  path
    ..lineTo(x1, size.height)
    ..close();
  canvas.drawShadow(path, NatureColors.ink, 2, false);
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge ?? NatureColors.paper.withValues(alpha: 0.35));
}

// ---- Journal: morning orchard ------------------------------------------------------
class OrchardBand extends StatelessWidget {
  final bool tornBottom;
  const OrchardBand({super.key, this.tornBottom = false});

  @override
  Widget build(BuildContext context) => _band(_OrchardPainter(tornBottom));
}

class _OrchardPainter extends CustomPainter {
  final bool tornBottom;
  const _OrchardPainter(this.tornBottom);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = h * (tornBottom ? 0.7 : 0.66);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NatureColors.skyHorizon, NatureColors.cream],
          ).createShader(Offset.zero & size));

    // Pale morning sun behind the tree's crown.
    final sun = Offset(w * 0.2, ground - h * 0.32);
    final r = math.min(h * 0.09, 26.0);
    canvas.drawCircle(sun, r * 2.2, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.25));
    canvas.drawCircle(sun + const Offset(1.5, 1.5), r, Paint()..color = NatureColors.sunGlow);
    canvas.drawCircle(
        sun,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = NatureColors.ochreInk.withValues(alpha: 0.6));

    // Birds: small hand-drawn ticks.
    final bird = Paint()
      ..color = NatureColors.ink.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final rb = math.Random(2);
    for (var i = 0; i < 4; i++) {
      final c = Offset(w * (0.36 + i * 0.06 + rb.nextDouble() * 0.03), h * (0.16 + rb.nextDouble() * 0.16));
      final s = 4.5 + rb.nextDouble() * 2;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx - s, c.dy)
            ..quadraticBezierTo(c.dx - s * 0.4, c.dy - s * 0.7, c.dx, c.dy)
            ..quadraticBezierTo(c.dx + s * 0.4, c.dy - s * 0.7, c.dx + s, c.dy),
          bird);
    }

    _ridge(canvas, size, seed: 21, base: ground - h * 0.04, amp: h * 0.14, color: NatureColors.mistRange);
    _ridge(canvas, size, seed: 6, base: ground + 2, amp: h * 0.07, color: NatureColors.eucalyptus, step: 0.2);

    // The tree on a low rise, right of centre.
    final tx = w * (w > 900 ? 0.8 : 0.74);
    final rise = Path()
      ..moveTo(tx - w * 0.32, h)
      ..quadraticBezierTo(tx, ground - h * 0.1, tx + w * 0.34, h)
      ..close();
    canvas.drawShadow(rise, NatureColors.ink, 2, false);
    canvas.drawPath(rise, Paint()..color = NatureColors.meadow);
    final crownR = math.min(h * 0.26, 74.0);
    final crownC = Offset(tx, ground - h * 0.08 - crownR * 0.95);
    final trunk = Paint()
      ..color = NatureColors.forestDeep
      ..strokeWidth = math.max(3, crownR * 0.1)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(tx, ground - h * 0.06), Offset(tx, crownC.dy + crownR * 0.2), trunk);
    canvas.drawCircle(crownC + const Offset(2.5, 2.5), crownR, Paint()..color = NatureColors.sunOchre.withValues(alpha: 0.55));
    canvas.drawCircle(crownC, crownR, Paint()..color = NatureColors.pineMid);
    // Folk-art leaf pattern carved into the crown.
    final leaf = Paint()
      ..color = NatureColors.paper.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var ring = 1; ring <= 2; ring++) {
      final rr = crownR * (0.34 * ring);
      final n = 6 * ring;
      for (var i = 0; i < n; i++) {
        final a = i / n * math.pi * 2 + ring * 0.3;
        final p = crownC + Offset(math.cos(a), math.sin(a)) * rr;
        final d = Offset(math.cos(a), math.sin(a)) * (crownR * 0.1);
        canvas.drawLine(p - d, p + d, leaf);
      }
    }
    // A few fruits.
    final fruit = Paint()..color = NatureColors.dustyCoral;
    final rf = math.Random(4);
    for (var i = 0; i < 6; i++) {
      final a = rf.nextDouble() * math.pi * 2;
      final d = crownR * (0.25 + rf.nextDouble() * 0.6);
      canvas.drawCircle(crownC + Offset(math.cos(a), math.sin(a)) * d, math.max(2.2, crownR * 0.05), fruit);
    }

    // The river: one continuous, handwriting-like line across the foreground.
    final river = Paint()
      ..color = NatureColors.riverBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final rv = Path()..moveTo(-4, ground + h * 0.12);
    for (var x = 0.0; x <= w * 0.62; x += 22) {
      rv.relativeQuadraticBezierTo(8, -7 + math.sin(x / 60) * 3, 22, math.sin(x / 90) * 2);
    }
    canvas.drawPath(rv, river);

    if (tornBottom) _tear(canvas, size, 13);
  }

  @override
  bool shouldRepaint(_OrchardPainter old) => old.tornBottom != tornBottom;
}

// ---- Sleep: dusk ------------------------------------------------------------------
class DuskBand extends StatelessWidget {
  final bool tornBottom;
  final double moonX;
  const DuskBand({super.key, this.tornBottom = false, this.moonX = 0.78});

  @override
  Widget build(BuildContext context) => _band(_DuskPainter(tornBottom, moonX));
}

class _DuskPainter extends CustomPainter {
  final bool tornBottom;
  final double moonX;
  const _DuskPainter(this.tornBottom, this.moonX);

  // Evening tints of the approved palette (illustration only, never text).
  static const Color duskHigh = Color(0xFF2E4A49);
  static const Color duskMid = Color(0xFF5E8487);
  static const Color duskGlow = Color(0xFFE6C39A);
  static const Color farHill = Color(0xFF6F8C8A);
  static const Color midHill = Color(0xFF41605A);
  static const Color nearHill = Color(0xFF2B4740);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * (tornBottom ? 0.72 : 0.7);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [duskHigh, duskMid, duskGlow],
            stops: [0, 0.62, 1],
          ).createShader(Rect.fromLTWH(0, 0, w, horizon)));

    // Stars: dots and a few four-point sparkles, upper sky only.
    final rs = math.Random(17);
    final star = Paint()..color = NatureColors.cream.withValues(alpha: 0.85);
    for (var i = 0; i < (w / 22).clamp(12, 48).round(); i++) {
      final p = Offset(rs.nextDouble() * w, rs.nextDouble() * horizon * 0.5);
      if (i % 7 == 0) {
        final s = 3.0 + rs.nextDouble() * 2;
        final sparkle = Paint()
          ..color = NatureColors.cream
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p - Offset(s, 0), p + Offset(s, 0), sparkle);
        canvas.drawLine(p - Offset(0, s), p + Offset(0, s), sparkle);
      } else {
        canvas.drawCircle(p, 0.8 + rs.nextDouble() * 0.9, star);
      }
    }

    // Crescent moon with an off-register ochre plate.
    final mr = math.min(h * 0.1, 28.0);
    final mc = Offset(w * moonX, horizon * (tornBottom ? 0.36 : 0.32));
    Path crescent(Offset c) => Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: mr)),
          Path()..addOval(Rect.fromCircle(center: c + Offset(mr * 0.48, -mr * 0.18), radius: mr * 0.86)),
        );
    canvas.drawCircle(mc, mr * 2.4, Paint()..color = NatureColors.cream.withValues(alpha: 0.07));
    canvas.drawPath(crescent(mc + const Offset(1.6, 1.6)), Paint()..color = NatureColors.sunOchre.withValues(alpha: 0.7));
    canvas.drawPath(crescent(mc), Paint()..color = NatureColors.cream);

    // Hills: the last light catches their edges.
    final lit = duskGlow.withValues(alpha: 0.45);
    _ridge(canvas, size, seed: 31, base: horizon - h * 0.02, amp: h * 0.16, color: farHill, edge: lit, step: 0.12);
    _ridge(canvas, size, seed: 8, base: horizon + h * 0.06, amp: h * 0.1, color: midHill, edge: lit, step: 0.18);
    _ridge(canvas, size, seed: 40, base: horizon + h * 0.16, amp: h * 0.08, color: nearHill, edge: lit, step: 0.25);

    // One small house on the near hill with a lit window.
    final hx = w * (1 - moonX) * 0.9 + 18;
    final hy = horizon + h * 0.12;
    final hs = math.min(h * 0.07, 18.0);
    final house = Path()
      ..moveTo(hx - hs, hy)
      ..lineTo(hx - hs, hy - hs)
      ..lineTo(hx, hy - hs * 1.8)
      ..lineTo(hx + hs, hy - hs)
      ..lineTo(hx + hs, hy)
      ..close();
    canvas.drawPath(house, Paint()..color = const Color(0xFF223A34));
    canvas.drawRect(Rect.fromLTWH(hx - hs * 0.32, hy - hs * 0.8, hs * 0.64, hs * 0.5),
        Paint()..color = NatureColors.sunGlow);
    canvas.drawCircle(Offset(hx, hy - hs * 0.55), hs * 1.4, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.12));

    if (tornBottom) _tear(canvas, size, 19);
  }

  @override
  bool shouldRepaint(_DuskPainter old) => old.tornBottom != tornBottom || old.moonX != moonX;
}

// ---- Workload: terraces -------------------------------------------------------------
class TerraceBand extends StatelessWidget {
  final bool tornBottom;
  const TerraceBand({super.key, this.tornBottom = false});

  @override
  Widget build(BuildContext context) => _band(_TerracePainter(tornBottom));
}

class _TerracePainter extends CustomPainter {
  final bool tornBottom;
  const _TerracePainter(this.tornBottom);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NatureColors.skyHigh, NatureColors.skyHorizon],
          ).createShader(Offset.zero & size));

    // Sun high on the left.
    final sun = Offset(w * 0.14, h * 0.24);
    final r = math.min(h * 0.09, 26.0);
    canvas.drawCircle(sun, r * 2.3, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.3));
    canvas.drawCircle(sun + const Offset(1.5, 1.5), r, Paint()..color = NatureColors.sunOchre);
    canvas.drawCircle(
        sun,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = NatureColors.ochreInk.withValues(alpha: 0.7));

    _ridge(canvas, size, seed: 12, base: h * 0.52, amp: h * 0.16, color: NatureColors.mistRange, step: 0.12);

    // The terraced hill: stacked contour bands from the right, rising.
    final colors = [
      NatureColors.meadow,
      const Color(0xFFB9C79A), // young-rice green (illustration only)
      NatureColors.eucalyptus,
      const Color(0xFFD8C08A), // ripening terrace (illustration only)
      NatureColors.meadow,
      const Color(0xFFB9C79A),
    ];
    final edge = Paint()
      ..color = NatureColors.forest.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final top = h * (tornBottom ? 0.3 : 0.34);
    final n = colors.length;
    final terraceTops = <double>[];
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final y = top + (h - top) * t;
      terraceTops.add(y);
      final left = w * (0.42 - t * 0.5);
      final p = Path()..moveTo(left, h);
      p.lineTo(left, y + 12);
      p.quadraticBezierTo(left + w * 0.1, y - 2, left + w * 0.3, y + 2);
      p.quadraticBezierTo(w * 0.75, y + 7 + math.sin(i * 1.7) * 4, w + 4, y - 2);
      p
        ..lineTo(w + 4, h)
        ..close();
      canvas.drawShadow(p, NatureColors.ink, 1.5, false);
      canvas.drawPath(p, Paint()..color = colors[i]);
      // Retaining-wall edge and a few planting rows.
      canvas.drawPath(
          Path()
            ..moveTo(left, y + 12)
            ..quadraticBezierTo(left + w * 0.1, y - 2, left + w * 0.3, y + 2)
            ..quadraticBezierTo(w * 0.75, y + 7 + math.sin(i * 1.7) * 4, w + 4, y - 2),
          edge);
      final row = Paint()
        ..color = NatureColors.forest.withValues(alpha: 0.18)
        ..strokeWidth = 1;
      final band = (h - top) / n;
      for (var k = 1; k <= 2; k++) {
        final ry = y + band * k / 3 + 6;
        if (ry > h) break;
        canvas.drawLine(Offset(left + 14, ry), Offset(w, ry - 3), row);
      }
    }

    // A cairn of balanced stones on the top terrace.
    final cx = w * 0.84, cy = terraceTops.first + 4;
    final stone = Paint()..color = NatureColors.borderStrong;
    final stoneEdge = Paint()
      ..color = NatureColors.ink.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final sizes = [15.0, 12.0, 9.0, 6.0];
    var y = cy;
    for (var i = 0; i < sizes.length; i++) {
      final s = sizes[i] * math.min(1.0, h / 220);
      final rect = Rect.fromCenter(center: Offset(cx + (i.isEven ? 0 : 1.5), y - s * 0.45), width: s * 2, height: s * 0.9);
      canvas.drawOval(rect.shift(const Offset(1.2, 1.2)), Paint()..color = NatureColors.sunOchre.withValues(alpha: 0.6));
      canvas.drawOval(rect, stone);
      canvas.drawOval(rect, stoneEdge);
      y -= s * 0.88;
    }

    if (tornBottom) _tear(canvas, size, 23);
  }

  @override
  bool shouldRepaint(_TerracePainter old) => old.tornBottom != tornBottom;
}
