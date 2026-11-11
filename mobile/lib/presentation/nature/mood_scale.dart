// Living Landscapes design system: PRODUCTION code (Phase 1).
// Shared by the production screens and by the isolated redesign preview
// (lib/main_redesign_preview.dart). Moved here from the approved prototypes.
//
// The check-in mood scale: five illustrated tiles with a selected state that
// never relies on colour alone.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_tappable.dart';
import 'mood_glyph.dart';

// ---- Mood scale -----------------------------------------------------------------
/// The five mood symbols as one ordered scale. Five across, left to right,
/// whenever they fit with every word whole; otherwise (very narrow screens or
/// large text) an ordered list, top to bottom. Never a broken grid, so the
/// 1 to 5 order always reads as a scale.
class MoodScale extends StatelessWidget {
  /// The mood options in order (value and visible label). Production passes
  /// `CheckInScreen.moodOptions`; nothing here defines the mood model.
  final List<({int value, String label})> options;
  final int selected;

  /// Null disables every option (for example while a check-in is saving).
  final ValueChanged<int>? onSelected;
  const MoodScale(
      {super.key, required this.options, required this.selected, required this.onSelected});

  static const double gap = 6;
  static const TextStyle labelStyle =
      TextStyle(fontFamily: NatureType.family, fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w600);
  static const TextStyle listLabelStyle =
      TextStyle(fontFamily: NatureType.family, fontSize: 15, height: 1.3, fontWeight: FontWeight.w600);

  /// Whether the five tiles fit across [width] at the current text size.
  static bool fitsAcross(
      double width, TextScaler textScaler, List<({int value, String label})> options) {
    // Widest single word at the selected (heavier) weight: labels may wrap
    // between words ("Very / Low") but never inside one.
    double widest = 0;
    for (final o in options) {
      for (final word in o.label.split(' ')) {
        final tp = TextPainter(
          text: TextSpan(text: word, style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, tp.width);
        tp.dispose();
      }
    }
    // Text width inside a selected tile: minus both outlines and padding,
    // with a 4 px safety margin for sub-pixel rounding.
    final tileW = ((width - gap * 4) / 5).floorToDouble();
    final textW = tileW - 2 * MoodTile.outlineSelected - 2 * MoodTile.padX;
    return tileW >= 54 && textW >= widest + 4;
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, c) {
      if (fitsAcross(c.maxWidth, textScaler, options)) {
        final tileW = ((c.maxWidth - gap * 4) / 5).floorToDouble();
        final glyph = (tileW * 0.6).clamp(36.0, 60.0).floorToDouble();
        final line = textScaler.scale(labelStyle.fontSize!) * labelStyle.height!;
        // padding 12 + 10, symbol, gap 8, two label lines, both outlines.
        final tileH = math.max(96.0, 12 + glyph + 8 + line * 2 + 10 + 2 * MoodTile.outlineSelected + 2);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final o in options)
              MoodTile(
                key: ValueKey('mood-${o.value}'),
                value: o.value,
                label: o.label,
                selected: o.value == selected,
                width: tileW,
                height: tileH,
                glyphSize: glyph,
                onTap: onSelected == null ? null : () => onSelected!(o.value),
              ),
          ],
        );
      }
      final line = textScaler.scale(listLabelStyle.fontSize!) * listLabelStyle.height!;
      final glyph = (line * 2.2).clamp(44.0, 64.0).floorToDouble();
      final rowH = math.max(math.max(64.0, glyph + 18), line * 2 + 16 + 2 * MoodTile.outlineSelected + 2);
      return Column(
        children: [
          for (final o in options) ...[
            if (o.value > 1) const SizedBox(height: gap + 2),
            MoodTile(
              key: ValueKey('mood-${o.value}'),
              value: o.value,
              label: o.label,
              selected: o.value == selected,
              width: c.maxWidth - 4, // room for the offset print
              height: rowH,
              glyphSize: glyph,
              horizontal: true,
              onTap: onSelected == null ? null : () => onSelected!(o.value),
            ),
          ],
        ],
      );
    });
  }
}

/// One mood option. Selected state uses five cues besides colour: a heavier
/// outline (1.5 to 2.5 px), a check badge, a paper surface with an offset
/// ochre print, a slightly raised symbol and a heavier label.
class MoodTile extends StatefulWidget {
  final int value;
  final String label;
  final bool selected;
  final double width, height, glyphSize;
  final bool horizontal; // list layout: symbol left, label right

  /// Null disables the option (announced as disabled).
  final VoidCallback? onTap;
  const MoodTile({
    super.key,
    required this.value,
    required this.label,
    required this.selected,
    required this.width,
    required this.height,
    required this.glyphSize,
    required this.onTap,
    this.horizontal = false,
  });

  /// Outline widths and horizontal padding (scale layout), exposed for tests.
  static const double outline = 1.5, outlineSelected = 2.5, padX = 1;

  /// The keyboard focus ring is drawn this far outside the tile, so it never
  /// sits on top of the selected outline (focused and selected stay distinct).
  static const double focusGap = 4;

  @override
  State<MoodTile> createState() => _MoodTileState();
}

class _MoodTileState extends State<MoodTile> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final d = still ? Duration.zero : NatureMotion.selection;
    final sel = widget.selected;
    const radius = BorderRadius.all(Radius.circular(NatureRadii.md));

    final glyph = AnimatedSlide(
      duration: d,
      curve: NatureMotion.ease,
      offset: Offset(0, sel ? -0.04 : 0),
      child: AnimatedScale(
        duration: d,
        curve: NatureMotion.ease,
        scale: sel ? 1.06 : 1,
        child: MoodGlyph(value: widget.value, size: widget.glyphSize),
      ),
    );
    final base = widget.horizontal ? MoodScale.listLabelStyle : MoodScale.labelStyle;
    final label = Text(
      widget.label,
      textAlign: widget.horizontal ? TextAlign.left : TextAlign.center,
      maxLines: 2,
      style: base.copyWith(
        fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
        color: sel ? NatureColors.ink : NatureColors.inkMuted,
      ),
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Offset ochre print under the selected tile.
          Positioned.fill(
            left: 3,
            top: 3,
            right: -3,
            bottom: -3,
            child: AnimatedOpacity(
              duration: d,
              opacity: sel ? 1 : 0,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: NatureColors.sunOchre, borderRadius: radius),
              ),
            ),
          ),
          Positioned(
            left: -MoodTile.focusGap,
            top: -MoodTile.focusGap,
            right: -MoodTile.focusGap,
            bottom: -MoodTile.focusGap,
            child: AnimatedScale(
              duration: still ? Duration.zero : NatureMotion.press,
              curve: NatureMotion.ease,
              scale: _pressed ? 0.96 : 1,
              child: SenseTappable(
                semanticLabel: 'Mood: ${widget.label}',
                selected: sel,
                onTap: widget.onTap,
                focusColor: NatureColors.focus,
                hoverColor: Colors.transparent,
                borderRadius: const BorderRadius.all(Radius.circular(NatureRadii.md + MoodTile.focusGap)),
                onHighlightChanged: (v) => setState(() => _pressed = v),
                onHover: (v) => setState(() => _hover = v),
                child: Padding(
                  padding: const EdgeInsets.all(MoodTile.focusGap),
                  child: AnimatedContainer(
                  key: ValueKey('mood-surface-${widget.value}'),
                  duration: d,
                  curve: NatureMotion.ease,
                  decoration: BoxDecoration(
                    color: sel
                        ? NatureColors.paper
                        : (_hover ? NatureColors.hover : NatureColors.background),
                    borderRadius: radius,
                    border: Border.all(
                      color: sel ? NatureColors.forest : NatureColors.borderStrong,
                      width: sel ? MoodTile.outlineSelected : MoodTile.outline,
                    ),
                  ),
                  padding: widget.horizontal
                      ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                      : const EdgeInsets.fromLTRB(MoodTile.padX, 12, MoodTile.padX, 10),
                  child: widget.horizontal
                      ? Row(children: [glyph, const SizedBox(width: 14), Expanded(child: label)])
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [glyph, const SizedBox(height: 8), label],
                        ),
                  ),
                ),
              ),
            ),
          ),
          // Check badge.
          Positioned(
            top: -8,
            right: -8,
            child: IgnorePointer(
              child: AnimatedScale(
                key: ValueKey('mood-check-${widget.value}'),
                duration: d,
                curve: NatureMotion.ease,
                scale: sel ? 1 : 0,
                child: const _CheckBadge(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox.square(dimension: 22, child: CustomPaint(painter: _CheckPainter())),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    canvas.scale(s);
    canvas.drawCircle(const Offset(10, 10), 9, Paint()..color = NatureColors.forest);
    canvas.drawCircle(
        const Offset(10, 10),
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = NatureColors.paper);
    canvas.drawPath(
        Path()
          ..moveTo(6, 10.4)
          ..lineTo(8.7, 13)
          ..lineTo(14.2, 7.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = NatureColors.paper);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => false;
}
