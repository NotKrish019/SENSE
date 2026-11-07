import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_screen.dart';

/// Module 02: Granular Consent & Privacy Console.
/// Enforces itemized, revocable consent per modality in accordance with DPDP Act 2023.
class ConsentScreen extends StatefulWidget {
  final bool isSettingsMode;

  const ConsentScreen({super.key, this.isSettingsMode = false});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _consentM1 = true; // Structured check-ins
  bool _consentM2 = true; // Text journal
  bool _consentM3 = true; // Sleep tracking
  bool _consentM4 = true; // Workload tracking
  bool _consentM5 = false; // Voice (Phase 3 opt-in)
  bool _consentM6 = false; // Steps (Phase 3 opt-in)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Consent Console'),
        leading: widget.isSettingsMode ? null : const SizedBox(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            const Text(
              'Granular Modality Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'In accordance with India\'s DPDP Act 2023, every data stream is voluntary. '
              'Disabling a modality will never be treated as a negative stress signal.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),

            _buildModalityTile(
              title: 'M1: Daily Structured Check-ins',
              subtitle: '15-second momentary perceived stress and mood ratings.',
              value: _consentM1,
              onChanged: (v) => setState(() => _consentM1 = v),
            ),
            _buildModalityTile(
              title: 'M2: Reflective Text Journal',
              subtitle: 'Encrypted daily reflections with on-device safety scan.',
              value: _consentM2,
              onChanged: (v) => setState(() => _consentM2 = v),
            ),
            _buildModalityTile(
              title: 'M3: Sleep Tracking',
              subtitle: 'Manual rest logs or authorized Health Connect sync.',
              value: _consentM3,
              onChanged: (v) => setState(() => _consentM3 = v),
            ),
            _buildModalityTile(
              title: 'M4: Cognitive Workload',
              subtitle: 'Task load, deadline proximity, and perceived effort.',
              value: _consentM4,
              onChanged: (v) => setState(() => _consentM4 = v),
            ),
            _buildModalityTile(
              title: 'M5: Voice Acoustic Check-in (Optional)',
              subtitle: '20-second prompt; raw audio is immediately erased after feature extraction.',
              value: _consentM5,
              onChanged: (v) => setState(() => _consentM5 = v),
            ),
            _buildModalityTile(
              title: 'M6: Physical Steps (Optional)',
              subtitle: 'Daily step count via OS health platform integration.',
              value: _consentM6,
              onChanged: (v) => setState(() => _consentM6 = v),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (widget.isSettingsMode) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    );
                  }
                },
                child: Text(
                  widget.isSettingsMode ? 'Save Preferences' : 'Confirm Consent & Enter MindPulse',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalityTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        activeColor: AppTheme.primaryTeal,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

