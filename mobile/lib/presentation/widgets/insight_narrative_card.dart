import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/late_fusion_engine.dart';

/// Evidence-linked, factor-attributed explanation card.
/// Replaces opaque numbers with contextual narrative synthesis.
class InsightNarrativeCard extends StatelessWidget {
  final FusionOutput output;

  const InsightNarrativeCard({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    final isAlert = output.isAlertTriggered;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAlert ? AppTheme.alertAmber.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAlert ? Icons.info_outline_rounded : Icons.auto_awesome_rounded,
                  color: isAlert ? AppTheme.alertAmber : AppTheme.primaryTeal,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isAlert ? 'Observed Pattern Shift' : 'Daily Well-Being Insight',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isAlert ? AppTheme.alertAmber : AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              output.explanationNarrative,
              style: const TextStyle(fontSize: 14, color: AppTheme.textDark, height: 1.45),
            ),
            if (output.factorAttributions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'Contributing Factors Today:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: output.factorAttributions.entries.map((e) {
                  final isElevated = e.value > 0;
                  return Chip(
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isElevated
                        ? Colors.amber.shade50
                        : Colors.teal.shade50,
                    label: Text(
                      '${e.key}: ${isElevated ? "+" : ""}${(e.value * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isElevated ? Colors.amber.shade900 : AppTheme.primaryTeal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

