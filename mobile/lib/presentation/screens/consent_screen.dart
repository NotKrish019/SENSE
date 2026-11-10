import 'package:flutter/material.dart';

import '../../core/state/consent_preferences.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/arrival_art.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_tappable.dart';
import 'main_shell.dart';

/// Data & consent preferences for the six optional inputs (M1–M6).
///
/// Shown after onboarding (Splash → Onboarding → Consent → Home) and from
/// Profile & settings ("Review data and consent preferences").
///
/// Living Landscapes (Phase 5) design. The preference model
/// ([ConsentPreferences]: identifiers M1–M6, all off by default), the wording
/// of every choice, and the completion behaviour are unchanged: "Continue to
/// SENSE" opens Home as the only route; in settings mode "Done" returns to
/// Profile.
///
/// Milestone K1: where the choices are kept is stated honestly from
/// [ConsentPreferences.persistence]. By default (no storage) they are held in
/// memory only, with the original wording. When storage is ready each change
/// is saved first and shown only after it succeeded; a failed save changes
/// nothing and says so. Choices never start any data collection, no OS
/// permission is requested, and this is not a research-participant consent
/// process.
class ConsentScreen extends StatefulWidget {
  /// True when opened from Settings: the action returns to Settings instead
  /// of entering the dashboard.
  final bool isSettingsMode;

  const ConsentScreen({super.key, this.isSettingsMode = false});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ConsentPreferences.instance;
    final settings = widget.isSettingsMode;
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          maxSheetWidth: 760,
          band: (desktop) => GateBand(tornBottom: desktop),
          child: ListenableBuilder(
            listenable: prefs,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(settings ? 'Profile · data & consent' : 'Data & consent preferences',
                    style: NatureType.eyebrow),
                const SizedBox(height: 8),
                const NatureHeading('Choose what you would like to share'),
                const SizedBox(height: 8),
                const Text(
                  'All six inputs are optional and off by default. You can continue '
                  'with none of them turned on, and skipping an input will never be '
                  'treated as a sign of stress.',
                  style: NatureType.bodyMuted,
                ),
                const SizedBox(height: 18),
                _PrototypeNotice(persistence: prefs.persistence, development: prefs.isDevelopmentStorage),
                const SizedBox(height: 26),
                for (final m in InputModality.values) ...[
                  _ConsentChoice(
                    modality: m,
                    info: _modalityInfo[m]!,
                    value: prefs.isEnabled(m),
                    saving: prefs.isPending(m),
                    enabled: prefs.persistence != ConsentPersistence.loading && !prefs.isPending(m),
                    onChanged: (v) => _change(context, prefs, m, v),
                  ),
                  if (m != InputModality.values.last)
                    const Divider(height: 1, thickness: 1, color: NatureColors.divider),
                ],
                const SizedBox(height: 22),
                const _SupportNote(),
                const SizedBox(height: 22),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${prefs.enabledCount} of ${InputModality.values.length} inputs turned on '
                    '(${_countNote(prefs)}).',
                    style: NatureType.label.copyWith(color: NatureColors.ink),
                  ),
                ),
                const SizedBox(height: 14),
                NaturePrintedAction(
                  label: settings ? 'Done' : 'Continue to SENSE',
                  icon: settings ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  onTap: () => _onContinue(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _countNote(ConsentPreferences prefs) => switch (prefs.persistence) {
        ConsentPersistence.memoryOnly => 'kept only while the app is open',
        ConsentPersistence.storageUnavailable => 'kept only while the app is open; secure storage unavailable',
        ConsentPersistence.loading => 'loading saved choices',
        ConsentPersistence.persisted =>
          prefs.isDevelopmentStorage ? 'saved to development storage' : 'saved on this device',
      };

  /// Applies one change and reports a save that did not happen. The value
  /// shown is always the model's value: it changes only after a save succeeded.
  Future<void> _change(BuildContext context, ConsentPreferences prefs, InputModality m, bool v) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await prefs.setEnabled(m, v);
    final message = switch (result) {
      ConsentChangeResult.failed => 'Your choice for ${m.title} could not be saved, so nothing was changed.',
      ConsentChangeResult.notReady => 'Your saved choices are still loading. Nothing was changed.',
      _ => null,
    };
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _onContinue(BuildContext context) {
    if (widget.isSettingsMode) {
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

/// One consent choice: the whole header row is a single toggle (announced
/// with its on/off state), followed by what the input involves, why it may be
/// useful and what it does in this prototype. The state is shown in words
/// ("On" / "Off") as well as by the switch.
class _ConsentChoice extends StatelessWidget {
  final InputModality modality;
  final _ModalityInfo info;
  final bool value;
  final bool saving;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ConsentChoice({
    required this.modality,
    required this.info,
    required this.value,
    required this.onChanged,
    this.saving = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final available = modality.isAvailableInPrototype;
    final title = '${modality.code} · ${modality.title}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SenseTappable(
            semanticLabel: '$title. ${info.statusLabel}',
            toggled: value,
            onTap: enabled ? () => onChanged(!value) : null,
            focusColor: NatureColors.focus,
            hoverColor: NatureColors.hover,
            borderRadius: NatureRadii.smBorder,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: NatureType.label.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusTag(label: info.statusLabel, available: available),
                              Text(saving ? (value ? 'On · saving…' : 'Off · saving…') : (value ? 'On' : 'Off'),
                                  style: NatureType.label.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: value ? NatureColors.forest : NatureColors.inkMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PrintedSwitch(on: value),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
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
        TextSpan(children: [
          TextSpan(text: '$heading: ', style: NatureType.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          TextSpan(text: body, style: NatureType.bodyMuted),
        ]),
      ),
    );
  }
}

/// The availability of an input, in words, on a quiet tag.
class _StatusTag extends StatelessWidget {
  final String label;
  final bool available;
  const _StatusTag({required this.label, required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: available ? NatureColors.sageWash : NatureColors.paper,
        borderRadius: NatureRadii.smBorder,
        border: Border.all(color: available ? NatureColors.forest : NatureColors.ochreInk),
      ),
      child: Text(label,
          style: NatureType.eyebrow.copyWith(
              fontSize: 12, color: available ? NatureColors.forest : NatureColors.ochreInk)),
    );
  }
}

/// A printed switch: a paper track with an outlined knob. On: forest track,
/// knob to the right and a check mark; off: outlined track, knob to the left.
/// The knob moves instantly with reduced motion. Decorative: the row it sits
/// in is the toggle and carries the state.
class _PrintedSwitch extends StatelessWidget {
  final bool on;
  const _PrintedSwitch({required this.on});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: still ? Duration.zero : NatureMotion.selection,
        curve: NatureMotion.ease,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? NatureColors.forest : NatureColors.paper,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: on ? NatureColors.forest : NatureColors.borderStrong, width: 1.5),
        ),
        child: AnimatedAlign(
          duration: still ? Duration.zero : NatureMotion.selection,
          curve: NatureMotion.ease,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? NatureColors.paper : NatureColors.borderStrong,
            ),
            child: on ? const Icon(Icons.check_rounded, size: 15, color: NatureColors.forest) : null,
          ),
        ),
      ),
    );
  }
}

/// How this screen works. In memory (the default) the original wording is
/// kept unchanged; otherwise the first point states where choices are kept.
class _PrototypeNotice extends StatelessWidget {
  final ConsentPersistence persistence;
  final bool development;
  const _PrototypeNotice({required this.persistence, required this.development});

  static const String _inMemory = 'Your choices are kept only while the app is open. They are not saved and are lost if you '
      'refresh or close it.';

  String get _where => switch (persistence) {
        ConsentPersistence.memoryOnly => _inMemory,
        ConsentPersistence.storageUnavailable =>
          'Secure storage is unavailable, so your choices are kept only while the app is open. '
              'They are not saved and are lost if you refresh or close it.',
        ConsentPersistence.loading => 'Your saved choices are loading. Changes are possible once they have loaded.',
        ConsentPersistence.persisted => development
            ? 'Your choices are saved to development storage on this device, an encrypted test '
                'database for development only. Development data is not for participants.'
            : 'Your choices are saved in encrypted storage on this device. Each change is saved '
                'before it is shown.',
      };

  @override
  Widget build(BuildContext context) {
    final points = [
      _where,
      'Turning an input on does not start any data collection, and no phone or browser permission '
          'is requested.',
      'This screen demonstrates consent choices. It is not a substitute for an approved '
          'research-participant consent process.',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: NatureColors.sunOchre, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prototype demonstration', style: NatureType.eyebrow.copyWith(color: NatureColors.ochreInk)),
          const SizedBox(height: 6),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 9, right: 10),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 5,
                        height: 5,
                        child: DecoratedBox(
                            decoration: BoxDecoration(color: NatureColors.ochreInk, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                  Expanded(child: Text(p, style: NatureType.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SupportNote extends StatelessWidget {
  const _SupportNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: ExcludeSemantics(child: Icon(Icons.support_rounded, color: NatureColors.coralInk, size: 20)),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Whatever you choose here, support contacts (Tele-MANAS 14416, KIRAN '
            '1800-599-0019) stay listed in Settings, and the journal still shows them '
            'if a crisis phrase is typed.',
            style: NatureType.bodyMuted,
          ),
        ),
      ],
    );
  }
}
