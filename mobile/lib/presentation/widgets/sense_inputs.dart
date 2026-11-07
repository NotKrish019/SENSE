import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SenseInputField extends StatelessWidget {
  final String? label;
  final String hintText;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const SenseInputField({
    super.key,
    this.label,
    required this.hintText,
    this.controller,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: SenseTypography.labelBold.copyWith(
              color: SenseColors.navy900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: SenseColors.white,
            borderRadius: SenseRadii.mdBorder,
            border: Border.all(color: SenseColors.border, width: 1.2),
            boxShadow: SenseShadows.recessed,
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: SenseTypography.body.copyWith(color: SenseColors.textPrimary),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: SenseTypography.bodySecondary.copyWith(color: SenseColors.textMuted),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: SenseColors.textSecondary, size: 20)
                  : null,
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class SenseToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  const SenseToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Visual states meet 3:1 against the white card: on = Electric Blue track
    // (3.1:1) with white thumb; off = white track with a slate outline and
    // slate thumb (5.1:1). State is also exposed to screen readers.
    final track = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: SenseRadii.pillBorder,
        color: value ? SenseColors.blue600 : SenseColors.white,
        border: Border.all(
          color: value ? SenseColors.blue600 : SenseColors.textMuted,
          width: 1.5,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? SenseColors.white : SenseColors.textMuted,
          ),
        ),
      ),
    );

    // The whole row (label + track) is the touch target when labelled.
    final content = label == null
        ? track
        : Row(
            children: [
              Expanded(
                child: Text(
                  label!,
                  style: SenseTypography.body.copyWith(
                    color: SenseColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              track,
            ],
          );

    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(heightFactor: 1, child: content),
        ),
      ),
    );
  }
}


/// Min / current value / max labels shown above a slider.
///
/// Normally one row (min · value · max). When the screen is narrow or text is
/// large, the value moves to its own line and the min/max labels wrap as whole
/// labels (never breaking mid-word or overlapping).
class SenseSliderLabels extends StatelessWidget {
  final String minLabel;
  final String valueLabel;
  final String maxLabel;
  final TextStyle? valueStyle;

  const SenseSliderLabels({
    super.key,
    required this.minLabel,
    required this.valueLabel,
    required this.maxLabel,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final value = Text(
      valueLabel,
      textAlign: TextAlign.center,
      style: valueStyle ?? SenseTypography.labelBold.copyWith(color: SenseColors.blue800),
    );
    final min = Text(minLabel, style: SenseTypography.caption);
    final max = Text(maxLabel, textAlign: TextAlign.end, style: SenseTypography.caption);
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = scale >= 1.3 || constraints.maxWidth < 300;
        if (stacked) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: value),
              const SizedBox(height: 4),
              // Natural widths: if both ends don't fit on one line, the max
              // label moves to its own line rather than breaking mid-word.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 2,
                  children: [min, max],
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: min),
            const SizedBox(width: 4),
            Expanded(flex: 2, child: value),
            const SizedBox(width: 4),
            Expanded(child: max),
          ],
        );
      },
    );
  }
}
