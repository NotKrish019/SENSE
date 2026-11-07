import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class QuickActionTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;

  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeText,
  });

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: _isPressed ? SenseColors.surface : SenseColors.white,
          borderRadius: SenseRadii.lgBorder,
          border: Border.all(
            color: _isPressed ? SenseColors.blue600 : SenseColors.border,
            width: 1.2,
          ),
          boxShadow: _isPressed ? SenseShadows.recessed : SenseShadows.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SenseColors.background,
                borderRadius: SenseRadii.mdBorder,
                border: Border.all(color: const Color(0xFFCBE8FA), width: 1.0),
              ),
              child: Icon(
                widget.icon,
                color: SenseColors.blue600,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            // Single-word labels: shrink only if the word cannot fit, rather
            // than breaking it mid-word ("Workloa/d").
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                style: SenseTypography.labelBold.copyWith(
                  color: SenseColors.navy900,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.badgeText != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.badgeText!,
                style: SenseTypography.caption.copyWith(
                  color: SenseColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

