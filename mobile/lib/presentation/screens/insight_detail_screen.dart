import 'package:flutter/material.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/meadow_band.dart';
import '../nature/nature_editorial.dart';
import '../nature/nature_home_sections.dart' show NaturePrintedIconWell;
import '../nature/nature_widgets.dart';

/// Production Insight detail (Living Landscapes, Phase 2).
///
/// An editorial explanation of one observation. It keeps five ideas visibly
/// apart: this is a SAMPLE observation; two indicators changing together is a
/// CORRELATION; that is not CAUSATION; real observations need a PERSONAL
/// BASELINE; and what is NOT BUILT yet. Non-clinical throughout.
class InsightDetailScreen extends StatefulWidget {
  final String observationTitle;
  final String primaryFactor;
  final String evidenceSummary;
  final String timeRange;
  final String whatCannotConclude;

  /// True while the observation is an illustrative example rather than one
  /// computed from the user's saved data (always true in this prototype).
  final bool isSampleData;

  const InsightDetailScreen({
    super.key,
    this.observationTitle = 'Sleep and stress changed in the same week',
    this.primaryFactor = 'Recorded sleep duration · Self-reported stress',
    this.evidenceSummary =
        'In this example, recorded sleep duration was longer and self-reported '
        'stress was lower during the same week. The two changed together; this '
        'does not show that one caused the other.',
    this.timeRange = 'Example week',
    this.whatCannotConclude =
        '${PrototypeCopy.noCausalClaim} SENSE does not yet produce observations '
        'from your own data.',
    this.isSampleData = true,
  });

  @override
  State<InsightDetailScreen> createState() => _InsightDetailScreenState();
}

class _InsightDetailScreenState extends State<InsightDetailScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          band: (desktop) => MeadowBand(seed: 7, sunX: desktop ? 0.12 : 0.24, tornBottom: desktop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (w.isSampleData) const NatureSampleTag(),
                  Text(w.timeRange, style: NatureType.eyebrow),
                ],
              ),
              const SizedBox(height: 10),
              NatureHeading(w.observationTitle),
              const SizedBox(height: 16),
              Row(
                children: [
                  const NaturePrintedIconWell(icon: Icons.hub_outlined, settled: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Indicators involved', style: NatureType.bodyMuted),
                        Text(w.primaryFactor, style: NatureType.label),
                      ],
                    ),
                  ),
                ],
              ),
              if (w.isSampleData) ...[
                const SizedBox(height: 18),
                Text(PrototypeCopy.sampleDataDescription, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
              ],
              const SizedBox(height: 26),
              _Part(
                marker: w.isSampleData ? 'Sample observation' : 'Observed pattern',
                rule: NatureColors.sunOchre,
                title: w.isSampleData ? 'What this example shows' : 'What changed in your recorded data',
                body: w.evidenceSummary,
              ),
              const _Part(
                marker: 'Correlation',
                rule: NatureColors.skyTeal,
                title: 'Changing together',
                body: 'Two indicators moved during the same period. That is all a correlation '
                    'says. It can happen by chance, or because something else affected both.',
              ),
              _Part(
                marker: 'Causation',
                rule: NatureColors.dustyCoral,
                title: 'Not the same as one causing the other',
                body: w.whatCannotConclude,
              ),
              const _Part(
                marker: 'Personal baseline',
                rule: NatureColors.forest,
                title: 'What a real observation would need',
                body: PrototypeCopy.noBaselineDescription,
              ),
              const _Part(
                marker: 'Not built yet',
                rule: NatureColors.borderStrong,
                title: 'Features that do not exist in this prototype',
                body: 'Saving check-ins and other inputs, observations from your own data, and '
                    'comparing how different inputs relate to your reported stress are planned '
                    'but not built.',
              ),
              const SprigRule(),
              const SizedBox(height: 22),
              const NatureSectionHeading('General well-being ideas',
                  lede: 'General information, not advice based on your data and not a treatment.'),
              const SizedBox(height: 12),
              const _Idea(
                icon: Icons.schedule_rounded,
                title: 'A regular bedtime',
                body: 'Some people find a consistent bedtime helpful. This is general '
                    'information, not advice based on your data.',
              ),
              const _Idea(
                icon: Icons.self_improvement_rounded,
                title: 'Short breaks',
                body: 'Some people find short breaks between demanding tasks help them '
                    'pace their day. This is general information, not a treatment.',
              ),
              const SizedBox(height: 26),
              NatureQuietButton(label: 'Back', onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled part of the explanation: a small marker word, a heading and
/// the text, set against a coloured margin rule. The marker word carries the
/// meaning; the rule colour is decoration.
class _Part extends StatelessWidget {
  final String marker;
  final Color rule;
  final String title;
  final String body;
  const _Part({required this.marker, required this.rule, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: rule, width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(marker, style: NatureType.eyebrow),
            const SizedBox(height: 4),
            Semantics(header: true, child: Text(title, style: NatureType.sectionTitle)),
            const SizedBox(height: 6),
            Text(body, style: NatureType.body),
          ],
        ),
      ),
    );
  }
}

class _Idea extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Idea({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: NatureColors.forest, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NatureType.label),
                const SizedBox(height: 2),
                Text(body, style: NatureType.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
