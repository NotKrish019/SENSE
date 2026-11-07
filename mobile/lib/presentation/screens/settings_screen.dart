import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/prototype_copy.dart';
import '../widgets/sense_card.dart';
import '../../core/state/consent_preferences.dart';
import '../widgets/sense_navigation.dart';
import 'consent_screen.dart';

/// Profile & settings: the Profile tab's landing screen. Holds the (honest)
/// profile placeholder, support contacts, data & consent review, privacy and
/// data management, and app information.
class SettingsScreen extends StatefulWidget {
  /// True when shown as the Profile bottom-navigation tab (no back arrow).
  final bool isTabRoot;

  const SettingsScreen({super.key, this.isTabRoot = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: SenseAppBar(
        title: 'Profile & settings',
        showBackButton: !widget.isTabRoot,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading('Profile'),
              // Profile overview: only information that genuinely exists.
              SenseCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SenseColors.primaryActionGradient,
                      ),
                      child: const Icon(Icons.person_rounded, color: SenseColors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile setup is not available yet',
                          style: SenseTypography.h3.copyWith(
                            color: SenseColors.navy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This prototype has no accounts, so no name, ID or personal '
                          'details are stored.',
                          style: SenseTypography.caption.copyWith(color: SenseColors.textSecondary),
                        ),
                        Text(
                          'Personal baseline: not started',
                          style: SenseTypography.caption.copyWith(
                            color: SenseColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _sectionHeading('Support'),
              // Emergency Support Banner (Permanent out-of-band crisis assistance)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: SenseRadii.lgBorder,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.support_agent_rounded, color: Color(0xFFB45309), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                          '24/7 National Crisis Helplines',
                          style: SenseTypography.labelBold.copyWith(
                            color: const Color(0xFF92400E),
                            fontSize: 14,
                          ),
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you or someone you know is in acute distress, free support is available:\n'
                      '• Tele-MANAS: 14416 (Govt of India)\n'
                      '• KIRAN Helpline: 1800-599-0019\n'
                      '• Vandrevala Foundation: +91 9999 666 555',
                      style: SenseTypography.caption.copyWith(
                        color: const Color(0xFF78350F),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data & consent preferences: one shared, in-memory source of truth
              // (ConsentPreferences), reviewed on the same screen as onboarding.
              _sectionHeading('Data & consent'),
              Text(
                'Each input is optional. In this prototype your choices are kept only while '
                'the app is open, are not saved, and do not start any data collection.',
                style: SenseTypography.bodySecondary,
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: ConsentPreferences.instance,
                builder: (context, _) {
                  final prefs = ConsentPreferences.instance;
                  final on = InputModality.values.where(prefs.isEnabled).toList();
                  return SenseCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 12,
                      leading: const Icon(Icons.fact_check_outlined, color: SenseColors.blue600),
                      title: Text(
                        'Review data and consent preferences',
                        style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          on.isEmpty
                              ? 'Currently on: none (not saved)'
                              : 'Currently on: ${on.map((m) => '${m.code} ${m.title}').join(', ')} (not saved)',
                          style: SenseTypography.caption,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: SenseColors.textSecondary),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConsentScreen(isSettingsMode: true),
                        ),
                      ),
                    ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // DPDP Act 2023 Rights (Portability & Erasure)
              _sectionHeading('Privacy & data management'),
              Text(
                'Your data rights under the DPDP Act 2023.',
                style: SenseTypography.bodySecondary,
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_rounded, color: SenseColors.blue600),
                      title: Text('Export my data', style: SenseTypography.labelBold),
                      subtitle: Text(
                        'Not available yet — nothing is stored in this prototype.',
                        style: SenseTypography.caption,
                      ),
                      trailing: const Icon(Icons.chevron_right, color: SenseColors.textSecondary),
                      onTap: _exportData,
                    ),
                    const Divider(color: SenseColors.border, height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_forever_rounded, color: SenseColors.danger),
                      title: Text(
                        'Erase my data',
                        style: SenseTypography.labelBold.copyWith(color: SenseColors.danger),
                      ),
                      subtitle: Text(
                        'Not available yet — nothing is stored in this prototype.',
                        style: SenseTypography.caption,
                      ),
                      trailing: const Icon(Icons.chevron_right, color: SenseColors.danger),
                      onTap: _confirmPurge,
                    ),
                  ],
                ),
                ),
              ),
              const SizedBox(height: 28),

              _sectionHeading('About'),
              // Research & Legal Disclaimers
              Center(
                child: Text(
                  'SENSE 0.1.0 · UI prototype\n'
                  'Non-clinical research prototype. Compliance with ICMR guidelines and the '
                  'DPDP Act has not yet been assessed.',
                  style: SenseTypography.caption.copyWith(
                    color: SenseColors.textMuted,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: SenseTypography.h3.copyWith(color: SenseColors.navy900)),
      ),
    );
  }

  // Data rights are not implemented yet. Never simulate a successful export or
  // deletion: explain honestly what is missing instead.
  void _exportData() => _showUnavailable('Export not available yet', PrototypeCopy.exportUnavailable);

  void _confirmPurge() => _showUnavailable('Erase not available yet', PrototypeCopy.eraseUnavailable);

  void _showUnavailable(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: SenseTypography.h3),
        content: Text(message, style: SenseTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: SenseTypography.labelBold),
          ),
        ],
      ),
    );
  }
}
