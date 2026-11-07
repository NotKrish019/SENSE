import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StressSummaryCard extends StatelessWidget {
  final String statusText;      // e.g. "Moderate", "Calibrated Equilibrium", "Mild"
  final double scoreFraction;    // 0.0 to 1.0 (e.g. 0.50)
  final String? subtitle;
  final VoidCallback? onTap;

  const StressSummaryCard({
    super.key,
    this.statusText = 'Moderate',
    this.scoreFraction = 0.50,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: SenseRadii.xlBorder,
          gradient: SenseColors.heroCardGradient,
          boxShadow: [
            BoxShadow(
              color: const Color(0x3D012F5F),
              offset: const Offset(0, 10),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0x2607CCFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x4D07CCFC), width: 1.0),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: SenseColors.cyan300,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Stress Pattern',
                          style: SenseTypography.label.copyWith(
                            color: const Color(0xFFB0D9F7),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          statusText,
                          style: SenseTypography.h2.copyWith(
                            color: SenseColors.textOnDark,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB0D9F7),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Cyan gradient progress bar matching the UI Toolkit board
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0x3307CCFC),
                    borderRadius: SenseRadii.pillBorder,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: scoreFraction.clamp(0.05, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: SenseColors.cyanHighlightGradient,
                      borderRadius: SenseRadii.pillBorder,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D07CCFC),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: SenseTypography.caption.copyWith(
                  color: const Color(0xFFC7E4F9),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

