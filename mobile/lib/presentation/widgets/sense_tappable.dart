import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Shared accessible tap target for SENSE's custom controls (Task 8).
///
/// Earlier custom controls used `Semantics(button: true, excludeSemantics:
/// true, child: GestureDetector(...))`. That announced a button but removed
/// the tap action from the semantics node, so a screen reader could not
/// activate it, and a bare GestureDetector cannot take keyboard focus.
///
/// This widget gives every custom control:
/// * one semantics node with the role, label, selected/toggled state **and**
///   the tap action (so VoiceOver/TalkBack activation reaches [onTap]);
/// * keyboard focus, with Enter/Space activation (via [InkWell]);
/// * a visible focus ring (2.5 px Ocean Blue, 7.6:1 on white), drawn on top of
///   the control so opaque decorations cannot hide it;
/// * a click cursor on the web.
///
/// When [semanticLabel] is given, the child's own semantics (texts, icons) are
/// excluded and replaced by that label. Otherwise the child's texts are merged
/// into the single node (like a button whose label is its visible text).
class SenseTappable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? selected;
  final bool? toggled;
  final bool isButton;
  final String? tooltip;
  final BorderRadius? borderRadius;
  final bool circle;
  final ValueChanged<bool>? onHighlightChanged;

  /// Optional ring colour (defaults to [focusRingColor]); used by the
  /// redesign preview, which needs a ring that contrasts with parchment.
  final Color? focusColor;

  /// Optional hover tint and hover callback (pointer devices); used by the
  /// redesign preview. Defaults keep the existing behaviour.
  final Color? hoverColor;
  final ValueChanged<bool>? onHover;

  const SenseTappable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.selected,
    this.toggled,
    this.isButton = true,
    this.tooltip,
    this.borderRadius,
    this.circle = false,
    this.onHighlightChanged,
    this.focusColor,
    this.hoverColor,
    this.onHover,
  });

  /// Colour of the keyboard focus ring.
  static const Color focusRingColor = SenseColors.blue800;

  @override
  State<SenseTappable> createState() => _SenseTappableState();
}

class _SenseTappableState extends State<SenseTappable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    Widget visual = widget.child;
    if (widget.semanticLabel != null) visual = ExcludeSemantics(child: visual);
    if (widget.tooltip != null) {
      visual = Tooltip(message: widget.tooltip!, excludeFromSemantics: true, child: visual);
    }

    Widget node = Semantics(
      container: true,
      button: widget.isButton && widget.toggled == null,
      enabled: widget.onTap != null,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: widget.onHighlightChanged,
          onFocusChange: (f) => setState(() => _focused = f),
          onHover: widget.onHover,
          hoverColor: widget.hoverColor,
          customBorder: widget.circle
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: radius),
          focusColor: Colors.transparent,
          child: Container(
            key: const ValueKey('sense-tappable-focus-ring'),
            foregroundDecoration: _focused
                ? BoxDecoration(
                    shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: widget.circle ? null : radius,
                    border: Border.all(
                        color: widget.focusColor ?? SenseTappable.focusRingColor, width: 2.5),
                  )
                : null,
            child: visual,
          ),
        ),
      ),
    );
    if (widget.semanticLabel == null) node = MergeSemantics(child: node);
    return node;
  }
}
