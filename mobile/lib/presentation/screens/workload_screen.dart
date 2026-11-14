import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/state/workload_controller.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/input_bands.dart';
import '../nature/nature_inputs.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_storage_scope.dart';
import 'consent_screen.dart';

/// Production Workload & demands (Living Landscapes, Phase 3; persistence
/// Milestone K2).
///
/// A sunlit terraced hillside above three self-reported answers. Fields,
/// ranges, defaults and wording follow ADR-009 Decision D:
/// 1. mental demand, 1 to 5, default 3 (adapted from NASA-TLX; accessible
///    name "Mental demand", value "n of 5");
/// 2. effort invested, 1 to 5, default 3 ("Effort");
/// 3. impending deadlines in the next 48 hours: a count from 0 to 20,
///    default 1, with "One fewer deadline" / "One more deadline" buttons
///    (each disabled at its limit).
/// The summary only restates the answers; no score is calculated.
///
/// Saving goes through [WorkloadController] and the app's storage owner
/// (encrypted development storage only, in a debug build with the explicit
/// define). When this build connects no storage, "Save Workload Rating"
/// shows the honest prototype "not saved" message, as before. Success is
/// shown only after the database transaction committed.
class WorkloadScreen extends StatefulWidget {
  /// Injected for tests; normally created from the app's storage owner.
  final WorkloadController? controller;

  const WorkloadScreen({super.key, this.controller});

  @override
  State<WorkloadScreen> createState() => _WorkloadScreenState();
}

class _WorkloadScreenState extends State<WorkloadScreen> {
  WorkloadController? _controller;
  bool _ownsController = false;

  /// A save outcome the status line cannot express from the controller's
  /// state alone (the date changed). Shown inline in the status line, never
  /// as an overlay; cleared by the next save.
  String? _notice;
  final ScrollController _scroll = ScrollController();

  WorkloadController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final injected = widget.controller;
    _ownsController = injected == null;
    _controller = injected ?? WorkloadController(access: workloadAccessOf(context));
    _c.addListener(_onController);
    unawaited(_c.start());
  }

  /// Rebuilds the page chrome (back control, system back) when saving starts
  /// or ends; the form itself rebuilds through its ListenableBuilder.
  bool _wasSaving = false;
  void _onController() {
    if (_c.isSaving != _wasSaving && mounted) setState(() => _wasSaving = _c.isSaving);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onController);
    if (_ownsController) _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _deadlinesLabel(int n) => '$n deadline${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final saving = _c.isSaving;
    // Leaving (back control or system back) cannot discard a save in flight.
    return PopScope(
      canPop: !saving,
      child: Theme(
        data: NatureTheme.light,
        child: Scaffold(
          backgroundColor: NatureColors.background,
          body: NatureJournalPage(
            controller: _scroll,
            onBack: () => Navigator.of(context).maybePop(),
            backEnabled: !saving,
            backLabel: 'Back',
            band: (desktop) => TerraceBand(tornBottom: desktop),
            child: ListenableBuilder(
              listenable: _c,
              builder: (context, _) => Column(
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
                  _Ledger(demand: _c.mentalDemand, effort: _c.effort, deadlines: _c.deadlines,
                      deadlinesLabel: _deadlinesLabel(_c.deadlines)),
                  const SizedBox(height: 28),
                  NatureQuestion(
                    number: 1,
                    title: 'Mental demand',
                    source: 'Adapted from NASA-TLX',
                    question:
                        'How much mental and perceptual activity was required (thinking, deciding, calculating)?',
                    child: NatureSlider(
                      semanticLabel: 'Mental demand',
                      value: _c.mentalDemand,
                      minLabel: '1 · Very light',
                      maxLabel: '5 · Intense',
                      // Locked while saving: what is on screen is what is written.
                      onChanged: _c.isSaving ? null : _c.setMentalDemand,
                    ),
                  ),
                  const SizedBox(height: 28),
                  NatureQuestion(
                    number: 2,
                    title: 'Effort invested',
                    question: 'How hard did you have to work to accomplish your level of performance?',
                    child: NatureSlider(
                      semanticLabel: 'Effort',
                      value: _c.effort,
                      minLabel: '1 · Minimal',
                      maxLabel: '5 · Exhausting',
                      onChanged: _c.isSaving ? null : _c.setEffort,
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
                          count: _c.deadlines,
                          valueLabel: _deadlinesLabel(_c.deadlines),
                          decrementLabel: 'One fewer deadline',
                          incrementLabel: 'One more deadline',
                          onDecrement: _c.canDecrementDeadlines ? _c.decrementDeadlines : null,
                          onIncrement: _c.canIncrementDeadlines ? _c.incrementDeadlines : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_c.persistenceConnected)
                    _WorkloadStatus(controller: _c, notice: _notice, onReviewConsent: _openConsent)
                  else
                    const NatureNotSavedNote(),
                  const SizedBox(height: 16),
                  NaturePrintedAction(
                    label: 'Save Workload Rating',
                    icon: null,
                    onTap: _c.canSave ? _saveWorkload : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openConsent() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ConsentScreen(isSettingsMode: true)),
      );

  /// Saves, then reports the outcome INLINE: the live status line just above
  /// Save shows it (saved, updated, denied, failed, date changed), so no
  /// floating message ever covers the Save button.
  Future<void> _saveWorkload() async {
    setState(() => _notice = null);
    final result = await _c.save();
    if (!mounted) return;
    if (result == WorkloadSaveResult.notConnected) {
      // Persistence is not connected in this build: report that honestly.
      showNatureNotSavedMessage(context, 'workload rating');
      return;
    }
    if (result == WorkloadSaveResult.dayChanged) {
      setState(() => _notice = _WorkloadStatus.dayChangedText);
    }
  }
}

/// An honest, live status line under the form: where the entry is kept and
/// what the last save actually did (Milestone K2).
class _WorkloadStatus extends StatelessWidget {
  final WorkloadController controller;

  /// Overrides the state's text with a specific outcome (see [_WorkloadScreenState._notice]).
  final String? notice;
  final VoidCallback onReviewConsent;
  const _WorkloadStatus({required this.controller, required this.notice, required this.onReviewConsent});

  static String savedText(bool development) => development
      ? "Today's workload entry was saved in development storage. Development data, not for participants."
      : "Today's workload entry was saved on this device.";
  static const String updatedText = "Today's workload entry was updated.";
  static const String consentDeniedText =
      'Workload is turned off in your data and consent preferences, so nothing was saved.';
  static const String unavailableText =
      'Secure storage is unavailable, so your workload rating cannot be saved right now. Nothing was saved.';
  static const String failedText =
      'Your workload rating could not be saved. Your answers are still here, so you can try again.';
  static const String dayChangedText =
      "The date changed, so nothing was saved. The form now shows today's entry.";

  String get _text {
    final c = controller;
    final where = c.isDevelopment
        ? 'Saving keeps this entry in encrypted development storage on this device (development data, '
            'not for participants).'
        : 'Saving keeps this entry in encrypted storage on this device.';
    return switch (c.phase) {
      WorkloadPhase.idle || WorkloadPhase.loading => "Loading today's entry.",
      WorkloadPhase.editing => c.hasExistingEntry
          ? "You already saved a workload entry today. It is shown here; saving replaces it. $where"
          : 'No workload entry saved today yet. $where Workload must be turned on in your data and consent '
              'preferences.',
      WorkloadPhase.saving => 'Saving your workload rating.',
      WorkloadPhase.saved => savedText(c.isDevelopment),
      WorkloadPhase.updated => updatedText,
      WorkloadPhase.consentDenied => consentDeniedText,
      WorkloadPhase.storageUnavailable => unavailableText,
      WorkloadPhase.failed => c.todayLoaded
          ? failedText
          : "Today's saved entry could not be read. Saving reads it again first.",
      WorkloadPhase.notConnected => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.isBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(
                  // A static indicator: nothing animates while waiting.
                  child: busy
                      ? const Icon(Icons.hourglass_empty_rounded,
                          key: Key('workload-busy'), size: 17, color: NatureColors.inkMuted)
                      : const Icon(Icons.info_outline_rounded, size: 17, color: NatureColors.inkMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(notice ?? _text,
                    key: const Key('workload-status'), style: NatureType.bodyMuted.copyWith(fontSize: 13)),
              ),
            ],
          ),
        ),
        if (controller.phase == WorkloadPhase.consentDenied) ...[
          const SizedBox(height: 4),
          NatureTextLink(label: 'Review data and consent preferences', onTap: onReviewConsent),
        ],
      ],
    );
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
