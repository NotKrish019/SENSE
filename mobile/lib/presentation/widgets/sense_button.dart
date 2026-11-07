import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum SenseButtonVariant { primary, secondary, outline, text }

class SenseButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final SenseButtonVariant variant;
  final IconData? icon;
  final bool isIconTrailing;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final BorderRadius? borderRadius;

  const SenseButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SenseButtonVariant.primary,
    this.icon,
    this.isIconTrailing = true,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 50.0,
    this.borderRadius,
  });

  @override
  State<SenseButton> createState() => _SenseButtonState();
}

class _SenseButtonState extends State<SenseButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final radius = widget.borderRadius ?? SenseRadii.pillBorder;

    Widget content;
    if (widget.isLoading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.variant == SenseButtonVariant.primary
                    ? SenseColors.white
                    : SenseColors.blue600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Saving...',
            style: widget.variant == SenseButtonVariant.primary
                ? SenseTypography.buttonLabel
                : SenseTypography.buttonLabel.copyWith(color: SenseColors.navy900),
          ),
        ],
      );
    } else {
      final List<Widget> children = [];
      final iconWidget = widget.icon != null
          ? Icon(
              widget.icon,
              size: 18,
              color: widget.variant == SenseButtonVariant.primary
                  ? SenseColors.white
                  : widget.variant == SenseButtonVariant.outline
                      ? SenseColors.blue600
                      : SenseColors.navy900,
            )
          : null;

      if (iconWidget != null && !widget.isIconTrailing) {
        children.add(iconWidget);
        children.add(const SizedBox(width: 8));
      }

      children.add(
        Flexible(
          child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: widget.variant == SenseButtonVariant.primary
              ? SenseTypography.buttonLabel
              : widget.variant == SenseButtonVariant.outline
                  ? SenseTypography.buttonLabel.copyWith(color: SenseColors.blue800)
                  : widget.variant == SenseButtonVariant.text
                      ? SenseTypography.buttonLabel.copyWith(color: SenseColors.textAccent)
                      : SenseTypography.buttonLabel.copyWith(color: SenseColors.navy900),
        ),
        ),
      );

      if (iconWidget != null && widget.isIconTrailing) {
        children.add(const SizedBox(width: 8));
        children.add(iconWidget);
      }

      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      );
    }

    BoxDecoration decoration;
    switch (widget.variant) {
      case SenseButtonVariant.primary:
        decoration = BoxDecoration(
          borderRadius: radius,
          gradient: isDisabled
              ? LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                )
              : _isPressed
                  ? const LinearGradient(
                      colors: [Color(0xFF02549B), Color(0xFF012F5F)],
                    )
                  : SenseColors.primaryButtonGradient,
          boxShadow: isDisabled || _isPressed ? [] : SenseShadows.card,
        );
        break;

      case SenseButtonVariant.secondary:
        decoration = BoxDecoration(
          color: isDisabled ? Colors.grey.shade200 : SenseColors.white,
          borderRadius: radius,
          border: Border.all(color: SenseColors.border, width: 1.2),
          boxShadow: isDisabled || _isPressed ? [] : SenseShadows.card,
        );
        break;

      case SenseButtonVariant.outline:
        decoration = BoxDecoration(
          color: _isPressed ? SenseColors.background : Colors.transparent,
          borderRadius: radius,
          border: Border.all(
            color: isDisabled ? Colors.grey.shade400 : SenseColors.blue600,
            width: 1.6,
          ),
        );
        break;

      case SenseButtonVariant.text:
        decoration = BoxDecoration(
          color: _isPressed ? SenseColors.surface : Colors.transparent,
          borderRadius: radius,
        );
        break;
    }

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      // Minimum (not fixed) height so the button grows when text wraps at
      // larger system text sizes.
      constraints: BoxConstraints(minHeight: widget.height),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: decoration,
      alignment: Alignment.center,
      child: content,
    );

    if (widget.isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return Semantics(
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: button,
      ),
    );
  }
}

