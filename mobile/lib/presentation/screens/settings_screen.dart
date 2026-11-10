import 'package:flutter/material.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/state/consent_preferences.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/meadow_band.dart';
import '../nature/nature_editorial.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_logo.dart';
import 'consent_screen.dart';

/// Production Profile & settings (Living Landscapes, Phase 2).
///
/// The Profile tab's landing page: an honest profile placeholder (there are
/// no accounts), support contacts, data and consent review, privacy and data
/// rights (Export and Erase are honestly unavailable), and app information.
/// Nothing here stores, exports or deletes anything.
class SettingsScreen extends StatefulWidget {
  /// True when shown as the Profile navigation tab (no back control).
  final bool isTabRoot;

  const SettingsScreen({super.key, this.isTabRoot = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
          onBack: widget.isTabRoot ? null : () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          band: (desktop) =>
              MeadowBand(seed: 11, sunX: desktop ? 0.86 : 0.8, contours: false, path: true, tornBottom: desktop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile', style: NatureType.eyebrow),
              const SizedBox(height: 8),
              const NatureHeading('Profile & settings'),
              const SizedBox(height: 18),
              _profile(),
              const SizedBox(height: 28),
              _support(),
              const SizedBox(height: 30),
              _consent(context),
              const SizedBox(height: 30),
              _privacy(),
              const SizedBox(height: 28),
              const SprigRule(),
              const SizedBox(height: 22),
              _about(),
            ],
          ),
        ),
      ),
    );
  }

  // Only information that genuinely exists: there are no accounts.
  Widget _profile() {
    return LayoutBuilder(builder: (context, c) {
      // Narrow screens with large text: the (decorative) avatar sits above
      // the text so the heading keeps a readable line length.
      final stacked = c.maxWidth < 360 && MediaQuery.textScalerOf(context).scale(1) >= 1.3;
      final avatar = ExcludeSemantics(
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: NatureColors.paleSage, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: NatureColors.forest, size: 28),
          ),
        );
      const text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile setup is not available yet', style: NatureType.statusTitle),
              SizedBox(height: 4),
              Text(
                'This prototype has no accounts, so no name, ID or personal details are stored.',
                style: NatureType.bodyMuted,
              ),
              SizedBox(height: 4),
              Text('Personal baseline: not started',
                  style: TextStyle(
                      fontFamily: NatureType.family,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: NatureColors.textSecondary)),
            ],
          );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [avatar, const SizedBox(height: 12), text],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [avatar, const SizedBox(width: 14), const Expanded(child: text)],
      );
    });
  }

  // Out-of-band crisis support, always visible on this page.
  Widget _support() {
    const lines = [
      ('Tele-MANAS', '14416 (Govt of India)'),
      ('KIRAN Helpline', '1800-599-0019'),
      ('Vandrevala Foundation', '+91 9999 666 555'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: NatureColors.dustyCoral, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support', style: NatureType.eyebrow.copyWith(color: NatureColors.coralInk)),
          const SizedBox(height: 4),
          Semantics(
              header: true,
              child: const Text('24/7 national crisis helplines', style: NatureType.sectionTitle)),
          const SizedBox(height: 6),
          const Text(
            'If you or someone you know is in acute distress, free support is available:',
            style: NatureType.body,
          ),
          const SizedBox(height: 8),
          for (final (name, number) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$name: ', style: NatureType.body),
                  TextSpan(text: number, style: NatureType.label.copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // Data & consent preferences: one shared source of truth
  // (ConsentPreferences, in memory unless storage is ready), reviewed on the
  // same screen as onboarding.
  Widget _consent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NatureSectionHeading(
          'Data & consent',
          lede: 'Each input is optional, and your choices do not start any data collection. '
              'Below it says whether they are saved.',
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: ConsentPreferences.instance,
          builder: (context, _) {
            final prefs = ConsentPreferences.instance;
            final on = InputModality.values.where(prefs.isEnabled).toList();
            final note = prefs.savedStateNote;
            return NatureIndex(rows: [
              NatureIndexRow(
                icon: Icons.fact_check_outlined,
                title: 'Review data and consent preferences',
                detail: on.isEmpty
                    ? 'Currently on: none ($note)'
                    : 'Currently on: ${on.map((m) => '${m.code} ${m.title}').join(', ')} ($note)',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConsentScreen(isSettingsMode: true)),
                ),
              ),
            ]);
          },
        ),
      ],
    );
  }

  // DPDP Act 2023 rights (portability and erasure): not implemented yet.
  Widget _privacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NatureSectionHeading('Privacy & data management',
            lede: 'Your data rights under the DPDP Act 2023.'),
        const SizedBox(height: 12),
        NatureIndex(rows: [
          NatureIndexRow(
            icon: Icons.download_rounded,
            title: 'Export my data',
            detail: 'Not available yet: nothing is stored in this prototype.',
            onTap: _exportData,
          ),
          NatureIndexRow(
            icon: Icons.delete_outline_rounded,
            title: 'Erase my data',
            detail: 'Not available yet: nothing is stored in this prototype.',
            caution: true,
            onTap: _confirmPurge,
          ),
        ]),
      ],
    );
  }

  Widget _about() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NatureSectionHeading('About'),
        const SizedBox(height: 12),
        const SenseLogo(
          variant: SenseLogoVariant.forestBadge,
          markSize: 32,
          wordmarkColor: NatureColors.forest,
          fontSize: 15,
        ),
        const SizedBox(height: 12),
        Text(
          'SENSE 0.1.0 · UI prototype\n'
          'Non-clinical research prototype. Compliance with ICMR guidelines and the '
          'DPDP Act has not yet been assessed.',
          style: NatureType.bodyMuted.copyWith(fontSize: 13),
        ),
      ],
    );
  }

  // Data rights are not implemented yet. Never simulate a successful export or
  // deletion: explain honestly what is missing instead.
  void _exportData() => showNatureInfoDialog(context,
      title: 'Export not available yet', message: PrototypeCopy.exportUnavailable);

  void _confirmPurge() => showNatureInfoDialog(context,
      title: 'Erase not available yet', message: PrototypeCopy.eraseUnavailable);
}
