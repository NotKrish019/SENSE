import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sense_card.dart';
import 'sense_chips.dart';

class SenseInsightCard extends StatelessWidget {
  final String title;
  final String narrative;
  final String provenance;
  final VoidCallback? onTap;

  const SenseInsightCard({
    super.key,
    this.title = 'Insight',
    required this.narrative,
    this.provenance = 'Observed pattern',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SenseCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity, // lets spaceBetween reach the right edge
            child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F8FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBCE7FD), width: 1.0),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: SenseColors.blue600,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                    title,
                    style: SenseTypography.h3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SenseColors.navy900,
                    ),
                  ),
                  ),
                ],
              ),
              SenseProvenanceBadge(text: provenance),
            ],
          ),
          ),
          const SizedBox(height: 12),
          Text(
            narrative,
            style: SenseTypography.body.copyWith(
              color: SenseColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'View observation details',
                    style: SenseTypography.labelBold.copyWith(
                      color: SenseColors.textAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: SenseColors.blue600,
                  size: 14,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

