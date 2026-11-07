import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sample_data_banner.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';
import '../widgets/sense_inputs.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _steps = 6800;
  int _activeMinutes = 35;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(title: 'Physical Activity'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Banner
              SenseCard(
                color: SenseColors.surface,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD6EFFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: SenseColors.blue600,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your entry (manual)',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$_steps steps • $_activeMinutes active mins',
                          style: SenseTypography.h3.copyWith(
                            color: SenseColors.navy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Steps Input Slider
              Text(
                'Daily Step Count (Manual Entry)',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Column(
                  children: [
                    SenseSliderLabels(
                      minLabel: '1,000',
                      valueLabel: '$_steps steps',
                      maxLabel: '20,000',
                      valueStyle: SenseTypography.h2.copyWith(
                        color: SenseColors.blue800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    MergeSemantics(child: Semantics(
                      // Name merged into the slider's own node (Task 8): it previously had none.
                      label: 'Steps',
                      child: Slider(
                        semanticFormatterCallback: (v) => '${v.round()} steps',
                        value: _steps.toDouble(),
                        min: 1000,
                        max: 20000,
                        divisions: 38,
                        activeColor: SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _steps = v.round()),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Minutes
              Text(
                'Active Exercise Minutes',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Column(
                  children: [
                    SenseSliderLabels(
                      minLabel: '0 mins',
                      valueLabel: '$_activeMinutes mins',
                      maxLabel: '120 mins',
                      valueStyle: SenseTypography.h2.copyWith(
                        color: SenseColors.blue800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    MergeSemantics(child: Semantics(
                      // Name merged into the slider's own node (Task 8): it previously had none.
                      label: 'Active minutes',
                      child: Slider(
                        semanticFormatterCallback: (v) => '${v.round()} minutes',
                        value: _activeMinutes.toDouble(),
                        min: 0,
                        max: 120,
                        divisions: 24,
                        activeColor: SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _activeMinutes = v.round()),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Health Connect / HealthKit Optional Connection
              SenseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: SenseColors.blue600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Health Connect sync (planned)',
                            style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
                          ),
                        ),
                        // Always off: announced as an unavailable option, never as granted.
                        Semantics(
                          label: 'Health Connect sync, not available in this prototype',
                          child: Switch(
                          value: false,
                          activeThumbColor: SenseColors.cyan500,
                          // Not implemented: never simulate a granted permission.
                          onChanged: (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Health Connect sync is not available in this prototype. '
                                    'No permission was requested and no data was read.'),
                                backgroundColor: SenseColors.navy900,
                              ),
                            );
                          },
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Not connected yet. If added later, it would read only daily step '
                      'totals, with your explicit permission — no GPS or background '
                      'location tracking.',
                      style: SenseTypography.caption.copyWith(
                        color: SenseColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Save Activity Entry',
                icon: Icons.save_rounded,
                onPressed: _saveActivity,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _saveActivity() {
    // Persistence is not connected yet: report that honestly.
    showPrototypeNotSavedMessage(context, 'activity entry');
  }
}

