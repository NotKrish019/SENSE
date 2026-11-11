import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/state/check_in_controller.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/mood_scale.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_storage_scope.dart';
import 'consent_screen.dart';

/// Production daily check-in (Living Landscapes, Phase 1).
///
/// * Step 1: mood (1 to 5, default 3) shown as the five approved mood
///   symbols, and motivation or energy (1 to 5, default 3); then "Continue to
///   stress rating".
/// * Step 2: perceived stress (1 to 5, default 2), the planned-processing
///   notice, Back (to step 1, answers kept) and "Finish check-in".
/// * Persistence (Milestone K3): "Finish check-in" saves through
///   [CheckInController] and the app's storage owner (encrypted development
///   storage only, in a debug build with the explicit define). The completion
///   page appears only after the database transaction committed; a refused or
///   failed save stays on step 2 with the answers kept. When this build
///   connects no storage, finishing shows the honest "not saved" page, as
///   before. No baseline is updated and no model runs.
///
/// Screen-reader names: "Mood: Very Low" … "Mood: Great" (with selected
/// state), "Motivation or energy level" and "Perceived stress", values read as
/// "n of 5". The mood symbols themselves are decorative.
class CheckInScreen extends StatefulWidget {
  /// Injected for tests; normally created from the app's storage owner.
  final CheckInController? controller;

  const CheckInScreen({super.key, this.controller});

  /// The mood scale: values, order and labels. This is the production mood
  /// model; the emoji it used before Phase 1 were presentation only.
  static const List<({int value, String label})> moodOptions = [
    (value: 1, label: 'Very Low'),
    (value: 2, label: 'Low'),
    (value: 3, label: 'Neutral'),
    (value: 4, label: 'Good'),
    (value: 5, label: 'Great'),
  ];

  @override
  State<CheckInScreen> createState() => CheckInScreenState();
}

class CheckInScreenState extends State<CheckInScreen> {
  int _currentStep = 1;
  CheckInController? _controller;
  bool _ownsController = false;

  /// The completion page shown, or null while answering.
  _Completion? _done;
  final ScrollController _scroll = ScrollController();

  CheckInController get _c => _controller!;

  /// Read-only view of the state, for tests.
  int get selectedMood => _c.mood;
  int get currentStep => _currentStep;
  int get motivationLevel => _c.motivation;
  int get perceivedStress => _c.stress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final injected = widget.controller;
    _ownsController = injected == null;
    _controller = injected ?? CheckInController(access: checkInAccessOf(context));
    unawaited(_c.start());
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openConsent() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ConsentScreen(isSettingsMode: true)),
      );

  Future<void> _finish() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await _c.save();
    if (!mounted) return;
    final done = switch (result) {
      CheckInSaveResult.saved => _Completion.saved,
      CheckInSaveResult.updated => _Completion.updated,
      CheckInSaveResult.notConnected => _Completion.notSaved,
      _ => null,
    };
    if (done != null) {
      _goTo(() => _done = done);
      return;
    }
    final message = _CheckInStatus.messageFor(result);
    if (message == null) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: NatureType.body.copyWith(color: NatureColors.paper)),
        backgroundColor: NatureColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NatureRadii.smBorder),
        duration: const Duration(seconds: 4),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final Widget content;
        final String key;
        final connected = _c.persistenceConnected;
        final saving = _c.isSaving;
        final Widget note =
            connected ? _CheckInStatus(controller: _c, onReviewConsent: _openConsent) : const NatureNotSavedNote();
        final done = _done;
        if (done != null) {
          key = 'done';
          content = _DoneStep(
            completion: done,
            development: _c.isDevelopment,
            onReturn: () => Navigator.of(context).maybePop(),
          );
        } else if (_currentStep == 1) {
          key = 'step1';
          content = _MoodStep(
            mood: _c.mood,
            motivation: _c.motivation,
            // While saving, the answers and the steps are locked: what is on
            // screen is exactly what is being written.
            onMood: saving ? null : _c.setMood,
            onMotivation: saving ? null : _c.setMotivation,
            onContinue: saving ? null : () => _goTo(() => _currentStep = 2),
            note: note,
          );
        } else {
          key = 'step2';
          content = _StressStep(
            stress: _c.stress,
            onStress: saving ? null : _c.setStress,
            onBack: saving ? null : () => _goTo(() => _currentStep = 1),
            // Disabled while today's check-in loads or a save is running, so
            // repeated taps never start a second write.
            onFinish: _c.canSave ? _finish : null,
            persistenceConnected: connected,
            note: note,
          );
        }

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
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
                  switchInCurve: NatureMotion.ease,
                  switchOutCurve: NatureMotion.ease,
                  layoutBuilder: (current, previous) =>
                      Stack(alignment: Alignment.topLeft, children: [...previous, if (current != null) current]),
                  child: KeyedSubtree(key: ValueKey(key), child: content),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Which completion page to show.
enum _Completion {
  /// Storage is not connected in this build: the honest "not saved" page.
  notSaved,

  /// Today's check-in was created (the transaction committed).
  saved,

  /// Today's existing check-in was replaced (the transaction committed).
  updated,
}

/// An honest, live status line under each step: where the answers are kept
/// and what the last save actually did (Milestone K3).
class _CheckInStatus extends StatelessWidget {
  final CheckInController controller;
  final VoidCallback onReviewConsent;
  const _CheckInStatus({required this.controller, required this.onReviewConsent});

  static const String consentDeniedText =
      'Structured check-ins are turned off in your data and consent preferences, so nothing was saved.';
  static const String unavailableText =
      'Secure storage is unavailable, so your check-in cannot be saved right now. Nothing was saved.';
  static const String failedText =
      'Your check-in could not be saved. Your answers are still here, so you can try again.';
  static const String dayChangedText = 'The date changed before you finished, so nothing was saved. This '
      "check-in is now for today: answers you changed are kept, the others show today's saved check-in or "
      'the starting values. Review them and finish again.';
  static const String dayChangedNotReloadedText = 'The date changed before you finished, so nothing was saved, '
      "and today's check-in could not be read. Your answers are still on screen; finishing again reads today "
      'first.';

  /// The message after a save that did not complete, or null.
  static String? messageFor(CheckInSaveResult r) => switch (r) {
        CheckInSaveResult.consentDenied => consentDeniedText,
        CheckInSaveResult.storageUnavailable => unavailableText,
        CheckInSaveResult.failed => failedText,
        CheckInSaveResult.dayChanged => dayChangedText,
        CheckInSaveResult.dayChangedNotReloaded => dayChangedNotReloadedText,
        CheckInSaveResult.saved ||
        CheckInSaveResult.updated ||
        CheckInSaveResult.notConnected ||
        CheckInSaveResult.notReady =>
          null,
      };

  String get _text {
    final c = controller;
    final where = c.isDevelopment
        ? 'Finishing keeps your answers in encrypted development storage on this device (development data, '
            'not for participants).'
        : 'Finishing keeps your answers in encrypted storage on this device.';
    return switch (c.phase) {
      CheckInPhase.idle || CheckInPhase.loading => "Loading today's check-in.",
      CheckInPhase.editing || CheckInPhase.saved || CheckInPhase.updated => c.hasExistingEntry
          ? 'You already completed a check-in today. Your answers are shown; finishing replaces them. $where'
          : 'No check-in saved today yet. $where Structured check-ins must be turned on in your data and '
              'consent preferences.',
      CheckInPhase.saving => 'Saving your check-in.',
      CheckInPhase.consentDenied => consentDeniedText,
      CheckInPhase.storageUnavailable => unavailableText,
      CheckInPhase.failed =>
        c.dayLoaded ? failedText : "Today's saved check-in could not be read. Finishing reads it again first.",
      CheckInPhase.notConnected => '',
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
                          key: Key('check-in-busy'), size: 17, color: NatureColors.inkMuted)
                      : const Icon(Icons.info_outline_rounded, size: 17, color: NatureColors.inkMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text(_text, key: const Key('check-in-status'), style: NatureType.bodyMuted.copyWith(fontSize: 13)),
              ),
            ],
          ),
        ),
        if (controller.phase == CheckInPhase.consentDenied) ...[
          const SizedBox(height: 4),
          NatureTextLink(label: 'Review data and consent preferences', onTap: onReviewConsent),
        ],
      ],
    );
  }
}

// ---- Step 1: mood, motivation ---------------------------------------------------
class _MoodStep extends StatelessWidget {
  final int mood;
  final int motivation;

  /// Null while saving (the answers are locked).
  final ValueChanged<int>? onMood;
  final ValueChanged<int>? onMotivation;
  final VoidCallback? onContinue;

  /// The "not saved" note, or the live storage status when connected.
  final Widget note;
  const _MoodStep({
    required this.mood,
    required this.motivation,
    required this.onMood,
    required this.onMotivation,
    required this.onContinue,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NatureStepHeader(step: 1),
        const SizedBox(height: 10),
        const NatureHeading('How are you feeling right now?'),
        const SizedBox(height: 8),
        const Text(
          'This check-in is optional. Choose the one that feels closest; '
          'there is no right answer, and you can leave at any time.',
          style: NatureType.bodyMuted,
        ),
        const SizedBox(height: 22),
        MoodScale(options: CheckInScreen.moodOptions, selected: mood, onSelected: onMood),
        const SizedBox(height: 26),
        const SprigRule(),
        const SizedBox(height: 22),
        const Text('Motivation and energy', style: NatureType.sectionTitle),
        const SizedBox(height: 4),
        const Text('How energetic or motivated do you feel to complete tasks today?',
            style: NatureType.bodyMuted),
        const SizedBox(height: 12),
        NatureSlider(
          semanticLabel: 'Motivation or energy level',
          value: motivation,
          minLabel: 'Low energy',
          maxLabel: 'High energy',
          onChanged: onMotivation,
        ),
        const SizedBox(height: 30),
        NaturePrintedAction(label: 'Continue to stress rating', onTap: onContinue),
        const SizedBox(height: 18),
        note,
      ],
    );
  }
}

// ---- Step 2: perceived stress ---------------------------------------------------
class _StressStep extends StatelessWidget {
  final int stress;

  /// Null while saving (the answer and the steps are locked).
  final ValueChanged<int>? onStress;
  final VoidCallback? onBack;

  /// Null while Finish is unavailable (loading or saving).
  final VoidCallback? onFinish;
  final bool persistenceConnected;

  /// The "not saved" note, or the live storage status when connected.
  final Widget note;
  const _StressStep({
    required this.stress,
    required this.onStress,
    required this.onBack,
    required this.onFinish,
    required this.persistenceConnected,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final finish = NaturePrintedAction(label: 'Finish check-in', onTap: onFinish, icon: null);
    final back = NatureQuietButton(label: 'Back', onTap: onBack);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NatureStepHeader(step: 2),
        const SizedBox(height: 10),
        const NatureHeading('Perceived stress'),
        const SizedBox(height: 8),
        const Text('Rate your subjective perceived stress today (adapted EMA subscale).',
            style: NatureType.bodyMuted),
        const SizedBox(height: 18),
        NatureSlider(
          semanticLabel: 'Perceived stress',
          value: stress,
          minLabel: '1 · Relaxed',
          maxLabel: '5 · Very stressed',
          onChanged: onStress,
          // The higher end (4 and 5) is shown in a warmer colour, as before;
          // the value text and thumb position carry the meaning.
          warm: stress >= 4,
        ),
        const SizedBox(height: 26),
        const SprigRule(),
        const SizedBox(height: 22),
        NatureMarginNote(
          eyebrow: 'Planned, not active yet',
          text: persistenceConnected
              ? 'Later, your ratings will be compared with your own history, and single unusual days '
                  'will be smoothed out before any pattern is shown. This is not active yet: nothing is '
                  'calculated from your answers.'
              : 'Once saving is connected, your ratings will be compared with your own '
                  'history, and single unusual days will be smoothed out before any pattern '
                  'is shown. This is not active yet. Ratings are not saved in this prototype.',
        ),
        const SizedBox(height: 30),
        LayoutBuilder(builder: (context, c) {
          final stacked = c.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [finish, const SizedBox(height: 10), back],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: back),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: finish),
            ],
          );
        }),
        const SizedBox(height: 18),
        note,
      ],
    );
  }
}

// ---- Finished: shown only after a committed save, or the honest "not saved" page ----
class _DoneStep extends StatelessWidget {
  final _Completion completion;
  final bool development;
  final VoidCallback onReturn;
  const _DoneStep({required this.completion, required this.development, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final where = development
        ? 'They are kept in encrypted development storage on this device. This is development data, '
            'not for participants.'
        : 'They are kept in encrypted storage on this device.';
    final (heading, body) = switch (completion) {
      _Completion.notSaved => (
          'Check-in complete, not saved',
          'Thank you for trying the check-in. In this prototype your answers are not '
              'saved and no personal baseline is updated.',
        ),
      _Completion.saved => (
          'Check-in saved',
          "Thank you. Today's check-in was saved. $where No personal baseline is updated "
              'and nothing is calculated from your answers yet.',
        ),
      _Completion.updated => (
          'Check-in updated',
          "Today's check-in was updated with your new answers. $where No personal baseline is "
              'updated and nothing is calculated from your answers yet.',
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily check-in', style: NatureType.eyebrow),
        const SizedBox(height: 10),
        NatureHeading(heading),
        const SizedBox(height: 10),
        Text(body, style: NatureType.body),
        const SizedBox(height: 26),
        const SprigRule(),
        const SizedBox(height: 26),
        NaturePrintedAction(label: 'Return to Home', onTap: onReturn, icon: null),
      ],
    );
  }
}
