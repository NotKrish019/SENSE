import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'nature_tokens.dart';

/// SENSE "Living Landscapes": a paper-cut diorama (redesign prototype v2).
///
/// Original artwork drawn in code. It takes qualities from the four
/// reference images (layered ranges, rock formations, a river, carved
/// contour clouds, an engraved sun, printed texture) without tracing any of
/// them.
///
/// Depth: the scene is a stack of cut-paper planes. Each plane casts a soft
/// shadow onto the plane behind it and has a lit top edge, so the depth is
/// visible even when nothing moves. On top of that:
///   * pointer / touch position tilts the diorama a little (perspective
///     transform) and separates the planes (parallax); page scroll adds a
///     small vertical separation;
///   * the sun is a dimensional element: shaded body, raised bevelled rings,
///     an off-register print plate, slowly rotating irregular rays and a
///     glow that breathes (10 s) and brightens when the pointer comes near;
///   * clouds drift independently (different speeds and directions, wrap
///     around), a flock crosses the sky every ~34 s with flapping wings,
///     grasses and flowers sway individually, the river shimmers.
///
/// Only small layers repaint per frame (rays, glow, birds, plants, water
/// light); everything else is painted once and moved by transforms.
/// Reduced motion (MediaQuery.disableAnimations): completely still.
/// Hidden tabs / covered routes: paused through TickerMode.
/// Decorative: excluded from semantics.
class LivingLandscape extends StatefulWidget {
  final double height;
  final ValueListenable<double>? scrollOffset;

  /// Where the sun sits in the scene; layouts use it to keep text clear of it.
  final Alignment sunAt;

  /// Horizontal extent of the rock formation (fractions of the width), so a
  /// layout can keep it visible beside overlapping content.
  final double rockLeft, rockWidth;

  const LivingLandscape({
    super.key,
    required this.height,
    this.scrollOffset,
    this.sunAt = const Alignment(0.55, -0.45),
    this.rockLeft = 0.04,
    this.rockWidth = 0.32,
  });

  @override
  State<LivingLandscape> createState() => _LivingLandscapeState();
}

const double _bleed = 28; // painted margin so tilt/parallax never shows an edge

class _LivingLandscapeState extends State<LivingLandscape> with SingleTickerProviderStateMixin {
  // One clock for everything: value * 3600 = seconds.
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(hours: 1));
  final ValueNotifier<Offset> _target = ValueNotifier(Offset.zero); // -1..1
  final ValueNotifier<Offset> _pointer = ValueNotifier(Offset.zero); // eased
  final ValueNotifier<Offset?> _pointerLocal = ValueNotifier(null);
  // Ambient time in seconds, published at ~30 Hz: slow ambient motion looks
  // the same as at 60 Hz and costs half the repaints.
  final ValueNotifier<double> _time = ValueNotifier(0);
  bool _motion = true;
  _Scene? _scene;

  // Static planes are baked into images once per size, so each frame only
  // draws a few images plus the small live layers. (Flutter web replays
  // recorded pictures every frame; replaying the static artwork, with its
  // shadows, grain and engraving, held the scene near 30 fps.)
  final Map<String, ui.Image> _baked = {};
  Object? _bakedKey;

  void _clearBaked() {
    for (final img in _baked.values) {
      img.dispose();
    }
    _baked.clear();
  }

  ui.Image _bake(String id, Size size, List<CustomPainter> painters, double dpr) {
    final cached = _baked[id];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    for (final p in painters) {
      p.paint(canvas, size);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
        math.max(1, (size.width * dpr).ceil()), math.max(1, (size.height * dpr).ceil()));
    picture.dispose();
    return _baked[id] = image;
  }

  double get _t => _clock.value * 3600;

  @override
  void initState() {
    super.initState();
    _clock.addListener(() {
      final next = Offset.lerp(_pointer.value, _target.value, 0.06)!;
      if ((next - _pointer.value).distanceSquared > 1e-7) _pointer.value = next;
      final t = _t;
      if ((t - _time.value).abs() >= 1 / 30) _time.value = t;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = !MediaQuery.disableAnimationsOf(context);
    if (_motion) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      _clock.value = 0;
      _time.value = 0;
      _target.value = Offset.zero;
      _pointer.value = Offset.zero;
      _pointerLocal.value = null;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _target.dispose();
    _pointer.dispose();
    _pointerLocal.dispose();
    _time.dispose();
    _clearBaked();
    super.dispose();
  }

  void _track(Offset local, Size size) {
    if (!_motion) return;
    _pointerLocal.value = local;
    _target.value = Offset(
      (((local.dx / size.width) - 0.5) * 2).clamp(-1.0, 1.0),
      (((local.dy / size.height) - 0.5) * 2).clamp(-1.0, 1.0),
    );
  }

  void _release() {
    _target.value = Offset.zero;
    _pointerLocal.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, widget.height);
        final scene = (_scene != null &&
                _scene!.size == size &&
                _scene!.sunAt == widget.sunAt &&
                _scene!.rockLeft == widget.rockLeft)
            ? _scene!
            : (_scene = _Scene(size, widget.sunAt, widget.rockLeft, widget.rockWidth));
        final full = Size(size.width + 2 * _bleed, size.height + 2 * _bleed);
        // Bake resolution: device pixels, capped to keep memory reasonable
        // on wide screens (about 60 MB at 1440 px, much less on phones).
        final dpr = math.min(MediaQuery.devicePixelRatioOf(context), size.width > 900 ? 1.5 : 2.0);
        final key = (scene, dpr);
        if (_bakedKey != key) {
          _clearBaked();
          _bakedKey = key;
        }
        Widget baked(String id, List<CustomPainter> painters) => RawImage(
              image: _bake(id, full, painters, dpr),
              width: full.width,
              height: full.height,
              scale: dpr,
            );

        Widget plane(double depth, Widget child) {
          return Positioned(
            left: -_bleed,
            top: -_bleed,
            width: full.width,
            height: full.height,
            child: _motion
                ? AnimatedBuilder(
                    animation: Listenable.merge([_pointer, if (widget.scrollOffset != null) widget.scrollOffset!]),
                    child: child,
                    builder: (context, child) {
                      final p = _pointer.value;
                      final s = widget.scrollOffset?.value ?? 0;
                      return Transform.translate(
                        offset: Offset(-p.dx * 14 * depth,
                            -p.dy * 8 * depth + (s * 0.08 * depth).clamp(-14.0, 14.0)),
                        child: child,
                      );
                    },
                  )
                : child,
          );
        }

        Widget still(CustomPainter p) => RepaintBoundary(child: CustomPaint(size: full, painter: p));
        Widget live(CustomPainter p) => RepaintBoundary(child: CustomPaint(size: full, painter: p));

        Widget cloud(_Cloud cl, double depth) {
          final box = cl.bounds.inflate(10);
          final art = RawImage(
            image: _bake('cloud${cl.seed}', box.size, [_CloudPainter(cl, box.topLeft)], dpr),
            width: box.width,
            height: box.height,
            scale: dpr,
          );
          return plane(
            depth,
            Stack(clipBehavior: Clip.none, children: [
              _motion
                  ? AnimatedBuilder(
                      animation: _time,
                      child: art,
                      builder: (context, child) {
                        final travel = full.width + box.width;
                        final x = ((box.left + _bleed + cl.speed * _time.value + box.width) % travel + travel) % travel -
                            box.width;
                        return Positioned(left: x, top: box.top + _bleed, child: child!);
                      },
                    )
                  : Positioned(left: box.left + _bleed, top: box.top + _bleed, child: art),
            ]),
          );
        }

        final ValueListenable<double> clock = _time;
        final layers = Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            plane(0, baked('sky', [_SkyPainter(scene)])),
            plane(0.06, live(_SunGlowPainter(scene, clock, _pointerLocal))),
            plane(0.06, live(_SunRaysPainter(scene, clock))),
            plane(0.06, still(_SunBodyPainter(scene))),
            cloud(scene.clouds[0], 0.10),
            cloud(scene.clouds[1], 0.12),
            plane(0.18, baked('distant', [_RangePainter(scene, scene.distant)])),
            cloud(scene.clouds[2], 0.22),
            plane(0.34, baked('middle', [_RangePainter(scene, scene.middle), _RockPainter(scene)])),
            plane(0.56, baked('valley', [_ForestPainter(scene, back: true), _ValleyPainter(scene)])),
            plane(0.6, live(_RiverLightPainter(scene, clock))),
            cloud(scene.clouds[3], 0.35),
            plane(0.8, baked('front', [_ForestPainter(scene, back: false), _ForegroundPainter(scene)])),
            plane(1.0, live(_PlantsPainter(scene, clock))),
            plane(0.15, live(_BirdsPainter(scene, clock))),
            Positioned.fill(
              child: IgnorePointer(
                child: RawImage(
                  image: _bake('grain', size, [_GrainPainter(scene)], dpr),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ],
        );

        // Gentle perspective tilt toward the pointer: the diorama, not a card.
        final tilted = _motion
            ? AnimatedBuilder(
                animation: _pointer,
                // Flatten the planes into one surface first, so the tilt
                // transforms a single texture instead of every plane.
                child: RepaintBoundary(child: layers),
                builder: (context, child) {
                  final p = _pointer.value;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0006)
                      ..rotateX(p.dy * 0.035)
                      ..rotateY(-p.dx * 0.045)
                      // Slight overscale while tilted so no edge is revealed.
                      ..scaleByDouble(1 + 0.05 * p.distance.clamp(0.0, 1.0),
                          1 + 0.05 * p.distance.clamp(0.0, 1.0), 1, 1),
                    child: child,
                  );
                },
              )
            : layers;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _track(e.localPosition, size),
          onPointerMove: (e) => _track(e.localPosition, size),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: MouseRegion(
            onHover: (e) => _track(e.localPosition, size),
            onExit: (_) => _release(),
            child: ClipRect(child: SizedBox(width: size.width, height: size.height, child: tilted)),
          ),
        );
      }),
    );
  }
}

// ===========================================================================
// Scene geometry (computed once per size). Panel coordinates; painters add
// the bleed offset.
// ===========================================================================

/// Deterministic value noise from summed sines with seeded phases.
class _Noise {
  final List<(double, double, double)> _o;
  _Noise(int seed, {int octaves = 5, double base = 1.6}) : _o = _octaves(seed, octaves, base);

  static List<(double, double, double)> _octaves(int seed, int octaves, double base) {
    final r = math.Random(seed);
    return List.generate(octaves, (i) {
      final f = base * math.pow(2.1, i).toDouble() * (0.8 + r.nextDouble() * 0.4);
      final a = 1 / math.pow(1.9, i).toDouble();
      return (f, a, r.nextDouble() * math.pi * 2);
    });
  }

  double at(double x) {
    var v = 0.0, n = 0.0;
    for (final (f, a, p) in _o) {
      v += a * math.sin(x * f * math.pi * 2 + p);
      n += a;
    }
    return v / n; // -1..1
  }
}

class _Ridge {
  final List<Offset> pts;
  final Color fill, edgeLight, shadow;
  final double elevation;
  final bool engrave;
  final Color? hazeTo;
  _Ridge(this.pts,
      {required this.fill,
      required this.edgeLight,
      required this.shadow,
      required this.elevation,
      this.engrave = false,
      this.hazeTo});
}

class _Cloud {
  final Path outline; // closed silhouette
  final Offset centre;
  final Rect bounds;
  final double speed; // px/s (sign = direction)
  final double opacity;
  final int seed;
  _Cloud(this.outline, this.centre, this.bounds, this.speed, this.opacity, this.seed);
}

class _Scene {
  final Size size;
  final Alignment sunAt;
  final double rockLeft, rockWidth;
  late final double w = size.width, h = size.height;
  late final Offset sun = sunAt.alongSize(size);
  late final double sunR = (math.min(w, h * 1.6) * 0.075).clamp(22.0, 64.0);
  double get unit => h / 420; // scale for strokes and plant sizes

  _Scene(this.size, this.sunAt, this.rockLeft, this.rockWidth);

  // ---- Ranges -------------------------------------------------------------
  List<Offset> _profile(int seed, double baseY, double amp,
      {double freq = 1.6, double peakX = -1, double peakLift = 0}) {
    final n = _Noise(seed, base: freq);
    final pts = <Offset>[];
    for (var x = -_bleed; x <= w + _bleed; x += 3) {
      final u = x / w;
      var y = baseY + n.at(u) * amp;
      if (peakX >= 0) {
        final d = (u - peakX) / 0.16;
        y -= peakLift * math.exp(-d * d);
      }
      pts.add(Offset(x, y));
    }
    return pts;
  }

  late final _Ridge distant = _Ridge(
    _profile(3, h * 0.47, h * 0.07, freq: 1.2, peakX: 0.3, peakLift: h * 0.08),
    fill: NatureColors.mistRange,
    edgeLight: NatureColors.paper,
    shadow: NatureColors.skyTeal,
    elevation: 3,
    hazeTo: NatureColors.skyHorizon,
  );
  late final _Ridge middle = _Ridge(
    _profile(7, h * 0.58, h * 0.085, freq: 1.5, peakX: 0.78, peakLift: h * 0.12),
    fill: NatureColors.eucalyptus,
    edgeLight: NatureColors.cream,
    shadow: NatureColors.forestDeep,
    elevation: 6,
    engrave: true,
  );

  double ridgeY(List<Offset> pts, double x) {
    final i = ((x + _bleed) / 3).floor().clamp(0, pts.length - 2);
    final a = pts[i], b = pts[i + 1];
    return a.dy + (b.dy - a.dy) * ((x - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0);
  }

  // ---- Rock formation (mesa and spires, mid-left) -------------------------
  late final Path rock = () {
    final n = _Noise(41, base: 3.5, octaves: 4);
    final base = h * 0.665;
    final left = w * rockLeft, right = w * (rockLeft + rockWidth);
    final p = Path()..moveTo(left - w * 0.02, base + 2);
    for (var x = left - w * 0.02; x <= right + w * 0.02; x += 2) {
      final u = (x - left) / (right - left);
      // Mesa body with two weathered spires; sloping scree at both ends.
      var top = h * (0.53 + 0.02 * n.at(u));
      top -= h * 0.075 * math.exp(-math.pow((u - 0.3) / 0.07, 2));
      top -= h * 0.045 * math.exp(-math.pow((u - 0.66) / 0.055, 2));
      final edge = math.min(u, 1 - u);
      if (edge < 0.14) {
        final k = ((0.14 - edge) / 0.14).clamp(0.0, 1.0);
        top += math.pow(k, 1.6) * (base - top);
      }
      p.lineTo(x, top);
    }
    p
      ..lineTo(right + w * 0.02, base + 2)
      ..close();
    return p;
  }();

  /// The rock's top profile, for strata that follow its shape.
  late final List<Offset> rockTop = () {
    final pts = <Offset>[];
    final m = rock.computeMetrics().first;
    for (var d = 0.0; d < m.length; d += 3) {
      final pt = m.getTangentForOffset(d)!.position;
      if (pt.dy < h * 0.66) pts.add(pt);
    }
    return pts;
  }();

  // ---- Valley floor and river ---------------------------------------------
  late final _Noise _groundNoise = _Noise(13, base: 1.1);
  double groundY(double x) => h * 0.70 + _groundNoise.at(x / w) * h * 0.025;

  late final Path valley = () {
    final p = Path()..moveTo(-_bleed, h + _bleed);
    for (var x = -_bleed; x <= w + _bleed; x += 4) {
      p.lineTo(x, groundY(x));
    }
    return p
      ..lineTo(w + _bleed, h + _bleed)
      ..close();
  }();

  /// River centreline from the far valley to the bottom edge (t = 0..1).
  Offset riverAt(double t) {
    final x0 = sun.dx.clamp(w * 0.35, w * 0.8);
    final x = x0 + math.sin(t * math.pi * 2.3 + 0.4) * w * 0.15 * (0.35 + t) - (x0 - w * 0.5) * t;
    final y = groundY(x0) + 2 + (h - groundY(x0) + _bleed) * t;
    return Offset(x, y);
  }

  double riverHalfWidth(double t) => (3 + t * w * 0.085).clamp(3.0, w * 0.13);

  late final Path river = () {
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= 60; i++) {
      final t = i / 60;
      final c = riverAt(t);
      final c2 = riverAt(math.min(1, t + 0.01));
      final d = (c2 - c);
      final len = d.distance == 0 ? 1.0 : d.distance;
      final nrm = Offset(-d.dy, d.dx) / len;
      final hw = riverHalfWidth(t) * (1 + 0.12 * math.sin(t * 17));
      left.add(c + nrm * hw);
      right.add(c - nrm * hw);
    }
    final p = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    for (final o in right.reversed) {
      p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }();

  // ---- Foreground ------------------------------------------------------------
  late final _Noise _foreNoise = _Noise(29, base: 1.4);
  double foreY(double x) {
    // Rises on the left (a bank with trees), dips to let the river through.
    final u = x / w;
    final riverX = riverAt(1).dx / w;
    final dip = math.exp(-math.pow((u - riverX) / 0.16, 2));
    return h * (0.84 - 0.06 * (1 - u) + 0.08 * dip) + _foreNoise.at(u) * h * 0.02;
  }

  late final Path foreground = () {
    final p = Path()..moveTo(-_bleed, h + _bleed);
    for (var x = -_bleed; x <= w + _bleed; x += 4) {
      p.lineTo(x, foreY(x));
    }
    return p
      ..lineTo(w + _bleed, h + _bleed)
      ..close();
  }();

  // ---- Clouds ------------------------------------------------------------------
  late final List<_Cloud> clouds = [
    _makeCloud(Offset(w * 0.18, h * 0.17), w * 0.16, 0.42, 101, speed: 3.2, opacity: 0.8),
    _makeCloud(Offset(w * 0.86, h * 0.13), w * 0.11, 0.5, 202, speed: -2.4, opacity: 0.75),
    _makeCloud(Offset(w * 0.52, h * 0.36), w * 0.13, 0.36, 303, speed: 5.5, opacity: 0.95),
    _makeCloud(Offset(w * 0.08, h * 0.44), w * 0.12, 0.4, 404, speed: -7.5, opacity: 1),
  ];

  _Cloud _makeCloud(Offset c, double rx, double aspect, int seed,
      {required double speed, required double opacity}) {
    rx = math.min(rx, h * 0.3).clamp(44.0, 150.0);
    final r = math.Random(seed);
    // A cumulus built from an irregular cluster of puffs: a long base row,
    // a second row of larger billows, and an off-centre crown. The puff
    // count, sizes and offsets differ per cloud, so no two share a shape.
    var path = Path();
    final base = 4 + r.nextInt(3);
    for (var i = 0; i < base; i++) {
      final x = c.dx - rx + (i + 0.5) * (2 * rx / base) + (r.nextDouble() - 0.5) * rx * 0.15;
      final pr = rx * (0.22 + r.nextDouble() * 0.12);
      path = Path.combine(PathOperation.union, path,
          Path()..addOval(Rect.fromCircle(center: Offset(x, c.dy - pr * 0.25), radius: pr)));
    }
    final mid = 2 + r.nextInt(3);
    final skew = (r.nextDouble() - 0.5) * rx * 0.6;
    for (var i = 0; i < mid; i++) {
      final x = c.dx + skew - rx * 0.55 + (i + 0.5) * (1.1 * rx / mid);
      final pr = rx * (0.30 + r.nextDouble() * 0.14) * aspect / 0.4;
      path = Path.combine(PathOperation.union, path,
          Path()..addOval(Rect.fromCircle(center: Offset(x, c.dy - rx * 0.22 * aspect / 0.4), radius: pr)));
    }
    if (r.nextBool()) {
      final pr = rx * (0.22 + r.nextDouble() * 0.1);
      path = Path.combine(PathOperation.union, path,
          Path()..addOval(Rect.fromCircle(center: Offset(c.dx + skew * 1.4, c.dy - rx * 0.5 * aspect / 0.4), radius: pr)));
    }
    // Level underside.
    final b0 = path.getBounds();
    final baseY = c.dy + rx * 0.08;
    path = Path.combine(PathOperation.intersect, path,
        Path()..addRect(Rect.fromLTRB(b0.left - 4, b0.top - 4, b0.right + 4, baseY)));
    return _Cloud(path, c, path.getBounds(), speed, opacity, seed);
  }
}

// ===========================================================================
// Painters
// ===========================================================================
abstract class _Plane extends CustomPainter {
  final _Scene s;
  _Plane(this.s, {super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(_bleed, _bleed);
    draw(canvas);
    canvas.restore();
  }

  void draw(Canvas canvas);

  @override
  bool shouldRepaint(covariant _Plane old) => old.s != s;
}

/// Cut-paper treatment: soft cast shadow, flat fill, lit top edge.
void _cutPaper(Canvas canvas, Path path, Color fill, {Color? shadow, double elevation = 4, Color? edge}) {
  if (shadow != null) {
    canvas.save();
    canvas.translate(elevation * 0.4, -elevation * 0.15);
    canvas.drawShadow(path, shadow.withValues(alpha: 0.55), elevation, false);
    canvas.restore();
  }
  canvas.drawPath(path, Paint()..color = fill);
  if (edge != null) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = edge.withValues(alpha: 0.55),
    );
  }
}

class _SkyPainter extends _Plane {
  _SkyPainter(super.s);

  @override
  void draw(Canvas canvas) {
    final w = s.w, h = s.h;
    final rect = Rect.fromLTRB(-_bleed, -_bleed, w + _bleed, h + _bleed);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, h * 0.7), const [
          NatureColors.skyHigh,
          NatureColors.sky,
          NatureColors.skyHorizon,
        ], const [0, 0.5, 1]),
    );
    // Warm light around the sun's side of the sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(s.sun, math.max(w, h) * 0.7, [
          NatureColors.sunGlow.withValues(alpha: 0.35),
          NatureColors.sunGlow.withValues(alpha: 0),
        ]),
    );
    // Printed ink unevenness: soft mottling, not a dot grid.
    final r = math.Random(5);
    for (var i = 0; i < (w * h / 2600).round(); i++) {
      final c = Offset(r.nextDouble() * w, r.nextDouble() * h * 0.65);
      final rad = 6 + r.nextDouble() * 38;
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..color = (i.isEven ? NatureColors.skyTeal : NatureColors.paper)
              .withValues(alpha: 0.035 + r.nextDouble() * 0.04)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.5),
      );
    }
    // Horizontal paper fibres.
    final fibre = Paint()
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < (w / 6).round(); i++) {
      final y = r.nextDouble() * h * 0.6;
      final x = r.nextDouble() * w;
      fibre.color = NatureColors.paper.withValues(alpha: 0.25 + r.nextDouble() * 0.25);
      canvas.drawLine(Offset(x, y), Offset(x + 10 + r.nextDouble() * 50, y + (r.nextDouble() - 0.5) * 1.5), fibre);
    }
  }
}

// ---- The dimensional sun ----------------------------------------------------------
class _SunGlowPainter extends _Plane {
  final ValueListenable<double> clock;
  final ValueListenable<Offset?> pointer;
  _SunGlowPainter(super.s, this.clock, this.pointer) : super(repaint: Listenable.merge([clock, pointer]));

  @override
  void draw(Canvas canvas) {
    final t = clock.value;
    final breathe = math.sin(t * 2 * math.pi / 10); // 10 s
    var near = 0.0;
    final p = pointer.value;
    if (p != null) {
      final d = (p - s.sun).distance;
      near = (1 - d / (s.sunR * 6)).clamp(0.0, 1.0);
    }
    final r = s.sunR * (2.6 + 0.22 * breathe + 0.5 * near);
    canvas.drawCircle(
      s.sun,
      r,
      Paint()
        ..shader = ui.Gradient.radial(s.sun, r, [
          NatureColors.sunGlow.withValues(alpha: (0.55 + 0.15 * breathe + 0.2 * near).clamp(0.0, 1.0)),
          NatureColors.sunGlow.withValues(alpha: 0.18),
          NatureColors.sunGlow.withValues(alpha: 0),
        ], const [0, 0.45, 1]),
    );
  }

  @override
  bool shouldRepaint(covariant _Plane old) => true;
}

class _SunRaysPainter extends _Plane {
  final ValueListenable<double> clock;
  _SunRaysPainter(super.s, this.clock) : super(repaint: clock);

  @override
  void draw(Canvas canvas) {
    final t = clock.value;
    final r = s.sunR;
    canvas.save();
    canvas.translate(s.sun.dx, s.sun.dy);
    canvas.rotate(t * 2 * math.pi / 240); // one turn every 4 minutes
    final rnd = math.Random(9);
    const n = 13;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + rnd.nextDouble() * 0.12;
      final len = r * (0.55 + rnd.nextDouble() * 0.5);
      final width = r * (0.16 + rnd.nextDouble() * 0.08);
      final base = r * 1.08;
      // A slightly curved flame-like ray with an engraved centre line.
      final dir = Offset(math.cos(a), math.sin(a));
      final nrm = Offset(-dir.dy, dir.dx);
      final p0 = dir * base + nrm * width;
      final p1 = dir * base - nrm * width;
      final tip = dir * (base + len) + nrm * width * 0.6;
      final c1 = dir * (base + len * 0.55) + nrm * width * 1.3;
      final c2 = dir * (base + len * 0.5) - nrm * width * 0.2;
      final ray = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, p1.dx, p1.dy)
        ..close();
      canvas.drawPath(ray, Paint()..color = NatureColors.sunGlow);
      canvas.drawLine(dir * (base + 2), dir * (base + len * 0.7) + nrm * width * 0.45,
          Paint()
            ..strokeWidth = 0.9
            ..color = NatureColors.ochreInk.withValues(alpha: 0.35));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Plane old) => true;
}

class _SunBodyPainter extends _Plane {
  _SunBodyPainter(super.s);

  @override
  void draw(Canvas canvas) {
    final c = s.sun, r = s.sunR;
    // Off-register print plate.
    canvas.drawCircle(c + Offset(r * 0.07, r * 0.06), r,
        Paint()..color = NatureColors.dustyCoral.withValues(alpha: 0.75));
    // Cast shadow, then a shaded body: lit upper left, deeper lower right.
    canvas.drawShadow(Path()..addOval(Rect.fromCircle(center: c, radius: r)), NatureColors.ochreInk, 6, false);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c + Offset(-r * 0.35, -r * 0.4), r * 1.5, const [
          Color(0xFFF7D79A),
          NatureColors.sunOchre,
          Color(0xFFC98A3A),
        ], const [0, 0.55, 1]),
    );
    // Raised rings: each ring is a ridge with a shadow below and a highlight
    // above (bevel), slightly wobbled like hand-carved lines.
    for (var k = 1; k <= 4; k++) {
      final rk = r * (0.16 + k * 0.18);
      Path ring(Offset shift) {
        final p = Path();
        for (var i = 0; i <= 72; i++) {
          final a = i / 72 * 2 * math.pi;
          final wob = 1 + 0.03 * math.sin(a * 3 + k) + 0.018 * math.sin(a * 8 + k * 2);
          final pt = c + shift + Offset(math.cos(a), math.sin(a)) * rk * wob;
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        return p;
      }

      canvas.drawPath(
          ring(Offset(r * 0.02, r * 0.025)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = const Color(0xFFB9772C).withValues(alpha: 0.55));
      canvas.drawPath(
          ring(Offset(-r * 0.015, -r * 0.02)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.035
            ..color = const Color(0xFFFBE6BC).withValues(alpha: 0.85));
    }
    // Soft specular highlight and a fine outer rim.
    canvas.drawCircle(
        c + Offset(-r * 0.38, -r * 0.42),
        r * 0.18,
        Paint()
          ..color = NatureColors.paper.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = NatureColors.ochreInk.withValues(alpha: 0.6));
  }
}

// ---- Clouds -----------------------------------------------------------------------
class _CloudPainter extends CustomPainter {
  final _Cloud cl;
  final Offset origin;
  _CloudPainter(this.cl, this.origin);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(-origin.dx, -origin.dy);
    final path = cl.outline;
    canvas.saveLayer(cl.bounds.inflate(12), Paint()..color = Color.fromRGBO(0, 0, 0, cl.opacity));
    canvas.drawShadow(path, NatureColors.skyTeal, 4, false);
    // Body with printed shading: warm peach underside fading up to cream.
    canvas.drawPath(path, Paint()..color = NatureColors.cream);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, cl.bounds.top), Offset(0, cl.bounds.bottom), [
          NatureColors.cream.withValues(alpha: 0),
          const Color(0xFFF2CFB4).withValues(alpha: 0.75),
        ], const [0.45, 1]),
    );
    // Carved contours: shrinking copies of the outline toward a point low in
    // the cloud, alternating ochre and coral, each slightly rotated.
    canvas.save();
    canvas.clipPath(path);
    final anchor = Offset(cl.centre.dx, cl.bounds.bottom - cl.bounds.height * 0.15);
    for (var k = 1; k <= 7; k++) {
      final f = 1 - k * 0.12;
      if (f <= 0.1) break;
      final m = Matrix4.identity()
        ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
        ..rotateZ(0.012 * k * (cl.seed.isEven ? 1 : -1))
        ..scaleByDouble(f, f * 0.94, 1, 1)
        ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
      canvas.drawPath(
        path.transform(m.storage),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = (k.isEven ? NatureColors.dustyCoral : NatureColors.sunOchre).withValues(alpha: 0.7),
      );
    }
    canvas.restore();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = NatureColors.ochreInk.withValues(alpha: 0.45));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.cl != cl;
}

// ---- Ranges: cut paper, haze, sunlit slopes, engraved contours ------------------
class _RangePainter extends _Plane {
  final _Ridge ridge;
  _RangePainter(super.s, this.ridge);

  @override
  void draw(Canvas canvas) {
    final pts = ridge.pts;
    final path = Path()..moveTo(pts.first.dx, s.h + _bleed);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path
      ..lineTo(pts.last.dx, s.h + _bleed)
      ..close();
    _cutPaper(canvas, path, ridge.fill, shadow: ridge.shadow, elevation: ridge.elevation);

    canvas.save();
    canvas.clipPath(path);
    if (ridge.hazeTo != null) {
      canvas.drawRect(
        Rect.fromLTRB(-_bleed, s.h * 0.3, s.w + _bleed, s.h),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, s.h * 0.45), Offset(0, s.h * 0.68), [
            ridge.hazeTo!.withValues(alpha: 0),
            ridge.hazeTo!.withValues(alpha: 0.8),
          ]),
      );
    }
    if (ridge.engrave) {
      final rnd = math.Random(23);
      // Sunlit faces: one continuous wash over every slope that faces the
      // sun, fading downward from the ridge. Shaded slopes get fine engraved
      // strokes falling from the ridge.
      final sunRight = s.sun.dx > s.w * 0.5;
      var lit = Path();
      var minY = double.infinity;
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1], b = pts[i];
        final slope = (b.dy - a.dy) / (b.dx - a.dx);
        final facing = sunRight ? slope > 0.04 : slope < -0.04;
        minY = math.min(minY, a.dy);
        if (facing) {
          final depth = s.h * (0.10 + 0.25 * slope.abs().clamp(0.0, 1.0));
          lit.addPolygon([a, b, b.translate(-depth * 0.25, depth), a.translate(-depth * 0.25, depth)], true);
        } else if (i % 3 == 0 && slope.abs() > 0.1) {
          final len = s.h * (0.02 + rnd.nextDouble() * 0.06);
          canvas.drawLine(
              b.translate(0, 2),
              b.translate(-len * 0.3, 2 + len),
              Paint()
                ..strokeWidth = 0.75
                ..color = NatureColors.forestDeep.withValues(alpha: 0.2));
        }
      }
      canvas.drawPath(
        lit,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, minY), Offset(0, minY + s.h * 0.3), [
            NatureColors.sunlitRock.withValues(alpha: 0.7),
            NatureColors.sunlitRock.withValues(alpha: 0),
          ]),
      );
      // Contour engraving: the ridge line echoed downward.
      for (var k = 1; k <= 5; k++) {
        final line = Path();
        for (var i = 0; i < pts.length; i += 2) {
          final p = pts[i].translate(0, k * s.h * 0.022 + math.sin(i * 0.07 + k) * 1.5);
          i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
            line,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.7
              ..color = NatureColors.forestDeep.withValues(alpha: 0.14 - k * 0.018));
      }
    }
    canvas.restore();

    // Lit ridge edge.
    final edge = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      edge.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = ridge.edgeLight.withValues(alpha: 0.7));
  }
}

class _RockPainter extends _Plane {
  _RockPainter(super.s);

  @override
  void draw(Canvas canvas) {
    final b = s.rock.getBounds();
    _cutPaper(canvas, s.rock, const Color(0xFFC99C86), shadow: NatureColors.forestDeep, elevation: 7);
    canvas.save();
    canvas.clipPath(s.rock);
    // Light from the sun's side, shade on the other; warm reflected light low.
    final sunRight = s.sun.dx > b.center.dx;
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(b.centerLeft, b.centerRight, [
          (sunRight ? const Color(0xFF8E6152) : const Color(0xFFF2CBAA)).withValues(alpha: 0.6),
          const Color(0xFFC99C86).withValues(alpha: 0),
          (sunRight ? const Color(0xFFF2CBAA) : const Color(0xFF8E6152)).withValues(alpha: 0.6),
        ], const [0, 0.5, 1]),
    );
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, b.top), Offset(0, b.bottom), [
          const Color(0xFFF6D9BD).withValues(alpha: 0.35),
          const Color(0xFF7A5446).withValues(alpha: 0.0),
          const Color(0xFF7A5446).withValues(alpha: 0.25),
        ], const [0, 0.5, 1]),
    );
    // Strata that follow the rock's own profile, broken and uneven.
    final rnd = math.Random(77);
    for (var k = 1; k <= 7; k++) {
      final dy = k * b.height * 0.11;
      var pen = false;
      final line = Path();
      for (final pt in s.rockTop) {
        final q = pt.translate(0, dy + math.sin(pt.dx * 0.05 + k) * 1.2);
        if (rnd.nextDouble() < 0.05) pen = false; // natural breaks
        if (!pen) {
          line.moveTo(q.dx, q.dy);
          pen = true;
        } else {
          line.lineTo(q.dx, q.dy);
        }
      }
      canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF7E4E3E).withValues(alpha: 0.3));
    }
    // A few weathering cracks down the spires.
    for (var i = 0; i < 9; i++) {
      final pt = s.rockTop[(rnd.nextDouble() * (s.rockTop.length - 1)).floor()];
      final len = b.height * (0.15 + rnd.nextDouble() * 0.3);
      final path = Path()
        ..moveTo(pt.dx, pt.dy + 3)
        ..quadraticBezierTo(pt.dx + (rnd.nextDouble() - 0.5) * 6, pt.dy + len * 0.5, pt.dx + (rnd.nextDouble() - 0.5) * 4, pt.dy + len);
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF6E4336).withValues(alpha: 0.35));
    }
    canvas.restore();
    // Lit rim along the top.
    final rim = Path();
    for (var i = 0; i < s.rockTop.length; i++) {
      final pt = s.rockTop[i];
      i == 0 ? rim.moveTo(pt.dx, pt.dy) : rim.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = NatureColors.cream.withValues(alpha: 0.7));
  }
}

// ---- Trees -----------------------------------------------------------------------
void _pine(Canvas canvas, Offset base, double height, Color color, math.Random r) {
  final w = height * (0.30 + r.nextDouble() * 0.14);
  final path = Path()..moveTo(base.dx, base.dy - height);
  final tiers = 5 + r.nextInt(3);
  final lean = (r.nextDouble() - 0.5) * height * 0.05;
  // Right side down with jagged branch tips, then left side up.
  final right = <Offset>[], left = <Offset>[];
  for (var i = 1; i <= tiers; i++) {
    final f = i / tiers;
    final y = base.dy - height + f * height * 0.86;
    final spread = w * 0.5 * (0.25 + 0.75 * f) * (0.85 + r.nextDouble() * 0.3);
    right
      ..add(Offset(base.dx + spread + lean * f, y))
      ..add(Offset(base.dx + spread * 0.42 + lean * f, y - height * 0.03));
    final s2 = w * 0.5 * (0.25 + 0.75 * f) * (0.85 + r.nextDouble() * 0.3);
    left
      ..add(Offset(base.dx - s2 + lean * f, y))
      ..add(Offset(base.dx - s2 * 0.42 + lean * f, y - height * 0.03));
  }
  for (final p in right) {
    path.lineTo(p.dx, p.dy);
  }
  path.lineTo(base.dx + w * 0.06, base.dy - height * 0.1);
  path.lineTo(base.dx + w * 0.05, base.dy);
  path.lineTo(base.dx - w * 0.05, base.dy);
  path.lineTo(base.dx - w * 0.06, base.dy - height * 0.1);
  for (final p in left.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

void _broadleaf(Canvas canvas, Offset base, double height, Color color, math.Random r) {
  canvas.drawLine(
      base,
      base.translate(height * 0.04, -height * 0.55),
      Paint()
        ..strokeWidth = height * 0.06
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4A3B32));
  final crown = base.translate(height * 0.04, -height * 0.68);
  for (var i = 0; i < 9; i++) {
    final a = i / 9 * 2 * math.pi;
    final o = Offset(math.cos(a) * height * 0.2, math.sin(a) * height * 0.13);
    canvas.drawCircle(crown + o, height * (0.13 + r.nextDouble() * 0.06), Paint()..color = color);
  }
  canvas.drawCircle(crown, height * 0.2, Paint()..color = color);
  canvas.drawCircle(crown.translate(-height * 0.07, -height * 0.07), height * 0.09,
      Paint()..color = NatureColors.meadow.withValues(alpha: 0.6));
}

class _ForestPainter extends _Plane {
  final bool back;
  _ForestPainter(super.s, {required this.back});

  @override
  void draw(Canvas canvas) {
    final r = math.Random(back ? 21 : 22);
    final u = s.unit;
    final rows = back
        ? [(0.40, 0.62, NatureColors.pineMid, 26.0), (0.80, 1.0, NatureColors.pineMid, 24.0)]
        : [(0.56, 0.74, NatureColors.forest, 36.0), (0.86, 1.05, NatureColors.forest, 40.0)];
    for (final (a, b, color, base) in rows) {
      var x = s.w * a;
      while (x < s.w * b) {
        final ht = base * u * (0.6 + r.nextDouble() * 0.8);
        final y = back ? s.ridgeY(s.middle.pts, x) + s.h * 0.08 : s.groundY(x) + 3;
        // Skip trees standing in the river.
        if (back || (x - s.riverAt(0.1).dx).abs() > s.w * 0.04) {
          _pine(canvas, Offset(x, y), ht, color.withValues(alpha: back ? 0.9 : 1), r);
        }
        x += ht * (0.28 + r.nextDouble() * 0.45);
      }
    }
  }
}

// ---- Valley floor and river -------------------------------------------------------
class _ValleyPainter extends _Plane {
  _ValleyPainter(super.s);

  @override
  void draw(Canvas canvas) {
    _cutPaper(canvas, s.valley, NatureColors.meadow, shadow: NatureColors.forestDeep, elevation: 5);
    canvas.save();
    canvas.clipPath(s.valley);
    // Terrain: soft bands and grass hatching that thickens toward the viewer.
    final r = math.Random(5);
    for (var k = 0; k < 4; k++) {
      final y0 = s.h * (0.74 + k * 0.05);
      final band = Path()..moveTo(-_bleed, y0);
      for (var x = -_bleed; x <= s.w + _bleed; x += 8) {
        band.lineTo(x, y0 + math.sin(x / s.w * 7 + k) * s.h * 0.012);
      }
      canvas.drawPath(
          band,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = NatureColors.forest.withValues(alpha: 0.18));
    }
    final grass = Paint()
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < (s.w * 1.2).round(); i++) {
      final x = r.nextDouble() * s.w;
      final top = s.groundY(x);
      final y = top + r.nextDouble() * (s.h - top);
      final len = 1.5 + (y - top) / (s.h - top) * 5;
      grass.color = NatureColors.forest.withValues(alpha: 0.22 + r.nextDouble() * 0.15);
      canvas.drawLine(Offset(x, y), Offset(x + 0.6, y - len), grass);
    }
    canvas.restore();

    // River: sandy banks, then water reflecting the sky above it.
    canvas.drawPath(
        s.river,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * s.unit
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFD9CBA9));
    canvas.drawPath(
      s.river,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, s.groundY(s.w / 2)), Offset(0, s.h), const [
          Color(0xFFBFD8D4),
          NatureColors.riverBlue,
          Color(0xFF5E8A93),
        ], const [0, 0.45, 1]),
    );
  }
}

class _RiverLightPainter extends _Plane {
  final ValueListenable<double> clock;
  _RiverLightPainter(super.s, this.clock) : super(repaint: clock);

  @override
  void draw(Canvas canvas) {
    final t = clock.value;
    canvas.save();
    canvas.clipPath(s.river);
    // Reflected sun: a broken column of warm light that flickers.
    final r = math.Random(31);
    for (var i = 0; i < 26; i++) {
      final u = i / 26;
      final c = s.riverAt(0.05 + u * 0.9);
      final flick = 0.5 + 0.5 * math.sin(t * 1.3 + i * 1.7);
      final len = s.riverHalfWidth(0.05 + u * 0.9) * (0.25 + r.nextDouble() * 0.5);
      canvas.drawLine(
          c.translate(-len, 0),
          c.translate(len, 0.3),
          Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = NatureColors.sunGlow.withValues(alpha: 0.25 + 0.45 * flick * (1 - u * 0.5)));
    }
    // Shimmer arcs travelling downstream.
    for (var i = 0; i < 14; i++) {
      final u = ((i / 14) + t * 0.018) % 1.0;
      final c = s.riverAt(u);
      final hw = s.riverHalfWidth(u);
      final off = (math.sin(i * 2.3) * 0.6) * hw;
      canvas.drawArc(
          Rect.fromCenter(center: c.translate(off, 0), width: hw * 0.5, height: hw * 0.08 + 1),
          math.pi,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = NatureColors.paper.withValues(alpha: 0.55 * math.sin(u * math.pi)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Plane old) => true;
}

// ---- Foreground bank ----------------------------------------------------------------
class _ForegroundPainter extends _Plane {
  _ForegroundPainter(super.s);

  @override
  void draw(Canvas canvas) {
    _cutPaper(canvas, s.foreground, NatureColors.forest,
        shadow: NatureColors.ink, elevation: 9, edge: NatureColors.meadow);
    canvas.save();
    canvas.clipPath(s.foreground);
    canvas.drawRect(
      Rect.fromLTRB(-_bleed, s.h * 0.75, s.w + _bleed, s.h + _bleed),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, s.h * 0.8), Offset(0, s.h), [
          NatureColors.forest.withValues(alpha: 0),
          NatureColors.forestDeep.withValues(alpha: 0.85),
        ]),
    );
    canvas.restore();
    final r = math.Random(55);
    final u = s.unit;
    // Framing trees: tall pines cropped by the left edge, one broadleaf.
    _pine(canvas, Offset(s.w * 0.02, s.foreY(s.w * 0.02) + 6), 150 * u, NatureColors.forestDeep, r);
    _pine(canvas, Offset(s.w * 0.075, s.foreY(s.w * 0.075) + 4), 112 * u, NatureColors.forestDeep, r);
    _broadleaf(canvas, Offset(s.w * 0.93, s.foreY(s.w * 0.93) + 4), 105 * u, const Color(0xFF4C6E5C), r);
  }
}

// ---- Plants (sway individually) ------------------------------------------------------
class _Stem {
  final Offset base;
  final double height, phase, period;
  final Color? flower;
  final bool leafy;
  _Stem(this.base, this.height, this.phase, this.period, this.flower, this.leafy);
}

class _PlantsPainter extends _Plane {
  final ValueListenable<double> clock;
  late final List<_Stem> stems = _build();
  _PlantsPainter(super.s, this.clock) : super(repaint: clock);

  List<_Stem> _build() {
    final r = math.Random(13);
    final out = <_Stem>[];
    final u = s.unit;
    // Tall grasses along the foreground edge.
    for (var x = 0.0; x < s.w; x += 5 + r.nextDouble() * 7) {
      final y = s.foreY(x) + 2 + r.nextDouble() * 6;
      out.add(_Stem(Offset(x, y), (10 + r.nextDouble() * 16) * u, r.nextDouble() * 6,
          3 + r.nextDouble() * 2.5, null, false));
    }
    // Wildflowers in colour groups (coral, ochre, cream), not random dots.
    final groups = [
      (0.70, NatureColors.dustyCoral, 9),
      (0.80, NatureColors.sunOchre, 6),
      (0.88, NatureColors.cream, 7),
      (0.16, NatureColors.dustyCoral, 6),
      (0.24, NatureColors.cream, 5),
    ];
    for (final (cx, color, n) in groups) {
      for (var i = 0; i < n; i++) {
        final x = s.w * cx + (r.nextDouble() - 0.5) * s.w * 0.07;
        final y = s.foreY(x) + 4 + r.nextDouble() * s.h * 0.06;
        out.add(_Stem(Offset(x, y), (16 + r.nextDouble() * 18) * u, r.nextDouble() * 6,
            3.5 + r.nextDouble() * 2.5, color, true));
      }
    }
    return out;
  }

  @override
  void draw(Canvas canvas) {
    final t = clock.value;
    final grass = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (final st in stems) {
      final sway = math.sin(t * 2 * math.pi / st.period + st.phase) * st.height * 0.12;
      final tip = st.base.translate(sway, -st.height);
      final ctrl = st.base.translate(sway * 0.2, -st.height * 0.55);
      grass.color = st.flower == null ? NatureColors.meadow : const Color(0xFF6E9178);
      canvas.drawPath(
          Path()
            ..moveTo(st.base.dx, st.base.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
          grass);
      if (st.leafy) {
        final leaf = st.base.translate(sway * 0.3, -st.height * 0.4);
        canvas.drawOval(Rect.fromCenter(center: leaf.translate(3, 0), width: 6, height: 2.6),
            Paint()..color = const Color(0xFF6E9178));
      }
      if (st.flower != null) {
        final pr = 2.1 * s.unit.clamp(0.8, 1.6);
        for (var k = 0; k < 5; k++) {
          final a = k / 5 * 2 * math.pi + st.phase;
          canvas.drawCircle(tip + Offset(math.cos(a), math.sin(a)) * pr, pr * 0.9, Paint()..color = st.flower!);
        }
        canvas.drawCircle(tip, pr * 0.6, Paint()..color = NatureColors.ochreInk);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Plane old) => true;
}

// ---- Birds: a flock crosses every ~34 s ------------------------------------------------
class _BirdsPainter extends _Plane {
  final ValueListenable<double> clock;
  _BirdsPainter(super.s, this.clock) : super(repaint: clock);

  static const double cycle = 34, crossing = 16;

  @override
  void draw(Canvas canvas) {
    final t = clock.value;
    final local = (t + 6) % cycle; // first pass starts soon after opening
    if (local > crossing) return;
    final p = local / crossing;
    final lead = Offset(-s.w * 0.12 + p * s.w * 1.3, s.h * (0.20 - 0.06 * p) + math.sin(p * 5) * s.h * 0.01);
    const offsets = [Offset(0, 0), Offset(-22, 9), Offset(-40, -6), Offset(-58, 13), Offset(-74, 2)];
    final k = s.unit.clamp(0.8, 1.5);
    final size = 6.5 * k;
    for (var i = 0; i < offsets.length; i++) {
      final c = lead + offsets[i] * k + Offset(0, math.sin(t * 1.1 + i) * 2);
      final flap = math.sin(t * 2 * math.pi * (1.5 + i * 0.07) + i * 1.3);
      final wy = -size * (0.25 + 0.45 * flap);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - size, c.dy + wy * 0.4)
          ..quadraticBezierTo(c.dx - size * 0.45, c.dy + wy, c.dx, c.dy)
          ..quadraticBezierTo(c.dx + size * 0.45, c.dy + wy, c.dx + size, c.dy + wy * 0.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = NatureColors.ink.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Plane old) => true;
}

// ---- Grain --------------------------------------------------------------------------------
class _GrainPainter extends CustomPainter {
  final _Scene s;
  _GrainPainter(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(11);
    final dark = List.generate((size.width * size.height / 60).round(),
        (_) => Offset(r.nextDouble() * size.width, r.nextDouble() * size.height));
    canvas.drawPoints(
        ui.PointMode.points,
        dark,
        Paint()
          ..color = NatureColors.ink.withValues(alpha: 0.05)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round);
    final light = List.generate((size.width * size.height / 120).round(),
        (_) => Offset(r.nextDouble() * size.width, r.nextDouble() * size.height));
    canvas.drawPoints(
        ui.PointMode.points,
        light,
        Paint()
          ..color = NatureColors.paper.withValues(alpha: 0.2)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.s != s;
}
