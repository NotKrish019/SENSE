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
    Widget toggle = GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: SenseRadii.pillBorder,
          color: value ? SenseColors.cyan500 : const Color(0xFFD6E7F2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SenseColors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33012F5F),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (label != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label!,
            style: SenseTypography.body.copyWith(
              color: SenseColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          toggle,
        ],
      );
    }

    return toggle;
  }
}

