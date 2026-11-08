import 'package:flutter/material.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/meadow_band.dart';
import '../nature/nature_charts.dart';
import '../nature/nature_widgets.dart';

/// Production Insights (Living Landscapes, Phase 2).
///
/// A calm, editorial page of SAMPLE charts showing how SENSE may display a
/// person's own history once saving is connected. Nothing here is computed
/// from user data: there is none yet. The Day / Week / Month selector is kept
/// and is honest that the sample charts do not change. No scores, risk levels
/// or diagnostic language.
class InsightsScreen extends StatefulWidget {
  /// True when shown as a navigation tab (no back control).
  final bool isTabRoot;

  const InsightsScreen({super.key, this.isTabRoot = false});

  /// The sample-data notice (unchanged wording).
  static const String sampleNotice =
      'All charts on this screen are illustrative examples of how '
      'SENSE may display your history. They are not your recorded '
      'data, and the Day / Week / Month options do not change them yet.';

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _selectedPeriod = 'Week';
  final List<String> _periods = ['Day', 'Week', 'Month'];
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: widget.isTabRoot ? null : () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          maxSheetWidth: 880,
          band: (desktop) => MeadowBand(seed: 3, sunX: desktop ? 0.88 : 0.76, tornBottom: desktop),
          child: _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    const trend = NatureTrendChart(
      values: [2.8, 3.2, 3.0, 3.4, 2.9, 2.4, 2.2],
      title: 'Self-reported stress',
      subtitle: 'Example 7-day trend. Each point would be one day of check-in ratings.',
      description: 'Sample line chart: an invented week of self-reported stress, a little '
          'higher midweek and lower towards Sunday. Not your data.',
      isSampleData: true,
    );
    const bars = NatureWeekBars(
      dayFractions: [0.35, 0.45, 0.65, 0.50, 0.70, 0.85, 0.40],
      title: 'Self-reported stress by day',
      subtitle: 'The darker bar marks Friday in this example.',
      isSampleData: true,
    );
    const ring = NatureRatingRing(rating: 4, label: 'Self-reported rest quality', isSampleData: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Insights', style: NatureType.eyebrow),
        const SizedBox(height: 8),
        const NatureHeading('Longitudinal insights'),
        const SizedBox(height: 8),
        const Text(
          'A place to look back over your own ratings, once saving is connected. '
          'Patterns here would compare you only with your own history.',
          style: NatureType.bodyMuted,
        ),
        const SizedBox(height: 20),
        const NatureMarginNote(eyebrow: PrototypeCopy.sampleDataTitle, text: InsightsScreen.sampleNotice),
        const SizedBox(height: 22),
        NaturePeriodSelector(
          periods: _periods,
          selected: _selectedPeriod,
          hint: 'Sample charts do not change yet',
          onSelected: (p) => setState(() => _selectedPeriod = p),
        ),
        const SizedBox(height: 26),
        trend,
        const SizedBox(height: 26),
        const Divider(height: 1, thickness: 1, color: NatureColors.divider),
        const SizedBox(height: 22),
        // Bars and the rest rating side by side when there is room; stacked
        // on narrow screens or with large text.
        LayoutBuilder(builder: (context, c) {
          final stack = c.maxWidth < 520 || MediaQuery.textScalerOf(context).scale(1) > 1.15;
          if (stack) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bars,
                SizedBox(height: 26),
                Divider(height: 1, thickness: 1, color: NatureColors.divider),
                SizedBox(height: 22),
                ring,
              ],
            );
          }
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: bars),
              SizedBox(width: 36),
              Expanded(flex: 2, child: ring),
            ],
          );
        }),
        const SizedBox(height: 28),
        const SprigRule(),
        const SizedBox(height: 24),
        // Factor comparison is not implemented: an honest note instead of
        // invented attribution percentages.
        const NatureMarginNote(
          eyebrow: 'Factor comparison: not available yet',
          text: 'SENSE does not yet estimate how sleep, workload, check-ins or journal '
              'entries relate to your reported stress. That needs several weeks of saved '
              'data and a method that has been tested in the research phase.',
        ),
        const SizedBox(height: 18),
        Text(PrototypeCopy.noCausalClaim, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
      ],
    );
  }
}
