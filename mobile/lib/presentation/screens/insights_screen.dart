import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_chips.dart';
import '../widgets/sense_charts.dart';
import '../widgets/sense_navigation.dart';
import 'insight_detail_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _selectedPeriod = 'Week';
  final List<String> _periods = ['Day', 'Week', 'Month'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Longitudinal Insights',
          style: SenseTypography.h3.copyWith(
            color: SenseColors.navy900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Selector Tabs (Day, Week, Month)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SenseColors.white,
                  borderRadius: SenseRadii.pillBorder,
                  border: Border.all(color: SenseColors.border, width: 1.0),
                ),
                child: Row(
                  children: _periods.map((p) {
                    final isSel = (_selectedPeriod == p);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPeriod = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? SenseColors.navy900 : Colors.transparent,
                            borderRadius: SenseRadii.pillBorder,
                          ),
                          child: Text(
                            p,
                            style: SenseTypography.captionMedium.copyWith(
                              color: isSel ? SenseColors.white : SenseColors.textSecondary,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Spline Trend Chart (Matching UI Toolkit Board)
              SenseSplineTrendChart(
                values: const [2.8, 3.2, 3.0, 3.4, 2.9, 2.4, 2.2],
                title: 'Stress Trend',
                metricDelta: '↓ 18%',
                subtitle: 'Lower than yesterday',
                isDeltaPositive: true,
              ),
              const SizedBox(height: 18),

              // 2-Column Row: Weekly Bar Chart + Donut Sleep Quality (Matching UI Toolkit Board)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SenseWeeklyBarChart(
                      dayFractions: const [0.35, 0.45, 0.65, 0.50, 0.70, 0.85, 0.40],
                      title: 'Weekly Stress',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    flex: 2,
                    child: SenseDonutQualityChart(
                      percentage: 72,
                      label: 'Sleep Quality',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Factor Attribution Breakdown
              SenseCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InsightDetailScreen(
                        observationTitle: 'Multimodal Attribution Breakdown',
                        primaryFactor: 'Sleep Regularity (+42% impact)',
                        evidenceSummary:
                            'Across the past 7 days, deviations in sleep consistency and bedtime regularity account for 42% of the variance in your evening stress self-reports, followed by task deadlines (28%).',
                        timeRange: 'Oct 24 - Oct 30, 2026',
                        whatCannotConclude:
                            'This decomposition represents statistical variance attribution in our late decision fusion model, not a medical causality proof.',
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Key Contributing Factors',
                          style: SenseTypography.labelBold.copyWith(
                            color: SenseColors.navy900,
                            fontSize: 14,
                          ),
                        ),
                        const SenseProvenanceBadge(text: 'Late Fusion Model'),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildFactorBar('Sleep Regularity & Rest', 0.42, SenseColors.blue600),
                    const SizedBox(height: 10),
                    _buildFactorBar('Task Volume & Deadlines', 0.28, SenseColors.cyan500),
                    const SizedBox(height: 10),
                    _buildFactorBar('Subjective Check-in Shift', 0.18, const Color(0xFF60A5FA)),
                    const SizedBox(height: 10),
                    _buildFactorBar('Journal Affective Tone', 0.12, SenseColors.cyan300),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tap for full scientific breakdown',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.blue600,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16, color: SenseColors.blue600),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFactorBar(String label, double fraction, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: SenseTypography.caption.copyWith(color: SenseColors.textPrimary)),
            Text('${(fraction * 100).toInt()}%',
                style: SenseTypography.caption.copyWith(
                    fontWeight: FontWeight.w700, color: SenseColors.navy900)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE2F2FC),
            borderRadius: SenseRadii.pillBorder,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: SenseRadii.pillBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

