
import 'package:flutter/material.dart';

import '../nature/mood_scale.dart';
import '../nature/nature_widgets.dart';
import '../screens/check_in_screen.dart';

// Moved to production in Phase 1; re-exported for the preview's tests.
export '../nature/mood_scale.dart' show MoodScale, MoodTile;
export '../nature/nature_widgets.dart' show SprigRule, StillWaterBand;
import 'nature_tokens.dart';

/// The check-in mood scale: the production model itself
/// (`CheckInScreen.moodOptions`), so the preview can never drift from it.
const List<({int value, String label})> natureMoodOptions = CheckInScreen.moodOptions;

/// REDESIGN PROTOTYPE: the daily check-in in the Living Landscapes style.
///
/// Viewable only through `lib/main_redesign_preview.dart`; the production
/// `CheckInScreen` is unchanged. Behaviour mirrors it exactly:
/// * step 1: mood (1 to 5, default 3) and motivation or energy (1 to 5,
///   default 3), then "Continue to stress rating";
/// * step 2: perceived stress (1 to 5, default 2), the planned-processing
///   notice, Back (to step 1) and the finish action;
/// * finishing shows an honest "not saved" page; nothing is stored, no
///   baseline is updated and no model runs.
/// Same screen-reader names as production ("Mood: Low", "Motivation or energy
/// level", "Perceived stress", values read as "n of 5").
class NatureCheckInPreview extends StatefulWidget {
  const NatureCheckInPreview({super.key});

  @override
  State<NatureCheckInPreview> createState() => NatureCheckInPreviewState();
}

class NatureCheckInPreviewState extends State<NatureCheckInPreview> {
  int _currentStep = 1;
  int _selectedMood = 3; // 1 to 5
  int _perceivedStress = 2; // 1 to 5
  int _motivationLevel = 3; // 1 to 5
  bool _isSaved = false;
  final ScrollController _scroll = ScrollController();

  /// Read-only view of the state, for tests.
  int get selectedMood => _selectedMood;
  int get currentStep => _currentStep;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final Widget content;
    final String key;
    if (_isSaved) {
      key = 'done';
      content = _DoneStep(onReturn: () => Navigator.of(context).maybePop());
    } else if (_currentStep == 1) {
      key = 'step1';
      content = _MoodStep(
        mood: _selectedMood,
        motivation: _motivationLevel,
        onMood: (v) => setState(() => _selectedMood = v),
        onMotivation: (v) => setState(() => _motivationLevel = v),
        onContinue: () => _goTo(() => _currentStep = 2),
      );
    } else {
      key = 'step2';
      content = _StressStep(
        stress: _perceivedStress,
        onStress: (v) => setState(() => _perceivedStress = v),
        onBack: () => _goTo(() => _currentStep = 1),
        // No persistence yet: go straight to the honest "not saved" state.
        onFinish: () => _goTo(() => _isSaved = true),
      );
    }

    return Scaffold(
      backgroundColor: NatureColors.background,
      body: NatureJournalPage(
        controller: _scroll,
        onBack: () => Navigator.of(context).maybePop(),
        child: AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
          switchInCurve: NatureMotion.ease,
          switchOutCurve: NatureMotion.ease,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topLeft, children: [...previous, if (current != null) current]),
          child: KeyedSubtree(key: ValueKey(key), child: content),
        ),
      ),
    );
  }
}

// ---- Step 1: mood, motivation ---------------------------------------------------
class _MoodStep extends StatelessWidget {
  final int mood;
  final int motivation;
  final ValueChanged<int> onMood;
  final ValueChanged<int> onMotivation;
  final VoidCallback onContinue;
  const _MoodStep({
    required this.mood,
    required this.motivation,
    required this.onMood,
    required this.onMotivation,
    required this.onContinue,
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
        MoodScale(options: natureMoodOptions, selected: mood, onSelected: onMood),
        const SizedBox(height: 26),
        const SprigRule(),
        const SizedBox(height: 22),
        Text('Motivation and energy', style: NatureType.sectionTitle),
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
        const NatureNotSavedNote(),
      ],
    );
  }
}

// ---- Step 2: perceived stress ---------------------------------------------------
class _StressStep extends StatelessWidget {
  final int stress;
  final ValueChanged<int> onStress;
  final VoidCallback onBack;
  final VoidCallback onFinish;
  const _StressStep({
    required this.stress,
    required this.onStress,
    required this.onBack,
    required this.onFinish,
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
          // As in production, the higher end (4 and 5) is shown in a warmer
          // colour; the value text and position carry the meaning.
          warm: stress >= 4,
        ),
        const SizedBox(height: 26),
        const SprigRule(),
        const SizedBox(height: 22),
        const NatureMarginNote(
          eyebrow: 'Planned, not active yet',
          text: 'Once saving is connected, your ratings will be compared with your own '
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
        const NatureNotSavedNote(),
      ],
    );
  }
}

// ---- Finished: honest "not saved" page ------------------------------------------
class _DoneStep extends StatelessWidget {
  final VoidCallback onReturn;
  const _DoneStep({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily check-in', style: NatureType.eyebrow),
        const SizedBox(height: 10),
        const NatureHeading('Check-in complete, not saved'),
        const SizedBox(height: 10),
        const Text(
          'Thank you for trying the check-in. In this prototype your answers are not '
          'saved and no personal baseline is updated.',
          style: NatureType.body,
        ),
        const SizedBox(height: 26),
        const SprigRule(),
        const SizedBox(height: 26),
        NaturePrintedAction(label: 'Return to Home', onTap: onReturn, icon: null),
      ],
    );
  }
}
