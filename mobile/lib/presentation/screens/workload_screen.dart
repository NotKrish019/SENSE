import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/input_bands.dart';
import '../nature/nature_inputs.dart';
import '../nature/nature_widgets.dart';

/// Production Workload & demands (Living Landscapes, Phase 3).
///
/// A sunlit terraced hillside above three self-reported answers. Fields,
/// ranges, defaults and wording are unchanged:
/// 1. mental demand, 1 to 5, default 3 (adapted from NASA-TLX; accessible
///    name "Mental demand", value "n of 5");
/// 2. effort invested, 1 to 5, default 3 ("Effort");
/// 3. impending deadlines in the next 48 hours: a count from 0 upwards,
///    default 1, with "One fewer deadline" / "One more deadline" buttons.
/// The summary only restates the answers; no score is calculated.
/// "Save Workload Rating" shows the honest "not saved" message.
class WorkloadScreen extends StatefulWidget {
  const WorkloadScreen({super.key});

  @override
  State<WorkloadScreen> createState() => _WorkloadScreenState();
}

class _WorkloadScreenState extends State<WorkloadScreen> {
  int _mentalDemand = 3; // 1 to 5
  int _effortRating = 3; // 1 to 5
  int _deadlinesCount = 1;
  int _tasksCompleted = 4; // pre-existing, not shown or used (no task tracking)
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _deadlines => '$_deadlinesCount deadline${_deadlinesCount == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          band: (desktop) => TerraceBand(tornBottom: desktop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Workload', style: NatureType.eyebrow),
              const SizedBox(height: 8),
              const NatureHeading('Workload & demands'),
              const SizedBox(height: 8),
              const Text(
                'Three self-reported answers. You choose each value; in this prototype '
                'nothing is calculated from them.',
                style: NatureType.bodyMuted,
              ),
              const SizedBox(height: 18),
              _Ledger(demand: _mentalDemand, effort: _effortRating, deadlines: _deadlinesCount,
                  deadlinesLabel: _deadlines),
              const SizedBox(height: 28),
              NatureQuestion(
                number: 1,
                title: 'Mental demand',
                source: 'Adapted from NASA-TLX',
                question:
                    'How much mental and perceptual activity was required (thinking, deciding, calculating)?',
                child: NatureSlider(
                  semanticLabel: 'Mental demand',
                  value: _mentalDemand,
                  minLabel: '1 · Very light',
                  maxLabel: '5 · Intense',
                  onChanged: (v) => setState(() => _mentalDemand = v),
                ),
              ),
              const SizedBox(height: 28),
              NatureQuestion(
                number: 2,
                title: 'Effort invested',
                question: 'How hard did you have to work to accomplish your level of performance?',
                child: NatureSlider(
                  semanticLabel: 'Effort',
                  value: _effortRating,
                  minLabel: '1 · Minimal',
                  maxLabel: '5 · Exhausting',
                  onChanged: (v) => setState(() => _effortRating = v),
                ),
              ),
              const SizedBox(height: 28),
              NatureQuestion(
                number: 3,
                title: 'Impending deadlines',
                question: 'Upcoming deliverables in the next 48 hours.',
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Text('Upcoming deliverables:', style: NatureType.label),
                    NatureCountStepper(
                      count: _deadlinesCount,
                      valueLabel: _deadlines,
                      decrementLabel: 'One fewer deadline',
                      incrementLabel: 'One more deadline',
                      onDecrement: _deadlinesCount > 0 ? () => setState(() => _deadlinesCount--) : null,
                      onIncrement: () => setState(() => _deadlinesCount++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const NatureNotSavedNote(),
              const SizedBox(height: 16),
              NaturePrintedAction(label: 'Save Workload Rating', icon: null, onTap: _saveWorkload),
            ],
          ),
        ),
      ),
    );
  }

  void _saveWorkload() {
    // Persistence is not connected yet: report that honestly.
    showNatureNotSavedMessage(context, 'workload rating');
  }
}

/// "Your ratings (self-reported)": the three answers restated side by side,
/// like a page in a field ledger. Nothing is added or combined.
class _Ledger extends StatelessWidget {
  final int demand;
  final int effort;
  final int deadlines;
  final String deadlinesLabel;
  const _Ledger({
    required this.demand,
    required this.effort,
    required this.deadlines,
    required this.deadlinesLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('Demand', '$demand/5'),
      ('Effort', '$effort/5'),
      ('Deadlines', '$deadlines'),
    ];
    return Semantics(
      container: true,
      label: 'Your ratings (self-reported): mental demand $demand of 5, effort $effort of 5, $deadlinesLabel',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: NatureColors.paper,
            borderRadius: NatureRadii.mdBorder,
            border: Border.all(color: NatureColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your ratings (self-reported)', style: NatureType.bodyMuted.copyWith(fontSize: 13)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                // Three columns only while every label fits its column whole.
                double width(String t, TextStyle st) {
                  final tp = TextPainter(
                    text: TextSpan(text: t, style: st),
                    textScaler: MediaQuery.textScalerOf(context),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                  )..layout();
                  final w = tp.width;
                  tp.dispose();
                  return w;
                }
                final need = [
                  for (final e in cells) ...[
                    width(e.$1, NatureType.bodyMuted.copyWith(fontSize: 13)),
                    width(e.$2, NatureType.statusTitle.copyWith(fontWeight: FontWeight.w600)),
                  ]
                ].reduce((a, b) => a > b ? a : b);
                final narrow = (c.maxWidth - 48) / 3 < need + 2;
                Widget cell((String, String) e) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.$2, style: NatureType.statusTitle.copyWith(fontWeight: FontWeight.w600)),
                        Text(e.$1, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                      ],
                    );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in cells)
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: cell(e)),
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cells.length; i++) ...[
                        if (i > 0)
                          const VerticalDivider(width: 24, thickness: 1, color: NatureColors.divider),
                        Expanded(child: cell(cells[i])),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
