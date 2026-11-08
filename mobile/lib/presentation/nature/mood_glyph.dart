import 'package:flutter/widgets.dart';

import 'mood_glyph_data.dart';

/// One of the five approved Living Landscapes mood symbols, drawn in code
/// from `mood_glyph_data.dart` (generated from the SVG originals in
/// `docs/redesign/mood-symbols/`).
///
/// [value] is the existing check-in mood value (1 Very Low ... 5 Great).
/// The symbol is decorative: the control that hosts it carries the name.
class MoodGlyph extends StatelessWidget {
  final int value;
  final double size;
  const MoodGlyph({super.key, required this.value, this.size = 40})
      : assert(value >= 1 && value <= 5);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: MoodGlyphPainter(value),
        ),
      ),
    );
  }
}

class MoodGlyphPainter extends CustomPainter {
  final int value;
  MoodGlyphPainter(this.value);

  static final Map<String, Path> _cache = {};
  static Path _path(String d) => _cache.putIfAbsent(d, () => parseSvgPath(d));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    for (final l in moodGlyphLayers[value]!) {
      final path = _path(l.path);
      canvas.save();
      if (l.clip != null) canvas.clipPath(_path(l.clip!));
      canvas.translate(l.dx, l.dy);
      if (l.fill != null) {
        canvas.drawPath(
            path,
            Paint()
              ..isAntiAlias = true
              ..color = l.fill!.withValues(alpha: l.opacity));
      }
      if (l.stroke != null) {
        canvas.drawPath(
            path,
            Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeWidth = l.strokeWidth
              ..strokeCap = l.roundCap ? StrokeCap.round : StrokeCap.butt
              ..strokeJoin = l.roundJoin ? StrokeJoin.round : StrokeJoin.miter
              ..color = l.stroke!.withValues(alpha: l.opacity));
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MoodGlyphPainter old) => old.value != value;
}

/// Parses the SVG path subset used by the mood symbols: M m L l C c Q q Z z,
/// with implicit repeats, plus `circle:cx,cy,r`.
Path parseSvgPath(String d) {
  final path = Path();
  if (d.startsWith('circle:')) {
    final v = d.substring(7).split(',').map(double.parse).toList();
    return path..addOval(Rect.fromCircle(center: Offset(v[0], v[1]), radius: v[2]));
  }
  final tokens = RegExp(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() {
    if (i >= tokens.length || isCmd(tokens[i])) {
      throw FormatException('Truncated SVG path data: $d');
    }
    return double.parse(tokens[i++]);
  }
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        sx = x;
        sy = y;
        path.moveTo(x, y);
        cmd = rel ? 'l' : 'L'; // implicit lineto after the first pair
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        cmd = ''; // a number straight after Z is malformed
      default:
        throw FormatException('Unsupported SVG path command "$cmd" in: $d');
    }
  }
  return path;
}
