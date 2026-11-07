import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(
        title,
        style: SenseTypography.h3.copyWith(
          color: SenseColors.navy900,
          fontWeight: FontWeight.w700,
          fontSize: 19,
        ),
      ),
      actions: actions,
    );
  }
}

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
    return Container(
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
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
              GestureDetector(
                onTap: onAddTap,
                child: Container(
                  width: 48,
                  height: 48,
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
              _buildNavItem(
                index: 2,
                icon: Icons.spa_outlined,
                activeIcon: Icons.spa_rounded,
                label: 'Tools',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
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
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? SenseColors.blue600 : SenseColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: SenseTypography.caption.copyWith(
                color: isActive ? SenseColors.blue600 : SenseColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

