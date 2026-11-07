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
                  color: SenseColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: SenseColors.blue600, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Baseline Active',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SenseColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Observations will be compared with your own recent history.',
                      style: TextStyle(fontSize: 13, color: SenseColors.textMuted),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: SenseColors.textPrimary),
                ),
                Text(
                  'Day $daysCompleted of ${AppConstants.calibrationDaysRequired}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: SenseColors.textAccent),
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
                valueColor: const AlwaysStoppedAnimation<Color>(SenseColors.blue600),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No patterns are shown until enough days have been recorded, to avoid misleading results from too little data.',
              style: TextStyle(fontSize: 12, color: SenseColors.textMuted, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

