// Living Landscapes design system: PRODUCTION code (Phase 1).
// Shared by the production screens and by the isolated redesign preview
// (lib/main_redesign_preview.dart). Moved here from the approved prototypes.
//
// Phone/tablet bottom bar, desktop top bar and the check-in disc.

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_logo.dart';
import '../widgets/sense_tappable.dart';

class NatureWordmark extends StatelessWidget {
  const NatureWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    // Logo geometry unchanged; single-colour forest variant for this theme.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SenseLogoMark(size: 28, variant: SenseLogoVariant.mono, color: NatureColors.forest),
        const SizedBox(width: 10),
        Text('SENSE',
            style: NatureType.label.copyWith(
                fontWeight: FontWeight.w600, letterSpacing: 2.2, color: NatureColors.forest)),
      ],
    );
  }
}

// ---- Navigation -------------------------------------------------------------------
/// The check-in action: forest disc with an off-register ochre ring.
class NatureCheckInDisc extends StatelessWidget {
  const NatureCheckInDisc({super.key});
  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Positioned(
            left: 3,
            top: 3,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NatureColors.sunOchre, width: 2.5),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: NatureColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: NatureColors.primaryForeground, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Phone/tablet bottom bar: paper surface, hairline top border, a forest
/// indicator above the active item (not colour alone).
class NatureBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCheckIn;

  const NatureBottomBar({super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: NatureColors.surface,
          border: Border(top: BorderSide(color: NatureColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 66, maxWidth: NatureBreakpoints.maxReading),
              child: Row(
                children: [
                  _navItem(context, 0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  _navItem(context, 1, Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: SenseTappable(
                        semanticLabel: 'New daily check-in',
                        tooltip: 'New daily check-in',
                        circle: true,
                        focusColor: NatureColors.focus,
                        onTap: onCheckIn,
                        child: const NatureCheckInDisc(),
                      ),
                    ),
                  ),
                  _navItem(context, 2, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final active = index == currentIndex;
    final color = active ? NatureColors.forest : NatureColors.inkMuted;
    return Expanded(
      child: SenseTappable(
        semanticLabel: '$label tab',
        selected: active,
        focusColor: NatureColors.focus,
        hoverColor: NatureColors.hover,
        borderRadius: NatureRadii.mdBorder,
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                // Reduced motion: the active indicator appears instantly.
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NatureMotion.selection,
                curve: NatureMotion.ease,
                width: active ? 22 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: NatureColors.forest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(active ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: NatureType.label.copyWith(
                    fontSize: 12,
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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

/// Desktop header: wordmark, text tabs with an underline indicator, and the
/// check-in action as a labelled button.
class NatureTopBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCheckIn;

  /// On Home the bar takes the sky colour so it reads as part of the scene.
  final bool overSky;

  const NatureTopBar({super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCheckIn,
    this.overSky = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: overSky ? NatureColors.skyHigh : NatureColors.background,
        border: overSky ? null : const Border(bottom: BorderSide(color: NatureColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NatureBreakpoints.maxContent + 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Row(
                children: [
                  const NatureWordmark(),
                  const Spacer(),
                  for (final (i, label) in const ['Home', 'Insights', 'Profile'].indexed)
                    _tab(context, i, label),
                  const SizedBox(width: 24),
                  SenseTappable(
                    semanticLabel: 'New daily check-in',
                    tooltip: 'New daily check-in',
                    focusColor: NatureColors.focus,
                    borderRadius: NatureRadii.mdBorder,
                    onTap: onCheckIn,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: NatureColors.primary,
                        borderRadius: NatureRadii.mdBorder,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: NatureColors.primaryForeground, size: 20),
                          const SizedBox(width: 8),
                          Text('New check-in',
                              style: NatureType.button.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index, String label) {
    final active = index == currentIndex;
    return SenseTappable(
      semanticLabel: '$label tab',
      selected: active,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.hover,
      borderRadius: NatureRadii.smBorder,
      onTap: () => onTap(index),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: NatureType.label.copyWith(
                    color: active ? NatureColors.forest : NatureColors.inkMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  )),
              const SizedBox(height: 4),
              AnimatedContainer(
                // Reduced motion: the active indicator appears instantly.
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NatureMotion.selection,
                curve: NatureMotion.ease,
                width: active ? 24 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: NatureColors.forest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
