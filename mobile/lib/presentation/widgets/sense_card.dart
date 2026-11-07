import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SenseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final VoidCallback? onTap;

  const SenseCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.boxShadow,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(SenseSpacing.cardPadding),
      decoration: BoxDecoration(
        color: color ?? SenseColors.white,
        borderRadius: borderRadius ?? SenseRadii.lgBorder,
        border: border ?? Border.all(color: SenseColors.border, width: 1.0),
        boxShadow: boxShadow ?? SenseShadows.card,
      ),
      child: child,
    );

    if (onTap != null) {
      // Announced as a single button whose label is the card's text.
      return MergeSemantics(
        child: Semantics(
          button: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: card,
          ),
        ),
      );
    }

    return card;
  }
}

