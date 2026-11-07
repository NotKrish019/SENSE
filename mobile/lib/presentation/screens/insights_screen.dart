import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_tappable.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_charts.dart';
import '../widgets/sense_navigation.dart';
import '../widgets/sample_data_banner.dart';

class InsightsScreen extends StatefulWidget {
  /// True when shown as a bottom-navigation tab (no back arrow).
  final bool isTabRoot;

  const InsightsScreen({super.key, this.isTabRoot = false});

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
        automaticallyImplyLeading: !widget.isTabRoot,
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
              // Every value on this screen is illustrative until real data is saved.
              const SenseSampleDataBanner(
                message:
                    'All charts on this screen are illustrative examples of how '
                    'SENSE may display your history. They are not your recorded '
                    'data, and the Day / Week / Month options do not change them yet.',
              ),
              const SizedBox(height: 16),

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
                      child: SenseTappable(
                        semanticLabel: '$p view',
                        semanticHint: 'Sample charts do not change yet',
                        selected: isSel,
                        onTap: () => setState(() => _selectedPeriod = p),
                        borderRadius: SenseRadii.pillBorder,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          // 48 px minimum touch target (was ~33 px).
                          constraints: const BoxConstraints(minHeight: 48),
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
              const SenseSplineTrendChart(
                values: [2.8, 3.2, 3.0, 3.4, 2.9, 2.4, 2.2],
                title: 'Self-reported stress',
                subtitle: 'Example 7-day trend',
                isSampleData: true,
              ),
              const SizedBox(height: 18),

              // Bar chart + donut side by side on roomy screens; stacked when the
              // screen is narrow or text is large, so neither card overflows.
              LayoutBuilder(
                builder: (context, constraints) {
                  const bars = SenseWeeklyBarChart(
                    dayFractions: [0.35, 0.45, 0.65, 0.50, 0.70, 0.85, 0.40],
                    title: 'Self-reported stress by day',
                    isSampleData: true,
                  );
                  const donut = SenseDonutQualityChart(
                    percentage: 80,
                    centerText: '4 / 5',
                    label: 'Self-reported rest quality',
                    isSampleData: true,
                  );
                  final stack = constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(1.0) > 1.15;
                  if (stack) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [bars, SizedBox(height: 12), donut],
                    );
                  }
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: bars),
                      SizedBox(width: 12),
                      Expanded(flex: 2, child: donut),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Factor comparison: not implemented, so show an honest empty state
              // instead of invented attribution percentages.
              SenseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_empty_rounded,
                            color: SenseColors.blue800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Factor comparison — not available yet',
                            style: SenseTypography.labelBold.copyWith(
                              color: SenseColors.navy900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'SENSE does not yet estimate how sleep, workload, check-ins '
                      'or journal entries relate to your reported stress. That '
                      'needs several weeks of saved data and a method that has '
                      'been tested in the research phase.',
                      style: SenseTypography.caption.copyWith(
                        color: SenseColors.textSecondary,
                        height: 1.45,
                      ),
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
}
