import 'package:flutter/material.dart';

import '../../core/state/consent_preferences.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/input_bands.dart';
import '../nature/nature_inputs.dart';
import '../nature/nature_widgets.dart';
import 'consent_screen.dart';

/// Production Voice (Living Landscapes, Phase 4).
///
/// Voice is PLANNED, NOT BUILT. This page explains what a voice check-in
/// would involve and states plainly that it is not available: there is no
/// recording control, the microphone is never used, no microphone permission
/// is requested, and nothing is recorded, analysed or saved.
///
/// Until Phase 4 this screen had a demonstration "record" button with a
/// three-second timer and decorative bars. It recorded nothing, but it looked
/// like a working recorder, so it was removed: an explicit unavailable state
/// replaces it.
///
/// The only control on the page besides Back opens the existing data and
/// consent preferences (the same in-memory [ConsentPreferences] as onboarding).
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  /// The suggested prompt a voice check-in would use (unchanged wording).
  static const String suggestedPrompt =
      'Describe three neutral tasks you accomplished today and how rested you feel.';

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
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
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          band: (desktop) => EchoBand(tornBottom: desktop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Voice · optional', style: NatureType.eyebrow),
              const SizedBox(height: 8),
              const NatureHeading('Voice check-in'),
              const SizedBox(height: 16),
              const NatureStatusPanel(
                status: 'Planned · not built',
                title: 'Not available in this prototype',
                body: 'There is no recording control. The microphone is never used and no '
                    'microphone permission is requested. Nothing is recorded, analysed or saved.',
                icon: Icons.mic_off_outlined,
              ),
              const SizedBox(height: 28),
              const _Section(
                title: 'What voice could add',
                body: 'SENSE plans to study whether experimental acoustic features, such as pitch '
                    'variability, speaking rate and pause length, change alongside self-reported '
                    'stress. They are research measures, not validated indicators of stress or '
                    'emotion. Voice input is entirely optional.',
              ),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: const Text('What a voice check-in would involve', style: NatureType.sectionTitle),
              ),
              const SizedBox(height: 4),
              const Text('Planned design, not yet built.', style: NatureType.bodyMuted),
              const SizedBox(height: 14),
              const _PlannedStep(
                number: 1,
                text: 'You would choose to start. Recording would begin only when you tap; there '
                    'would be no background listening.',
              ),
              const _PlannedStep(
                number: 2,
                text: 'You would answer a short, neutral prompt, for example:',
                quote: VoiceScreen.suggestedPrompt,
              ),
              const _PlannedStep(
                number: 3,
                text: 'The audio would be converted on the device to acoustic features, and the '
                    'recording then deleted.',
              ),
              const SizedBox(height: 14),
              const SprigRule(),
              const SizedBox(height: 22),
              Semantics(
                header: true,
                child: const Text('Your choice about voice', style: NatureType.sectionTitle),
              ),
              const SizedBox(height: 6),
              ListenableBuilder(
                listenable: ConsentPreferences.instance,
                builder: (context, _) {
                  final prefs = ConsentPreferences.instance;
                  final on = prefs.isEnabled(InputModality.voice);
                  final note = prefs.savedStateNote;
                  return Text(
                    on
                        ? 'Voice is on in your preferences ($note). This only notes your '
                            'interest; it does not start any recording.'
                        : 'Voice is off in your preferences ($note). Turning it on only notes '
                            'your interest; it does not start any recording.',
                    style: NatureType.body,
                  );
                },
              ),
              const SizedBox(height: 4),
              NatureTextLink(
                label: 'Review data and consent preferences',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConsentScreen(isSettingsMode: true)),
                ),
              ),
              const SizedBox(height: 22),
              NatureQuietButton(label: 'Back', onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: NatureType.sectionTitle)),
        const SizedBox(height: 6),
        Text(body, style: NatureType.body),
      ],
    );
  }
}

/// One step of the planned design: a numeral and text, no control.
class _PlannedStep extends StatelessWidget {
  final int number;
  final String text;
  final String? quote;
  const _PlannedStep({required this.number, required this.text, this.quote});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(builder: (context, c) {
        // The quote sits under the step text; on narrow screens with large
        // text it uses the full width so its words never break.
        final indent = c.maxWidth >= 300 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4) ? 46.0 : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NatureStepNumeral(number: number, accent: NatureColors.skyInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(text, style: NatureType.body),
                  ),
                ),
              ],
            ),
            if (quote != null)
              Padding(
                padding: EdgeInsets.only(left: indent, top: 8),
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: NatureColors.skyTeal, width: 3)),
                  ),
                  child: Text('"$quote"', style: NatureType.body.copyWith(fontWeight: FontWeight.w500)),
                ),
              ),
          ],
        );
      }),
    );
  }
}
