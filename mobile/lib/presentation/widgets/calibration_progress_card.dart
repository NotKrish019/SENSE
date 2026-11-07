import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Calibration Progress Ring & Status Indicator.
/// Suppresses premature baseline alerts while visually reassuring the user.
class CalibrationProgressCard extends StatelessWidget {
  final int daysCompleted;
  final bool isCalibrated;

  const CalibrationProgressCard({
    super.key,
    required this.daysCompleted,
    required this.isCalibrated,
  });

  @override
  Widget build(BuildContext context) {
    if (isCalibrated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentSage.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTeal, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Baseline Active',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Insights are personalized against your 14-day dynamic equilibrium.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = (daysCompleted / AppConstants.calibrationDaysRequired).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Calibrating Personal Baseline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                ),
                Text(
                  'Day $daysCompleted of ${AppConstants.calibrationDaysRequired}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryTeal),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Early warnings are suppressed during calibration to prevent false alarms. Continue your daily reflections to build an accurate personal model.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

