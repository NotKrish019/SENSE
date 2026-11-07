import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'sense_tappable.dart';

class StressSummaryCard extends StatelessWidget {
  final String statusText;      // e.g. "No pattern yet" until a real baseline exists
  /// 0.0 to 1.0. Null hides the bar: never show a level that was not computed.
  final double? scoreFraction;
  final String? subtitle;
  final VoidCallback? onTap;

  const StressSummaryCard({
    super.key,
    this.statusText = 'No pattern yet',
    this.scoreFraction,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // When tappable: one button labelled with the card's text, with a tap
    // action, keyboard focus and a visible focus ring (SenseTappable).
    final card = Container(
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
            // Icon + titles + chevron in one row, unless the longest word of
            // the title cannot fit beside the icon (narrow screen / large
            // text): then the titles get the full card width below the icon,
            // so words are never broken mid-word.
            LayoutBuilder(builder: (context, constraints) {
              final titleStyle = SenseTypography.h2.copyWith(
                color: SenseColors.textOnDark,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              );
              final titles = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stress Pattern',
                    style: SenseTypography.label.copyWith(
                      color: const Color(0xFFB0D9F7),
                      fontSize: 13,
                    ),
                  ),
                  Text(statusText, style: titleStyle),
                ],
              );
              final icon = Container(
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
              );
              const chevron = Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0D9F7),
                size: 24,
              );
              final longestWord = statusText
                  .split(' ')
                  .fold<String>('', (a, b) => b.length > a.length ? b : a);
              final painter = TextPainter(
                text: TextSpan(text: longestWord, style: titleStyle),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              final wordWidth = painter.width;
              painter.dispose();
              final inlineWidth = constraints.maxWidth - 36 - 12 - 24;
              if (wordWidth + 2 <= inlineWidth) {
                return Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: titles),
                    chevron,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [icon, chevron],
                  ),
                  const SizedBox(height: 10),
                  titles,
                ],
              );
            }),
            if (scoreFraction != null) ...[
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
                  widthFactor: scoreFraction!.clamp(0.05, 1.0),
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
            ],
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
      );
    if (onTap == null) return card;
    return SenseTappable(
      onTap: onTap,
      borderRadius: SenseRadii.xlBorder,
      child: card,
    );
  }
}

