import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/state/insights_controller.dart';
import '../../core/theme/nature_tokens.dart';
import '../../domain/personal_insights.dart';
import '../nature/meadow_band.dart';
import '../nature/nature_charts.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_storage_scope.dart';
import 'consent_screen.dart';

/// Production Insights (Living Landscapes, Phase 2).
///
/// A calm, editorial page of SAMPLE charts showing how SENSE may display a
/// person's own history. The Day / Week / Month selector is kept and is
/// honest that the sample charts do not change. No scores, risk levels or
/// diagnostic language.
///
/// Personal baseline (Milestone E): when storage is connected, a section
/// above the samples shows, for each Check-in, Sleep and Workload variable,
/// the person's own baseline from their SAVED entries of the last 14 days
/// ([InsightsController], the existing [PersonalBaselineAnalyzer] engine), or
/// how many more observations are needed. Modalities whose consent is off are
/// not analysed. It refreshes whenever the screen is shown. When storage is
/// not connected the page is the sample page, exactly as before.
class InsightsScreen extends StatefulWidget {
  /// True when shown as a navigation tab (no back control).
  final bool isTabRoot;

  /// Injected for tests; normally created from the app's storage owner.
  final InsightsController? controller;

  const InsightsScreen({super.key, this.isTabRoot = false, this.controller});

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
  InsightsController? _controller;
  bool _ownsController = false;
  bool _visible = false;

  InsightsController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final injected = widget.controller;
      _ownsController = injected == null;
      _controller = injected ?? InsightsController(access: insightsAccessOf(context));
    }
    // As a tab the screen stays alive while hidden (TickerMode off). Read the
    // saved entries again each time it is shown, so new saves and consent
    // changes are reflected and nothing stale stays visible.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) unawaited(_c.refresh());
    _visible = visible;
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openConsent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConsentScreen(isSettingsMode: true)),
    );
    if (mounted) unawaited(_c.refresh());
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
          child: ListenableBuilder(listenable: _c, builder: (context, _) => _content(context)),
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

    final connected = _c.persistenceConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Insights', style: NatureType.eyebrow),
        const SizedBox(height: 8),
        const NatureHeading('Longitudinal insights'),
        const SizedBox(height: 8),
        if (connected) ...[
          const Text(
            'Your personal patterns, from the check-ins, sleep and workload entries you have saved. '
            'Each result compares you only with your own recent entries.',
            style: NatureType.bodyMuted,
          ),
          const SizedBox(height: 22),
          _PersonalBaselineSection(controller: _c, onReviewConsent: _openConsent),
          const SizedBox(height: 28),
          const SprigRule(),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: const Text('Examples of future charts', style: NatureType.sectionTitle),
          ),
          const SizedBox(height: 10),
        ] else
          const Text(
            'A place to look back over your own ratings, once saving is connected. '
            'Patterns here would compare you only with your own history.',
            style: NatureType.bodyMuted,
          ),
        if (!connected) const SizedBox(height: 20),
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

const List<String> _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Tue 11 Nov" for a `YYYY-MM-DD` local date (no locale data).
String _dayLabel(String date, {bool weekday = true}) {
  final p = date.split('-').map(int.parse).toList();
  final d = DateTime(p[0], p[1], p[2]);
  final day = '${d.day} ${_monthsShort[d.month - 1]}';
  return weekday ? '${_daysShort[d.weekday - 1]} $day' : day;
}

/// The person's own baseline per variable, from their saved entries
/// (Milestone E). Descriptive only: no score, alert or interpretation beyond
/// within, above or below their own recent range.
class _PersonalBaselineSection extends StatelessWidget {
  final InsightsController controller;
  final VoidCallback onReviewConsent;
  const _PersonalBaselineSection({required this.controller, required this.onReviewConsent});

  static const Map<String, String> _modalityTitles = {
    'M1': 'Check-ins',
    'M3': 'Sleep',
    'M4': 'Workload',
  };
  static const Map<String, String> _consentOff = {
    'M1': 'Structured check-ins are off in your data and consent preferences, so they are not analysed.',
    'M3': 'Sleep is off in your data and consent preferences, so it is not analysed.',
    'M4': 'Workload is off in your data and consent preferences, so it is not analysed.',
  };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final days = c.analyzer.windowDays;
    final required = c.analyzer.required;
    final dates = c.windowDates;
    final children = <Widget>[
      Semantics(header: true, child: const Text('Your personal baseline', style: NatureType.sectionTitle)),
      const SizedBox(height: 4),
      Text(
        dates == null
            ? 'Last $days days of saved entries.'
            : 'Last $days days: ${_dayLabel(dates.first, weekday: false)} to ${_dayLabel(dates.last, weekday: false)}'
                '${c.isDevelopment ? ' (development data)' : ''}.',
        key: const Key('insights-window'),
        style: NatureType.label,
      ),
      const SizedBox(height: 14),
    ];
    switch (c.phase) {
      case InsightsPhase.idle || InsightsPhase.loading:
        children.add(const Text('Reading your saved entries.', key: Key('insights-loading'), style: NatureType.bodyMuted));
      case InsightsPhase.storageUnavailable:
        children.add(const Text('Secure storage is unavailable, so your saved entries cannot be read right now.',
            key: Key('insights-unavailable'), style: NatureType.bodyMuted));
      case InsightsPhase.failed:
        children.add(const Text('Your saved entries could not be read. Nothing is shown.',
            key: Key('insights-failed'), style: NatureType.bodyMuted));
      case InsightsPhase.notConnected:
        break;
      case InsightsPhase.available:
        for (final m in c.modalities!) {
          children
            ..add(Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Semantics(
                header: true,
                child: Text(_modalityTitles[m.modality]!,
                    style: NatureType.label.copyWith(fontWeight: FontWeight.w700, color: NatureColors.ink)),
              ),
            ))
            ..addAll(switch (m) {
              ModalityNotAnalysed() => [
                  Text(_consentOff[m.modality]!, key: Key('insights-off-${m.modality}'), style: NatureType.bodyMuted),
                  NatureTextLink(label: 'Review data and consent preferences', onTap: onReviewConsent),
                ],
              ModalityAnalysed(:final variables) => [for (final v in variables) _VariableRow(result: v)],
            })
            ..add(const SizedBox(height: 10));
        }
        children
          ..add(const SizedBox(height: 6))
          ..add(Text(
            'Descriptive only. Each result compares your saved entries with your own entries from the last '
            '$days days, using their median and typical spread. A baseline appears from $required entries; '
            'that minimum does not make it reliable. This does not assess your health or predict anything.',
            key: const Key('insights-footnote'),
            style: NatureType.bodyMuted.copyWith(fontSize: 13),
          ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// One variable: its observation count, and its baseline only when the
/// engine's minimum is met.
class _VariableRow extends StatelessWidget {
  final VariableBaseline result;
  const _VariableRow({required this.result});

  ({double min, double max}) get _bounds => switch (result.variable) {
        InsightVariable.sleepDuration => (min: 4.0, max: 12.0),
        InsightVariable.deadlines => (min: 0.0, max: 20.0),
        _ => (min: 1.0, max: 5.0),
      };

  String _value(double v) {
    final text = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return switch (result.variable) {
      InsightVariable.sleepDuration => '${v.toStringAsFixed(1)} h',
      InsightVariable.deadlines => text,
      _ => '$text of 5',
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final lines = <String>[];
    if (!r.sufficient) {
      lines.add('Insufficient observations: ${r.observations} of ${r.required} required in the last '
          '${r.windowDays} days. No baseline is shown yet.');
    } else if (r.state == BaselineState.degenerateDispersion) {
      // Enough entries, but almost all identical: the engine has no robust
      // spread, so no usual range and no direction are shown.
      lines
        ..add('${r.observations} of ${r.windowDays} days observed (${r.required} required).')
        ..add('Personal baseline ${_value(r.baseline!)}.')
        ..add('Latest entry, ${_dayLabel(r.latestDate!)}: ${_value(r.latestValue!)}.')
        ..add('Most of your entries in this period are the same, so there is not enough variation to compare '
            'the latest entry with your baseline.');
    } else {
      final b = _bounds;
      final low = (r.baseline! - r.scale!).clamp(b.min, b.max);
      final high = (r.baseline! + r.scale!).clamp(b.min, b.max);
      lines
        ..add('${r.observations} of ${r.windowDays} days observed (${r.required} required).')
        ..add('Personal baseline ${_value(r.baseline!)}; usual range ${_value(low)} to ${_value(high)}.');
      final position = switch (r.position) {
        BaselinePosition.within => 'Within your usual range.',
        BaselinePosition.above => 'Above your personal baseline.',
        BaselinePosition.below => 'Below your personal baseline.',
        null => '',
      };
      lines.add('Latest entry, ${_dayLabel(r.latestDate!)}: ${_value(r.latestValue!)}. $position'.trim());
    }
    return Semantics(
      container: true,
      label: '${r.variable.label}. ${lines.join(' ')}',
      child: ExcludeSemantics(
        child: Container(
          key: Key('insights-${r.variable.name}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: NatureColors.paper,
            borderRadius: NatureRadii.smBorder,
            border: Border.all(color: NatureColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.variable.label, style: NatureType.label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              for (final l in lines) Text(l, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
