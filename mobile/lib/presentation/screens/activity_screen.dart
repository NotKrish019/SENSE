import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _steps = 6800;
  int _activeMinutes = 35;
  bool _healthConnectConnected = false;
  bool _isSaving = false;

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Movement',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$_steps Steps • $_activeMinutes Mins Active',
                          style: SenseTypography.h3.copyWith(
                            color: SenseColors.navy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1,000', style: SenseTypography.caption),
                        Text(
                          '$_steps steps',
                          style: SenseTypography.h2.copyWith(
                            color: SenseColors.blue800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('20,000', style: SenseTypography.caption),
                      ],
                    ),
                    Slider(
                      value: _steps.toDouble(),
                      min: 1000,
                      max: 20000,
                      divisions: 38,
                      activeColor: SenseColors.blue600,
                      inactiveColor: const Color(0xFFD6EFFC),
                      onChanged: (v) => setState(() => _steps = v.round()),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0 mins', style: SenseTypography.caption),
                        Text(
                          '$_activeMinutes mins',
                          style: SenseTypography.h2.copyWith(
                            color: SenseColors.blue800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('120 mins', style: SenseTypography.caption),
                      ],
                    ),
                    Slider(
                      value: _activeMinutes.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      activeColor: SenseColors.blue600,
                      inactiveColor: const Color(0xFFD6EFFC),
                      onChanged: (v) => setState(() => _activeMinutes = v.round()),
                    ),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sync_rounded, color: SenseColors.blue600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Auto-sync with Health Connect',
                              style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
                            ),
                          ],
                        ),
                        Switch(
                          value: _healthConnectConnected,
                          activeColor: SenseColors.cyan500,
                          onChanged: (v) {
                            setState(() => _healthConnectConnected = v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(v
                                    ? 'Health Connect permission mock granted (Phase 3 feature).'
                                    : 'Auto-sync disabled. Using manual logging.'),
                                backgroundColor: SenseColors.navy900,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Zero GPS or continuous background location tracking. Only aggregated daily step totals are read with your explicit permission.',
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
                isLoading: _isSaving,
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
    setState(() => _isSaving = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity metrics added to personal baseline.'),
            backgroundColor: SenseColors.navy900,
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }
}

