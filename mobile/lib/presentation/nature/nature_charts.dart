// Living Landscapes design system: PRODUCTION code (Phase 2).
//
// Calm, editorial charts for Insights: muted forest and sky marks, readable
// labels, a sample-data tag and a spoken description for every chart. They
// draw only the values they are given; nothing here computes analytics.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_tappable.dart';
import 'nature_widgets.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Chart title, optional subtitle and the sample-data tag.
class NatureChartHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSampleData;
  const NatureChartHeader({super.key, required this.title, this.subtitle, this.isSampleData = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: NatureType.label.copyWith(fontWeight: FontWeight.w600)),
        ),
        if (isSampleData) const NatureSampleTag(),
        if (subtitle != null)
          SizedBox(
            width: double.infinity,
            child: Text(subtitle!, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
          ),
      ],
    );
  }
}

/// Weekday label helpers: Mon…Sun when every label fits its slot at the
/// current text size, otherwise single letters at full size (never shrunk or
/// clipped).
abstract final class _DayLabels {
  static TextStyle style(bool strong) => TextStyle(
        fontFamily: NatureType.family,
        fontSize: 12,
        height: 1.2,
        letterSpacing: 0,
        color: strong ? NatureColors.ink : NatureColors.inkMuted,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
      );

  static bool compact(BuildContext context, double width) {
    final textScaler = MediaQuery.textScalerOf(context);
    final slot = width / 7;
    for (var i = 0; i < 7; i++) {
      final tp = TextPainter(
        text: TextSpan(text: _days[i], style: style(true)),
        textScaler: textScaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final wide = tp.width > slot;
      tp.dispose();
      if (wide) return true;
    }
    return false;
  }
}

/// A smooth line over seven days, on faint ruled lines.
class NatureTrendChart extends StatelessWidget {
  final List<double> values;
  final String title;
  final String? subtitle;
  final bool isSampleData;

  /// Spoken description of the chart (screen readers).
  final String description;

  const NatureTrendChart({
    super.key,
    required this.values,
    required this.title,
    required this.description,
    this.subtitle,
    this.isSampleData = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NatureChartHeader(title: title, subtitle: subtitle, isSampleData: isSampleData),
        const SizedBox(height: 14),
        Semantics(
          label: description,
          image: true,
          excludeSemantics: true,
          child: Column(
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(values)),
              ),
              const SizedBox(height: 8),
              // The line runs Monday to Sunday; the bar chart below labels
              // each day.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text('Monday', style: _DayLabels.style(false)),
                    Text('Sunday', style: _DayLabels.style(false)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  _TrendPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    // Ruled lines, like the journal paper.
    final rule = Paint()
      ..color = NatureColors.divider
      ..strokeWidth = 1;
    for (var k = 0; k < 4; k++) {
      final y = 6 + k * (size.height - 12) / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final range = (hi - lo).clamp(0.001, 100.0);
    // One point in the middle of each day's slot (matches the labels).
    final slot = size.width / values.length;
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(slot * (i + 0.5), size.height - 12 - (values[i] - lo) / range * (size.height - 28)),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = NatureColors.eucalyptus.withValues(alpha: 0.28));
    // Off-register ochre plate under the forest line (printmaking detail).
    canvas.drawPath(
        line.shift(const Offset(1.2, 1.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = NatureColors.sunOchre.withValues(alpha: 0.55));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = NatureColors.forest);
    for (final p in pts) {
      canvas.drawCircle(p, 3.2, Paint()..color = NatureColors.paper);
      canvas.drawCircle(
          p,
          3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = NatureColors.forest);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values;
}

/// Seven bars, one per weekday. Each bar is announced with its full day name
/// ("Wednesday, sample bar" for sample data).
class NatureWeekBars extends StatelessWidget {
  final List<double> dayFractions; // Mon..Sun, 0..1
  final String title;
  final String? subtitle;
  final bool isSampleData;

  /// Day drawn as "today" (darker bar, heavier label); Friday in the sample.
  final int highlight;

  const NatureWeekBars({
    super.key,
    required this.dayFractions,
    required this.title,
    this.subtitle,
    this.isSampleData = false,
    this.highlight = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NatureChartHeader(title: title, subtitle: subtitle, isSampleData: isSampleData),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final short = _DayLabels.compact(context, c.maxWidth);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Semantics(
                    label: isSampleData ? '${_fullDays[i]}, sample bar' : _fullDays[i],
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 72,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _Bar(
                              fraction: i < dayFractions.length ? dayFractions[i] : 0.4,
                              strong: i == highlight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          short ? _days[i].substring(0, 1) : _days[i],
                          maxLines: 1,
                          softWrap: false,
                          style: _DayLabels.style(i == highlight),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final bool strong;
  const _Bar({required this.fraction, required this.strong});

  @override
  Widget build(BuildContext context) {
    final h = (fraction * 72).clamp(10.0, 72.0);
    return SizedBox(
      width: 18,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Off-register plate.
          Positioned(
            left: 1.5,
            top: 1.5,
            right: -1.5,
            bottom: -1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: strong ? NatureColors.sunOchre : NatureColors.eucalyptus.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: strong ? NatureColors.forest : NatureColors.riverBlue,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rating out of five drawn as a ring, with the rating as text.
class NatureRatingRing extends StatelessWidget {
  final int rating; // 0..5
  final String label;
  final bool isSampleData;
  const NatureRatingRing({super.key, required this.rating, required this.label, this.isSampleData = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NatureChartHeader(title: label, isSampleData: isSampleData),
        const SizedBox(height: 14),
        Semantics(
          label: '$label: $rating of 5${isSampleData ? ', sample data' : ''}',
          image: true,
          excludeSemantics: true,
          child: SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: const Size.square(92), painter: _RingPainter(rating / 5)),
                Text('$rating / 5',
                    style: NatureType.label.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  _RingPainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = NatureColors.border);
    final arc = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        arc.shift(const Offset(1.2, 1.4)),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = NatureColors.sunOchre.withValues(alpha: 0.6));
    canvas.drawArc(
        arc,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = NatureColors.forest);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// Day / Week / Month selector. Each option is a selectable button announced
/// as "Week view" with its selected state; the selected one is filled forest
/// with a heavier label (not colour alone).
class NaturePeriodSelector extends StatelessWidget {
  final List<String> periods;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? hint;
  const NaturePeriodSelector({
    super.key,
    required this.periods,
    required this.selected,
    required this.onSelected,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NatureColors.paper,
        borderRadius: NatureRadii.mdBorder,
        border: Border.all(color: NatureColors.borderStrong),
      ),
      child: Row(
        children: [
          for (final p in periods)
            Expanded(
              child: SenseTappable(
                semanticLabel: '$p view',
                semanticHint: hint,
                selected: p == selected,
                focusColor: NatureColors.focus,
                hoverColor: NatureColors.hover,
                borderRadius: NatureRadii.smBorder,
                onTap: () => onSelected(p),
                child: AnimatedContainer(
                  duration: still ? Duration.zero : NatureMotion.selection,
                  curve: NatureMotion.ease,
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: p == selected ? NatureColors.forest : Colors.transparent,
                    borderRadius: NatureRadii.smBorder,
                  ),
                  child: Text(
                    p,
                    maxLines: 1,
                    style: NatureType.label.copyWith(
                      fontSize: 14,
                      color: p == selected ? NatureColors.primaryForeground : NatureColors.inkMuted,
                      fontWeight: p == selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
