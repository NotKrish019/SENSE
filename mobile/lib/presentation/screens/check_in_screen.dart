import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/mood_scale.dart';
import '../nature/nature_widgets.dart';

/// Production daily check-in (Living Landscapes, Phase 1).
///
/// * Step 1: mood (1 to 5, default 3) shown as the five approved mood
///   symbols, and motivation or energy (1 to 5, default 3); then "Continue to
///   stress rating".
/// * Step 2: perceived stress (1 to 5, default 2), the planned-processing
///   notice, Back (to step 1, answers kept) and "Finish check-in".
/// * Finishing shows an honest "not saved" page. Nothing is stored, no
///   baseline is updated and no model runs: persistence is not connected.
///
/// Screen-reader names: "Mood: Very Low" … "Mood: Great" (with selected
/// state), "Motivation or energy level" and "Perceived stress", values read as
/// "n of 5". The mood symbols themselves are decorative.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

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
  int _selectedMood = 3; // 1 to 5
  int _perceivedStress = 2; // 1 to 5
  int _motivationLevel = 3; // 1 to 5
  bool _isSaved = false;
  final ScrollController _scroll = ScrollController();

  /// Read-only view of the state, for tests.
  int get selectedMood => _selectedMood;
  int get currentStep => _currentStep;
  int get motivationLevel => _motivationLevel;
  int get perceivedStress => _perceivedStress;

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
        // No persistence yet: go straight to the honest "not saved" state
        // instead of simulating a saving delay.
        onFinish: () => _goTo(() => _isSaved = true),
      );
    }

    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: () => Navigator.of(context).maybePop(),
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
            switchInCurve: NatureMotion.ease,
            switchOutCurve: NatureMotion.ease,
            layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft, children: [...previous, if (current != null) current]),
            child: KeyedSubtree(key: ValueKey(key), child: content),
          ),
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
          // The higher end (4 and 5) is shown in a warmer colour, as before;
          // the value text and thumb position carry the meaning.
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
