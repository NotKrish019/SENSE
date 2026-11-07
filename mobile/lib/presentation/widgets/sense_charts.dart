import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sense_card.dart';
import 'sense_chips.dart';

/// Smooth Spline Trend Chart matching the SENSE UI Toolkit Board
class SenseSplineTrendChart extends StatelessWidget {
  final List<double> values;
  final String title;
  final String subtitle;
  /// Optional change label. Empty hides it: only show a computed change.
  final String metricDelta;
  final bool isDeltaPositive;
  /// Shows the shared "Sample data" badge for illustrative values.
  final bool isSampleData;

  const SenseSplineTrendChart({
    super.key,
    required this.values,
    this.title = 'Stress Trend',
    this.subtitle = '',
    this.metricDelta = '',
    this.isDeltaPositive = true,
    this.isSampleData = false,
  });

  @override
  Widget build(BuildContext context) {
    return SenseCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity, // lets spaceBetween reach the right edge
            child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SenseTypography.h3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SenseColors.navy900,
                    ),
                  ),
                  if (metricDelta.isNotEmpty || subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (metricDelta.isNotEmpty)
                      Text(
                        metricDelta,
                        style: SenseTypography.labelBold.copyWith(
                          color: isDeltaPositive ? SenseColors.success : SenseColors.warning,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: SenseTypography.caption.copyWith(
                          color: SenseColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
              if (isSampleData) const SenseProvenanceBadge.sampleData(),
            ],
          ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _SplineChartPainter(values: values),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplineChartPainter extends CustomPainter {
  final List<double> values;

  _SplineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final double minVal = values.reduce(math.min);
    final double maxVal = values.reduce(math.max);
    final double range = (maxVal - minVal).clamp(0.001, 100.0);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minVal) / range;
      final y = size.height - (normalized * (size.height - 20) + 10);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Gradient fill below the curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4D07CCFC), Color(0x05E6F6FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Spline stroke
    final strokePaint = Paint()
      ..color = SenseColors.cyan500
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Endpoint dot with white core
    final lastPoint = points.last;
    canvas.drawCircle(
      lastPoint,
      5.0,
      Paint()..color = SenseColors.blue600,
    );
    canvas.drawCircle(
      lastPoint,
      2.5,
      Paint()..color = SenseColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) => true;
}

/// Mon-Sun Weekly Bar Chart matching the SENSE UI Toolkit Board
class SenseWeeklyBarChart extends StatelessWidget {
  final List<double> dayFractions; // 7 values for Mon-Sun (0.0 to 1.0)
  final String title;
  final bool isSampleData;

  const SenseWeeklyBarChart({
    super.key,
    required this.dayFractions,
    this.title = 'Weekly Stress',
    this.isSampleData = false,
  });

  /// Weekday label style: used both to draw and to measure the labels.
  /// Letter spacing is set explicitly so the theme's body letter spacing
  /// (0.25) is not inherited.
  static TextStyle _dayLabelStyle(bool isToday) => SenseTypography.caption.copyWith(
        fontSize: 11,
        letterSpacing: 0,
        color: isToday ? SenseColors.navy900 : SenseColors.textSecondary,
        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
      );

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return SenseCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SenseTypography.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SenseColors.navy900,
            ),
          ),
          if (isSampleData) ...[
            const SizedBox(height: 6),
            const SenseProvenanceBadge.sampleData(),
          ],
          const SizedBox(height: 18),
          // Each day gets an equal slot. If any 3-letter label does not fit its
          // slot at the current text size, single letters (M T W …) are shown
          // at full size instead of squeezing words together; every bar is
          // still announced with its full day name. Each label is measured in
          // the font and weight it is actually drawn with (bundled Poppins;
          // only "today" is bold).
          LayoutBuilder(builder: (context, constraints) {
            final textScaler = MediaQuery.textScalerOf(context);
            final slot = constraints.maxWidth / 7;
            var compact = false;
            for (var i = 0; i < days.length && !compact; i++) {
              final painter = TextPainter(
                text: TextSpan(
                    text: days[i],
                    style: DefaultTextStyle.of(context).style.merge(_dayLabelStyle(i == 4))),
                textScaler: textScaler,
                textDirection: TextDirection.ltr,
                maxLines: 1,
              )..layout();
              compact = painter.width > slot;
              painter.dispose();
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final frac = i < dayFractions.length ? dayFractions[i] : 0.4;
                final isToday = (i == 4); // Friday
                return Expanded(
                  child: Semantics(
                    label: isSampleData
                        ? '${fullDays[i]}, sample bar'
                        : fullDays[i],
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 65,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 14,
                              height: (frac * 65).clamp(10.0, 65.0),
                              decoration: BoxDecoration(
                                color: isToday ? SenseColors.blue600 : SenseColors.cyan300,
                                borderRadius: SenseRadii.smBorder,
                                gradient: isToday ? SenseColors.primaryActionGradient : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          compact ? days[i].substring(0, 1) : days[i],
                          maxLines: 1,
                          softWrap: false,
                          style: _dayLabelStyle(isToday),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

/// Circular Progress Donut Chart matching the SENSE UI Toolkit Board
class SenseDonutQualityChart extends StatelessWidget {
  final int percentage;
  final String label;
  /// Overrides the centre text (default "$percentage%"), e.g. "4 / 5" for a
  /// self-reported rating. Never present an uncomputed score as a percentage.
  final String? centerText;
  final bool isSampleData;

  const SenseDonutQualityChart({
    super.key,
    required this.percentage,
    this.label = 'Sleep Quality',
    this.centerText,
    this.isSampleData = false,
  });

  @override
  Widget build(BuildContext context) {
    return SenseCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(76, 76),
                  painter: _DonutChartPainter(percentage: percentage),
                ),
                Text(
                  centerText ?? '$percentage%',
                  style: SenseTypography.labelBold.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SenseColors.navy900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: SenseTypography.captionMedium.copyWith(
              color: SenseColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (isSampleData) ...[
            const SizedBox(height: 6),
            const SenseProvenanceBadge.sampleData(),
          ],
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final int percentage;

  _DonutChartPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Track circle
    final trackPaint = Paint()
      ..color = const Color(0xFFD6EFFC)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    final progressPaint = Paint()
      ..color = SenseColors.blue600
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (percentage / 100.0) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

