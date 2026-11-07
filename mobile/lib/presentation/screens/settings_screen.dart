import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_inputs.dart';
import '../widgets/sense_navigation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Granular consent state per modality
  bool _consentCheckIn = true;
  bool _consentSleep = true;
  bool _consentWorkload = true;
  bool _consentJournal = true;
  bool _consentVoice = false;
  bool _consentActivity = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(
        title: 'Privacy & Profile',
        showBackButton: false,
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
              // Participant Profile Card
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Participant Profile',
                          style: SenseTypography.h3.copyWith(
                            color: SenseColors.navy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: usr_8f3d4a92 (Pseudonymous)',
                          style: SenseTypography.caption.copyWith(color: SenseColors.textSecondary),
                        ),
                        Text(
                          'Baseline: Calibrated (Day 15/14)',
                          style: SenseTypography.caption.copyWith(
                            color: SenseColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                        Text(
                          '24/7 National Crisis Helplines',
                          style: SenseTypography.labelBold.copyWith(
                            color: const Color(0xFF92400E),
                            fontSize: 14,
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

              // Granular Modality Consent
              Text(
                'Granular Modality Consent',
                style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 6),
              Text(
                'Every modality is separately opt-in. Disabling an indicator removes it from late fusion without penalizing your baseline.',
                style: SenseTypography.bodySecondary,
              ),
              const SizedBox(height: 12),
              SenseCard(
                child: Column(
                  children: [
                    SenseToggleSwitch(
                      label: 'M1: Structured Check-ins',
                      value: _consentCheckIn,
                      onChanged: (v) => setState(() => _consentCheckIn = v),
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    SenseToggleSwitch(
                      label: 'M2: Daily Journal Analysis',
                      value: _consentJournal,
                      onChanged: (v) => setState(() => _consentJournal = v),
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    SenseToggleSwitch(
                      label: 'M3: Sleep Tracking',
                      value: _consentSleep,
                      onChanged: (v) => setState(() => _consentSleep = v),
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    SenseToggleSwitch(
                      label: 'M4: Workload & Task Demands',
                      value: _consentWorkload,
                      onChanged: (v) => setState(() => _consentWorkload = v),
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    SenseToggleSwitch(
                      label: 'M5: Voice Prosody Samples',
                      value: _consentVoice,
                      onChanged: (v) => setState(() => _consentVoice = v),
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    SenseToggleSwitch(
                      label: 'M6: Physical Activity Sync',
                      value: _consentActivity,
                      onChanged: (v) => setState(() => _consentActivity = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // DPDP Act 2023 Rights (Portability & Erasure)
              Text(
                'DPDP Act 2023 Data Rights',
                style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_rounded, color: SenseColors.blue600),
                      title: Text('Export Personal Records (JSON)', style: SenseTypography.labelBold),
                      subtitle: Text(
                        'Section 12: Receive all check-ins, sleep, workload, and inferences.',
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
                        'Permanently Erase All Data',
                        style: SenseTypography.labelBold.copyWith(color: SenseColors.danger),
                      ),
                      subtitle: Text(
                        'Section 13: Hard-purge all SQLite tables and personal baseline state.',
                        style: SenseTypography.caption,
                      ),
                      trailing: const Icon(Icons.chevron_right, color: SenseColors.danger),
                      onTap: _confirmPurge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Research & Legal Disclaimers
              Center(
                child: Text(
                  'SENSE Version 0.1.0 (Phase 2 MVP)\n'
                  'Non-Clinical Research Platform • Indian ICMR Ethical Guidelines Compliant',
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

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported structured user data JSON fulfilling DPDP Section 12.'),
        backgroundColor: SenseColors.navy900,
      ),
    );
  }

  void _confirmPurge() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Permanently Erase Data?', style: SenseTypography.h3),
        content: Text(
          'Under the DPDP Act 2023, this will completely delete all check-ins, sleep logs, journal reflections, and your baseline from the encrypted database. This action is irreversible.',
          style: SenseTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: SenseTypography.label),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All personal records have been permanently erased.'),
                  backgroundColor: SenseColors.danger,
                ),
              );
            },
            child: Text(
              'Erase Everything',
              style: SenseTypography.labelBold.copyWith(color: SenseColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
