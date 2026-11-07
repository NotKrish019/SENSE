import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sense_tappable.dart';
import '../../core/constants/prototype_copy.dart';

class SenseFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SenseFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 48 px tall touch target; the visible chip stays compact and centred.
    return SenseTappable(
      semanticLabel: label,
      selected: isSelected,
      onTap: onTap,
      borderRadius: SenseRadii.pillBorder,
      child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
      heightFactor: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SenseColors.navy900 : SenseColors.surface,
          borderRadius: SenseRadii.pillBorder,
          border: Border.all(
            color: isSelected ? SenseColors.navy900 : SenseColors.border,
            width: 1.0,
          ),
          boxShadow: isSelected ? SenseShadows.recessed : [],
        ),
        child: Text(
          label,
          style: isSelected
              ? SenseTypography.captionMedium.copyWith(
                  color: SenseColors.white,
                  fontWeight: FontWeight.w600,
                )
              : SenseTypography.captionMedium.copyWith(
                  color: SenseColors.textSecondary,
                ),
        ),
      ),
      ),
      ),
    );
  }
}

enum StressStatusLevel { good, moderate, high }

class SenseStatusTag extends StatelessWidget {
  final StressStatusLevel level;
  final String? customLabel;

  const SenseStatusTag({
    super.key,
    required this.level,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String labelText;

    switch (level) {
      case StressStatusLevel.good:
        dotColor = SenseColors.success;
        labelText = customLabel ?? 'Good';
        break;
      case StressStatusLevel.moderate:
        dotColor = SenseColors.warning;
        labelText = customLabel ?? 'Moderate';
        break;
      case StressStatusLevel.high:
        dotColor = SenseColors.danger;
        labelText = customLabel ?? 'High';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SenseColors.surface,
        borderRadius: SenseRadii.pillBorder,
        border: Border.all(color: SenseColors.border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            labelText,
            style: SenseTypography.captionMedium.copyWith(
              color: SenseColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SenseProvenanceBadge extends StatelessWidget {
  final String text; // e.g. "You reported" or "Observed pattern"
  final IconData? icon;

  const SenseProvenanceBadge({
    super.key,
    required this.text,
    this.icon,
  });

  /// Shared label for hard-coded illustrative values (see PrototypeCopy).
  /// Never use it on information the user actually entered.
  const SenseProvenanceBadge.sampleData({super.key})
      : text = PrototypeCopy.sampleDataLabel,
        icon = Icons.science_outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SenseColors.background,
        borderRadius: SenseRadii.smBorder,
        border: Border.all(color: const Color(0xFFC0E4F9), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: SenseColors.blue800),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: SenseTypography.caption.copyWith(
                color: SenseColors.blue800,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

