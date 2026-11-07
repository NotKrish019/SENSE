import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sense_tappable.dart';

class SenseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const SenseAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: SenseColors.navy900),
              // Icon-only: the tooltip ("Back", localised) is also its
              // screen-reader label.
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      // Full title always shown: shrinks only if it cannot fit (large text,
      // narrow screens) instead of being cut off with an ellipsis.
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: SenseTypography.h3.copyWith(
            color: SenseColors.navy900,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
      ),
      actions: actions,
    );
  }
}

/// Bottom navigation: Home · Insights · (+ Check-in) · Profile.
///
/// Indices: 0 = Home, 1 = Insights, 2 = Profile. The centre button is an
/// action (opens the check-in), not a destination.
/// Accessibility: each item is announced as a selected/unselected button; the
/// active item uses a filled icon, bold label and an indicator bar (not colour
/// alone); the bar grows with text size instead of using a fixed height.
class SenseBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const SenseBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    // Like Material's NavigationBar, nav labels follow system text size but
    // are capped at 1.3x so four items still fit on a 320 px screen.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        decoration: const BoxDecoration(
          color: SenseColors.white,
          border: Border(top: BorderSide(color: SenseColors.border, width: 1.0)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14012F5F),
              offset: Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  label: 'Insights',
                ),
                // Central elevated action button matching UI Toolkit Board
                Expanded(
                  // heightFactor: 1 keeps the bar as tall as its content;
                  // a plain Center would expand to the full screen height.
                  child: Center(
                    heightFactor: 1,
                    // One semantics node with the tap action, keyboard focus
                    // (Enter/Space) and a visible focus ring.
                    child: SenseTappable(
                      semanticLabel: 'New daily check-in',
                      tooltip: 'New daily check-in',
                      circle: true,
                      onTap: onAddTap,
                      child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SenseColors.primaryActionGradient,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40059BE0),
                                  offset: Offset(0, 4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: SenseColors.white,
                              size: 28,
                            ),
                          ),
                    ),
                  ),
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = (currentIndex == index);
    // Icon: Electric Blue is fine for a non-text indicator (3.1:1 on white).
    // Label: small text needs >= 4.5:1, so it uses textAccent (7.65:1).
    final color = isActive ? SenseColors.blue600 : SenseColors.textSecondary;
    final labelColor = isActive ? SenseColors.textAccent : SenseColors.textSecondary;
    return Expanded(
      child: SenseTappable(
        semanticLabel: '$label tab',
        selected: isActive,
        onTap: () => onTap(index),
        borderRadius: SenseRadii.mdBorder,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicator bar: a non-colour cue for the active tab.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isActive ? 24 : 0,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: SenseColors.blue600,
                    borderRadius: SenseRadii.pillBorder,
                  ),
                ),
                Icon(isActive ? activeIcon : icon, color: color, size: 24),
                const SizedBox(height: 3),
                // Shrinks only if a single word cannot fit its slot.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: SenseTypography.caption.copyWith(
                      color: labelColor,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}
