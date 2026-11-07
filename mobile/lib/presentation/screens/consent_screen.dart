import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/consent_preferences.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';
import 'main_shell.dart';

/// Data & consent preferences for the six optional inputs (M1–M6).
///
/// Shown after onboarding (Splash → Onboarding → Consent → Dashboard) and from
/// Settings ("Review data and consent preferences").
///
/// Prototype honesty rules: choices are held in memory only (see
/// [ConsentPreferences]); they do not start any data collection, no OS
/// permission is requested, and this is not a research-participant consent
/// process.
class ConsentScreen extends StatelessWidget {
  /// True when opened from Settings: the action returns to Settings instead
  /// of entering the dashboard.
  final bool isSettingsMode;

  const ConsentScreen({super.key, this.isSettingsMode = false});

  @override
  Widget build(BuildContext context) {
    final prefs = ConsentPreferences.instance;
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(title: 'Data & consent preferences'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: SenseSpacing.screenHorizontal,
              vertical: 12,
            ),
            children: [
              Text(
                'Choose what you would like to share',
                style: SenseTypography.h2.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              Text(
                'All six inputs are optional and off by default. You can continue '
                'with none of them turned on, and skipping an input will never be '
                'treated as a sign of stress.',
                style: SenseTypography.bodySecondary.copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),
              const _PrototypeNotice(),
              const SizedBox(height: 20),
              for (final m in InputModality.values) ...[
                _ModalityCard(
                  modality: m,
                  info: _modalityInfo[m]!,
                  value: prefs.isEnabled(m),
                  onChanged: (v) => prefs.setEnabled(m, v),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              _SupportNote(),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${prefs.enabledCount} of ${InputModality.values.length} inputs turned on '
                  '(kept only while the app is open).',
                  style: SenseTypography.captionMedium.copyWith(color: SenseColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              SenseButton(
                label: isSettingsMode ? 'Done' : 'Continue to SENSE',
                icon: isSettingsMode ? Icons.check_rounded : Icons.arrow_forward_rounded,
                onPressed: () => _onContinue(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _onContinue(BuildContext context) {
    if (isSettingsMode) {
      Navigator.of(context).pop();
      return;
    }
    // Enter the main app (Home tab) as the only route, so Back cannot
    // return into onboarding/consent and no duplicate dashboard is created.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }
}

class _ModalityInfo {
  final String whatItInvolves;
  final String whyUseful;
  final String inThisPrototype;
  final String statusLabel;

  const _ModalityInfo({
    required this.whatItInvolves,
    required this.whyUseful,
    required this.inThisPrototype,
    required this.statusLabel,
  });
}

const Map<InputModality, _ModalityInfo> _modalityInfo = {
  InputModality.checkIn: _ModalityInfo(
    whatItInvolves:
        'Ratings you choose to give, such as mood, perceived stress, energy and motivation.',
    whyUseful: 'Could help show how your own ratings change over time.',
    inThisPrototype: 'You can try the check-in screen. Answers are not saved.',
    statusLabel: 'Available to try · not saved',
  ),
  InputModality.journal: _ModalityInfo(
    whatItInvolves: 'Written reflections that you choose to write.',
    whyUseful: 'Could later help you notice recurring themes in your own words.',
    inThisPrototype:
        'You can type an entry, but it is not saved and the planned language analysis is '
        'not built. Text is only checked on this device for crisis phrases so support '
        'contacts can be shown.',
    statusLabel: 'Available to try · not saved',
  ),
  InputModality.sleep: _ModalityInfo(
    whatItInvolves:
        'Sleep duration, bedtime, wake time and rest quality that you enter yourself.',
    whyUseful: 'Could help compare your sleep with your own ratings over time.',
    inThisPrototype: 'Manual entry only, not saved. No health app is connected.',
    statusLabel: 'Available to try · not saved',
  ),
  InputModality.workload: _ModalityInfo(
    whatItInvolves:
        'Academic, work or personal workload that you report: demand, effort and deadlines.',
    whyUseful: 'Could help compare busy periods with your own ratings.',
    inThisPrototype: 'Manual entry only, not saved.',
    statusLabel: 'Available to try · not saved',
  ),
  InputModality.voice: _ModalityInfo(
    whatItInvolves:
        'Short voice recordings you would choose to make, used for experimental acoustic '
        'features such as speaking rate and pauses.',
    whyUseful:
        'Being researched as a possible signal. It is not a validated measure of stress or emotion.',
    inThisPrototype:
        'Planned, not built. No audio is recorded and no microphone permission is '
        'requested. Turning this on only notes your interest.',
    statusLabel: 'Planned · not built',
  ),
  InputModality.activity: _ModalityInfo(
    whatItInvolves: 'Steps and active minutes. Health-app sync may be added later.',
    whyUseful: 'Could help compare activity with your own ratings over time.',
    inThisPrototype:
        'Manual entry only, not saved. Health Connect and other activity data are not '
        'read, and no permission is requested.',
    statusLabel: 'Manual entry only · sync planned',
  ),
};

class _ModalityCard extends StatelessWidget {
  final InputModality modality;
  final _ModalityInfo info;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ModalityCard({
    required this.modality,
    required this.info,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final available = modality.isAvailableInPrototype;
    return SenseCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Whole row is the switch's tap target and accessible label.
          // Transparent Material so the tile's ink renders on the card.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value,
            onChanged: onChanged,
            activeThumbColor: SenseColors.white,
            activeTrackColor: SenseColors.blue600,
            // Off state must stay visible on a white card (>= 3:1 contrast).
            inactiveThumbColor: SenseColors.textMuted,
            inactiveTrackColor: SenseColors.white,
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? SenseColors.blue600
                  : SenseColors.textMuted,
            ),
            title: Text(
              '${modality.code} · ${modality.title}',
              style: SenseTypography.labelBold.copyWith(
                color: SenseColors.navy900,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    available ? Icons.touch_app_outlined : Icons.hourglass_empty_rounded,
                    size: 14,
                    color: SenseColors.blue800,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${info.statusLabel} · ${value ? 'On' : 'Off'}',
                      style: SenseTypography.caption.copyWith(
                        color: SenseColors.blue800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('What it involves', info.whatItInvolves),
                _detail('Why it may be useful', info.whyUseful),
                _detail('In this prototype', info.inThisPrototype),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$heading: ',
              style: SenseTypography.caption.copyWith(
                color: SenseColors.navy900,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: body,
              style: SenseTypography.caption.copyWith(color: SenseColors.textSecondary),
            ),
          ],
        ),
        style: const TextStyle(height: 1.4),
      ),
    );
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SenseSpacing.md),
      decoration: BoxDecoration(
        color: SenseColors.white,
        borderRadius: SenseRadii.mdBorder,
        border: Border.all(color: SenseColors.cyan500, width: 1.2),
        boxShadow: SenseShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: SenseColors.blue800, size: 20),
          const SizedBox(width: SenseSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prototype demonstration',
                  style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Your choices are kept only while the app is open. They are not saved '
                  'and are lost if you refresh or close it.\n'
                  '• Turning an input on does not start any data collection, and no phone '
                  'or browser permission is requested.\n'
                  '• This screen demonstrates consent choices. It is not a substitute for an '
                  'approved research-participant consent process.',
                  style: SenseTypography.caption.copyWith(
                    color: SenseColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.favorite_border_rounded, color: SenseColors.blue800, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Whatever you choose here, support contacts (Tele-MANAS 14416, KIRAN '
            '1800-599-0019) stay listed in Settings, and the journal still shows them '
            'if a crisis phrase is typed.',
            style: SenseTypography.caption.copyWith(
              color: SenseColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
