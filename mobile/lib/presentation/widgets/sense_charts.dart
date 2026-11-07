import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sense_card.dart';

/// Smooth Spline Trend Chart matching the SENSE UI Toolkit Board
class SenseSplineTrendChart extends StatelessWidget {
  final List<double> values;
  final String title;
  final String subtitle;
  final String metricDelta;
  final bool isDeltaPositive;

  const SenseSplineTrendChart({
    super.key,
    required this.values,
    this.title = 'Stress Trend',
    this.subtitle = 'Lower than yesterday',
    this.metricDelta = '↓ 18%',
    this.isDeltaPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return SenseCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        metricDelta,
                        style: SenseTypography.labelBold.copyWith(
                          color: isDeltaPositive ? SenseColors.success : SenseColors.warning,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        subtitle,
                        style: SenseTypography.caption.copyWith(
                          color: SenseColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
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

  const SenseWeeklyBarChart({
    super.key,
    required this.dayFractions,
    this.title = 'Weekly Stress',
  });

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
          const SizedBox(height: 18),
          SizedBox(
            height: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final frac = i < dayFractions.length ? dayFractions[i] : 0.4;
                final isToday = (i == 4); // Friday
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 14,
                      height: (frac * 65).clamp(10.0, 65.0),
                      decoration: BoxDecoration(
                        color: isToday ? SenseColors.blue600 : SenseColors.cyan300,
                        borderRadius: SenseRadii.smBorder,
                        gradient: isToday ? SenseColors.primaryActionGradient : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: SenseTypography.caption.copyWith(
                        fontSize: 11,
                        color: isToday ? SenseColors.navy900 : SenseColors.textSecondary,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular Progress Donut Chart matching the SENSE UI Toolkit Board
class SenseDonutQualityChart extends StatelessWidget {
  final int percentage;
  final String label;

  const SenseDonutQualityChart({
    super.key,
    this.percentage = 72,
    this.label = 'Sleep Quality',
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
                  '$percentage%',
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

