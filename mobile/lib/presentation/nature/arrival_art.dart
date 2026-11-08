// Living Landscapes design system: PRODUCTION code (Phase 5).
//
// Original artwork for the arrival screens, drawn in code and decorative
// (excluded from semantics); none of it animates:
// * SplashHorizon: a printed horizon (layered ridges, a low ochre sun) along
//   the foot of the Splash screen;
// * OnboardingMotif: one round printed medallion per onboarding step:
//   contour rings ("compared with you"), six stepping stones ("every input
//   optional") and a sheltering leaf ("privacy-first, non-clinical");
// * GateBand: a field path through a hedgerow with an open gate, above the
//   consent choices.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';

Widget _art(CustomPainter p, {Size size = Size.infinite}) =>
    ExcludeSemantics(child: RepaintBoundary(child: CustomPaint(painter: p, size: size)));

Path _ridgePath(Size size, {required int seed, required double base, required double amp, double step = 0.16}) {
  final w = size.width;
  final rnd = math.Random(seed);
  final path = Path()..moveTo(0, size.height);
  var prev = Offset(0, base - amp * (0.4 + rnd.nextDouble() * 0.5));
  path.lineTo(prev.dx, prev.dy);
  for (var t = step; t <= 1.0001; t += step) {
    final x = w * t;
    final y = base - amp * (0.3 + rnd.nextDouble() * 0.7);
    final mid = Offset((prev.dx + x) / 2, math.min(prev.dy, y) - amp * 0.14);
    path.quadraticBezierTo(mid.dx, mid.dy, x, y);
    prev = Offset(x, y);
  }
  return path
    ..lineTo(w, size.height)
    ..close();
}

void _plate(Canvas canvas, Path p, Color color, {Color? edge}) {
  canvas.drawShadow(p, NatureColors.ink, 2, false);
  canvas.drawPath(p, Paint()..color = color);
  canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge ?? NatureColors.paper.withValues(alpha: 0.4));
}

// ---- Splash ------------------------------------------------------------------------------
class SplashHorizon extends StatelessWidget {
  const SplashHorizon({super.key});

  @override
  Widget build(BuildContext context) => _art(const _SplashHorizonPainter());
}

class _SplashHorizonPainter extends CustomPainter {
  const _SplashHorizonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Low sun rising behind the far ridge, with an off-register plate.
    final r = math.min(h * 0.22, 46.0);
    final sun = Offset(w * 0.68, h * 0.42);
    canvas.drawCircle(sun, r * 1.9, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.25));
    canvas.drawCircle(sun + const Offset(2, 2), r, Paint()..color = NatureColors.sunOchre);
    canvas.drawCircle(
        sun,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = NatureColors.ochreInk.withValues(alpha: 0.7));
    _plate(canvas, _ridgePath(size, seed: 3, base: h * 0.62, amp: h * 0.3, step: 0.12), NatureColors.mistRange);
    _plate(canvas, _ridgePath(size, seed: 17, base: h * 0.8, amp: h * 0.22), NatureColors.eucalyptus);
    _plate(canvas, _ridgePath(size, seed: 8, base: h * 0.98, amp: h * 0.2, step: 0.22), NatureColors.meadow);
    // A few carved grass strokes in the foreground.
    final grass = Paint()
      ..color = NatureColors.forest.withValues(alpha: 0.6)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final rg = math.Random(4);
    for (var i = 0; i < (w / 18).clamp(10, 80).round(); i++) {
      final x = rg.nextDouble() * w;
      final y = h * (0.9 + rg.nextDouble() * 0.08);
      canvas.drawLine(Offset(x, y), Offset(x + 2 - rg.nextDouble() * 4, y - 6 - rg.nextDouble() * 6), grass);
    }
  }

  @override
  bool shouldRepaint(_SplashHorizonPainter old) => false;
}

// ---- Onboarding medallions -------------------------------------------------------------------
enum OnboardingMotifKind { contours, stones, leaf }

class OnboardingMotif extends StatelessWidget {
  final OnboardingMotifKind kind;
  final double size;
  const OnboardingMotif({super.key, required this.kind, this.size = 168});

  @override
  Widget build(BuildContext context) => _art(_MotifPainter(kind), size: Size.square(size));
}

class _MotifPainter extends CustomPainter {
  final OnboardingMotifKind kind;
  const _MotifPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    // The medallion: an ochre plate printed slightly off a paper disc.
    canvas.drawCircle(c + const Offset(4, 5), r, Paint()..color = NatureColors.sunOchre.withValues(alpha: 0.55));
    canvas.drawCircle(c, r, Paint()..color = NatureColors.paper);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = NatureColors.forest);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - 1)));
    switch (kind) {
      case OnboardingMotifKind.contours:
        _contours(canvas, c, r);
      case OnboardingMotifKind.stones:
        _stones(canvas, c, r);
      case OnboardingMotifKind.leaf:
        _leaf(canvas, c, r);
    }
    canvas.restore();
  }

  // A hill seen from above as contour rings; one ring drawn in forest: your
  // own line, compared with itself.
  void _contours(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = NatureColors.sky);
    final rnd = math.Random(12);
    for (var i = 6; i >= 1; i--) {
      final rr = r * i / 6.6;
      final p = Path();
      for (var a = 0.0; a <= math.pi * 2 + 0.01; a += math.pi / 18) {
        final wob = 1 + (math.sin(a * 3 + i) * 0.06) + (rnd.nextDouble() - 0.5) * 0.03;
        final pt = c + Offset(math.cos(a), math.sin(a)) * rr * wob + const Offset(0, 6);
        a == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = Color.lerp(NatureColors.mistRange, NatureColors.meadow, (6 - i) / 6)!);
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 3 ? 2.2 : 1
            ..color = i == 3 ? NatureColors.forest : NatureColors.paper.withValues(alpha: 0.6));
    }
    canvas.drawCircle(c + const Offset(0, 6), 4, Paint()..color = NatureColors.dustyCoral);
  }

  // Six stepping stones across water: six separate, optional inputs.
  void _stones(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawRect(rect, Paint()..color = NatureColors.skyHorizon);
    final water = Rect.fromLTWH(rect.left, c.dy - r * 0.15, rect.width, r * 1.2);
    canvas.drawRect(water, Paint()..color = Color.lerp(NatureColors.riverBlue, NatureColors.sky, 0.45)!);
    final ripple = Paint()
      ..color = NatureColors.paper.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = water.top + 10 + i * 13.0;
      canvas.drawLine(Offset(c.dx - r * 0.8 + i * 9, y), Offset(c.dx - r * 0.45 + i * 9, y), ripple);
    }
    final stone = Paint()..color = NatureColors.borderStrong;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = NatureColors.ink.withValues(alpha: 0.55);
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final p = Offset(c.dx - r * 0.66 + t * r * 1.32, c.dy + r * 0.32 - math.sin(t * math.pi) * r * 0.28);
      final o = Rect.fromCenter(center: p, width: r * 0.26, height: r * 0.12);
      canvas.drawOval(o.shift(const Offset(1.5, 1.5)), Paint()..color = NatureColors.sunOchre.withValues(alpha: 0.6));
      canvas.drawOval(o, i == 2 ? (Paint()..color = NatureColors.forest) : stone);
      canvas.drawOval(o, edge);
    }
    _hill(canvas, c, r);
  }

  void _hill(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx - r, c.dy - r * 0.15)
      ..quadraticBezierTo(c.dx - r * 0.4, c.dy - r * 0.55, c.dx + r * 0.1, c.dy - r * 0.2)
      ..quadraticBezierTo(c.dx + r * 0.55, c.dy - r * 0.5, c.dx + r, c.dy - r * 0.2)
      ..lineTo(c.dx + r, c.dy - r * 0.15)
      ..close();
    canvas.drawPath(p, Paint()..color = NatureColors.eucalyptus);
  }

  // A broad leaf sheltering a small seed: kept close, not taken anywhere.
  void _leaf(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = NatureColors.sageWash);
    final leaf = Path()
      ..moveTo(c.dx - r * 0.62, c.dy + r * 0.3)
      ..quadraticBezierTo(c.dx - r * 0.5, c.dy - r * 0.7, c.dx + r * 0.6, c.dy - r * 0.45)
      ..quadraticBezierTo(c.dx + r * 0.35, c.dy + r * 0.5, c.dx - r * 0.62, c.dy + r * 0.3)
      ..close();
    canvas.drawPath(leaf.shift(const Offset(2, 2.5)), Paint()..color = NatureColors.sunOchre.withValues(alpha: 0.5));
    canvas.drawPath(leaf, Paint()..color = NatureColors.meadow);
    canvas.drawPath(
        leaf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = NatureColors.forest);
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = NatureColors.paper.withValues(alpha: 0.75);
    final from = Offset(c.dx - r * 0.55, c.dy + r * 0.25);
    final to = Offset(c.dx + r * 0.52, c.dy - r * 0.4);
    canvas.drawLine(from, to, vein);
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      final p = Offset.lerp(from, to, t)!;
      canvas.drawLine(p, p + Offset(-r * 0.05, -r * 0.2), vein);
      canvas.drawLine(p, p + Offset(r * 0.14, r * 0.1), vein);
    }
    // The seed under the leaf.
    final seed = c + Offset(r * 0.08, r * 0.52);
    canvas.drawOval(Rect.fromCenter(center: seed + const Offset(1.5, 1.5), width: r * 0.24, height: r * 0.17),
        Paint()..color = NatureColors.sunOchre);
    canvas.drawOval(Rect.fromCenter(center: seed, width: r * 0.24, height: r * 0.17), Paint()..color = NatureColors.dustyCoral);
    canvas.drawLine(
        Offset(c.dx - r * 0.8, c.dy + r * 0.62),
        Offset(c.dx + r * 0.8, c.dy + r * 0.62),
        Paint()
          ..color = NatureColors.forest.withValues(alpha: 0.5)
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_MotifPainter old) => old.kind != kind;
}

// ---- Consent: an open gate ---------------------------------------------------------------------
class GateBand extends StatelessWidget {
  final bool tornBottom;
  const GateBand({super.key, this.tornBottom = false});

  @override
  Widget build(BuildContext context) => _art(_GatePainter(tornBottom));
}

class _GatePainter extends CustomPainter {
  final bool tornBottom;
  const _GatePainter(this.tornBottom);

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
    final sun = Offset(w * 0.2, h * 0.3);
    final r = math.min(h * 0.08, 24.0);
    canvas.drawCircle(sun, r * 2, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.28));
    canvas.drawCircle(sun + const Offset(1.4, 1.4), r, Paint()..color = NatureColors.sunGlow);

    _plate(canvas, _ridgePath(size, seed: 44, base: h * 0.56, amp: h * 0.16, step: 0.12), NatureColors.mistRange);
    _plate(canvas, _ridgePath(size, seed: 2, base: h * 0.74, amp: h * 0.1, step: 0.2), NatureColors.eucalyptus);

    // Hedgerow: a band of rounded shrubs across the field.
    final hedgeY = h * 0.68;
    final hedge = Paint()..color = NatureColors.pineMid;
    final rh = math.Random(6);
    for (var x = -10.0; x < w + 20; x += 16 + rh.nextDouble() * 10) {
      final rr = 10 + rh.nextDouble() * 9;
      canvas.drawCircle(Offset(x, hedgeY - rr * 0.4), rr, hedge);
    }
    canvas.drawRect(Rect.fromLTWH(0, hedgeY - 4, w, h * 0.06), hedge);

    // Field and path.
    final field = Rect.fromLTWH(0, hedgeY + h * 0.04, w, h - hedgeY);
    canvas.drawRect(field, Paint()..color = NatureColors.meadow);
    final gx = w * (w > 900 ? 0.74 : 0.66);
    final pathP = Path()
      ..moveTo(gx - 24, field.top)
      ..lineTo(gx + 24, field.top)
      ..quadraticBezierTo(gx + 60, h * 0.9, gx + 120, h + 2)
      ..lineTo(gx - 90, h + 2)
      ..quadraticBezierTo(gx - 40, h * 0.9, gx - 24, field.top)
      ..close();
    canvas.drawPath(pathP, Paint()..color = NatureColors.cream);

    // Gap in the hedge with two posts and an open five-bar gate swung inwards.
    canvas.drawRect(Rect.fromLTWH(gx - 26, hedgeY - 26, 52, h * 0.06 + 26), Paint()..color = NatureColors.skyHorizon);
    final post = Paint()
      ..color = NatureColors.forestDeep
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final top = hedgeY - 20, bottom = field.top + 2;
    canvas.drawLine(Offset(gx - 26, top), Offset(gx - 26, bottom), post);
    canvas.drawLine(Offset(gx + 26, top), Offset(gx + 26, bottom), post);
    final bar = Paint()
      ..color = NatureColors.paper
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Open gate drawn in perspective, hinged on the right post.
    final hinge = Offset(gx + 26, 0);
    final open = Offset(gx + 62, 0);
    for (var i = 0; i < 5; i++) {
      final y = top + 4 + i * (bottom - top - 8) / 4;
      canvas.drawLine(Offset(hinge.dx, y), Offset(open.dx, y + 6 + i * 1.5), bar);
    }
    canvas.drawLine(Offset(hinge.dx, top + 4), Offset(open.dx, bottom + 4), bar);
    canvas.drawLine(Offset(open.dx, top + 10), Offset(open.dx, bottom + 6), bar);

    if (tornBottom) {
      final tr = math.Random(41);
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

  @override
  bool shouldRepaint(_GatePainter old) => old.tornBottom != tornBottom;
}
