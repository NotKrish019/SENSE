// Living Landscapes design system: PRODUCTION code (Phase 1).
// Shared by the production screens and by the isolated redesign preview
// (lib/main_redesign_preview.dart). Moved here from the approved prototypes.
//
// Surfaces, actions, text links, tags, separators, sliders and the
// still-water band used across Living Landscapes screens.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_tappable.dart';

/// A sheet of journal paper laid over the landscape: torn top edge, a soft
/// shadow onto the scene, faint ruled lines. A surface with a reason: it is
/// where today's words are written.
class NatureJournalSheet extends StatelessWidget {
  final Widget child;
  final bool floating;
  const NatureJournalSheet({super.key, required this.child, this.floating = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SheetPainter(floating: floating),
      child: Padding(
        padding: EdgeInsets.fromLTRB(NatureSpace.gutter, floating ? 34 : 36, NatureSpace.gutter, floating ? 26 : 8),
        child: child,
      ),
    );
  }
}

class NatureTornEdgePainter extends CustomPainter {
  const NatureTornEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(8);
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, 6 + r.nextDouble() * 6 + math.sin(x / 41) * 2.5);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawShadow(path, NatureColors.ink, 6, false);
    canvas.drawPath(path, Paint()..color = NatureColors.background);
  }

  @override
  bool shouldRepaint(NatureTornEdgePainter old) => false;
}

class _SheetPainter extends CustomPainter {
  final bool floating;
  _SheetPainter({required this.floating});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(3);
    final path = Path()..moveTo(0, 14);
    // Torn top edge: small irregular fibres.
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, 8 + r.nextDouble() * 6 + math.sin(x / 37) * 2);
    }
    if (floating) {
      // Floating sheet: torn top, clean sides, gently rounded bottom.
      path
        ..lineTo(size.width, size.height - 10)
        ..quadraticBezierTo(size.width, size.height, size.width - 10, size.height)
        ..lineTo(10, size.height)
        ..quadraticBezierTo(0, size.height, 0, size.height - 10)
        ..close();
    } else {
      path
        ..lineTo(size.width, size.height + 2)
        ..lineTo(0, size.height + 2)
        ..close();
    }
    canvas.drawShadow(path, NatureColors.ink, floating ? 14 : 8, false);
    canvas.drawPath(path, Paint()..color = NatureColors.paper);
    // Fibre edge highlight and faint ruled lines near the top.
    canvas.drawPath(
      Path()..addPath(path, Offset.zero),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = NatureColors.border,
    );
    final rule = Paint()
      ..strokeWidth = 1
      ..color = NatureColors.skyTeal.withValues(alpha: 0.12);
    for (var y = 40.0; y < math.min(size.height - 8, 220); y += 28) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), rule);
    }
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.floating != floating;
}

// ---- Primary action: a printed button with a misregistered ochre layer --------
class NaturePrintedAction extends StatefulWidget {
  final String label;

  /// Null disables the action (announced as disabled; no ochre print layer).
  final VoidCallback? onTap;

  /// Trailing icon; defaults to a forward arrow, null for none.
  final IconData? icon;
  const NaturePrintedAction(
      {super.key, required this.label, required this.onTap, this.icon = Icons.arrow_forward_rounded});

  @override
  State<NaturePrintedAction> createState() => _NaturePrintedActionState();
}

class _NaturePrintedActionState extends State<NaturePrintedAction> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // The forest "print" sits 4 px off its ochre layer; pressing settles it
    // onto the ochre (a tactile, physical press without shadows).
    final enabled = widget.onTap != null;
    final settle = !enabled ? 4.0 : (_pressed ? 4.0 : (_hover ? 1.5 : 0.0));
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: 4,
            top: 4,
            right: -4,
            bottom: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: enabled ? NatureColors.sunOchre : NatureColors.divider,
                borderRadius: const BorderRadius.all(Radius.circular(NatureRadii.md)),
              ),
            ),
          ),
          AnimatedContainer(
              // Reduced motion: the press still settles, but instantly.
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NatureMotion.press,
              curve: NatureMotion.ease,
              transform: Matrix4.translationValues(settle, settle, 0),
              child: SenseTappable(
                semanticLabel: widget.label,
                onTap: widget.onTap,
                focusColor: NatureColors.focus,
                borderRadius: NatureRadii.mdBorder,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                onHover: (v) => setState(() => _hover = v),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: !enabled
                        ? NatureColors.divider
                        : (_pressed ? NatureColors.forestDeep : NatureColors.primary),
                    borderRadius: NatureRadii.mdBorder,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(widget.label,
                            style: NatureType.button.copyWith(
                                fontWeight: FontWeight.w600,
                                color: enabled ? NatureColors.primaryForeground : NatureColors.inkMuted),
                            textAlign: TextAlign.center),
                      ),
                      if (widget.icon != null) ...[
                        const SizedBox(width: 10),
                        Icon(widget.icon,
                            color: enabled ? NatureColors.primaryForeground : NatureColors.inkMuted, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class NatureSampleTag extends StatelessWidget {
  const NatureSampleTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NatureColors.paper,
        borderRadius: NatureRadii.smBorder,
        border: Border.all(color: NatureColors.borderStrong),
      ),
      child: Text(PrototypeCopy.sampleDataLabel,
          style: NatureType.eyebrow.copyWith(color: NatureColors.ink, fontSize: 12)),
    );
  }
}

class NatureTextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const NatureTextLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SenseTappable(
      semanticLabel: label,
      onTap: onTap,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.hover,
      borderRadius: NatureRadii.smBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(label, style: NatureType.link),
        ),
      ),
    );
  }
}

// ---- Page: still-water band, back control, journal sheet -------------------------
class NatureJournalPage extends StatelessWidget {
  final ScrollController controller;

  /// Back control action; null hides it (tab roots).
  final VoidCallback? onBack;

  /// Accessible name and tooltip of the back control.
  final String backLabel;

  /// False shows the back control disabled (for example while a save is in
  /// progress, so leaving cannot discard it). It stays visible and in place.
  final bool backEnabled;

  /// The illustrated band behind the top of the sheet; receives whether the
  /// desktop composition is in use. Defaults to [StillWaterBand].
  final Widget Function(bool desktop)? band;

  /// Maximum sheet width on desktop (the phone/tablet text column is capped
  /// at [NatureBreakpoints.maxReading]).
  final double maxSheetWidth;

  final Widget child;
  const NatureJournalPage({
    super.key,
    required this.controller,
    required this.child,
    this.onBack,
    this.backLabel = 'Back to Home',
    this.backEnabled = true,
    this.band,
    this.maxSheetWidth = NatureBreakpoints.maxReading + 40,
  });

  Widget _band(bool desktop) =>
      band?.call(desktop) ??
      (desktop ? const StillWaterBand(sunX: 0.86, tornBottom: true) : const StillWaterBand());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final desktop = width >= NatureBreakpoints.desktop;
      final back =
          onBack == null ? null : NatureBackControl(onTap: backEnabled ? onBack! : null, label: backLabel);

      if (desktop) {
        // As on Home: the scene spans the window with a torn paper edge where
        // it meets the page, and the sheet floats over it, leaving the sun
        // and the reeds visible on either side.
        final bandH = (c.maxHeight * 0.62).clamp(360.0, 560.0);
        final sheetW = math.min(maxSheetWidth, width - 80);
        final left = (width - sheetW) / 2;
        return SingleChildScrollView(
          controller: controller,
          child: Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, height: bandH, child: _band(true)),
              Padding(
                padding: EdgeInsets.fromLTRB(left, 132, left, 72),
                child: NatureJournalSheet(floating: true, child: child),
              ),
              if (back != null)
                Positioned(
                  top: 20,
                  left: math.max(24.0, left - 72),
                  child: back,
                ),
            ],
          ),
        );
      }

      // Phone and tablet: the band runs edge to edge and the sheet rises over
      // its lower edge, reaching at least to the bottom of the screen.
      final bandH = (c.maxHeight * 0.26).clamp(170.0, width >= NatureBreakpoints.tablet ? 250.0 : 210.0);
      final side = width > NatureBreakpoints.maxReading + 2 * NatureSpace.gutter
          ? (width - NatureBreakpoints.maxReading) / 2
          : NatureSpace.gutter;
      final sheetTop = bandH - 44;
      return SingleChildScrollView(
        controller: controller,
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, height: bandH, child: _band(false)),
            Padding(
              padding: EdgeInsets.only(top: sheetTop),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: math.max(0, c.maxHeight - sheetTop)),
                child: NatureJournalSheet(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(side - NatureSpace.gutter, 0, side - NatureSpace.gutter, 40),
                    child: child,
                  ),
                ),
              ),
            ),
            if (back != null)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(padding: EdgeInsets.fromLTRB(side - 8, 6, 0, 0), child: back),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class NatureBackControl extends StatelessWidget {
  /// Null disables the control (announced as disabled), for example while a
  /// save is in progress.
  final VoidCallback? onTap;
  final String label;
  const NatureBackControl({super.key, required this.onTap, this.label = 'Back to Home'});

  @override
  Widget build(BuildContext context) {
    return SenseTappable(
      semanticLabel: label,
      tooltip: label,
      circle: true,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.hover,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NatureColors.paper.withValues(alpha: 0.88),
          border: Border.all(color: NatureColors.borderStrong),
        ),
        child: Icon(Icons.arrow_back_rounded, color: onTap == null ? NatureColors.inkMuted : NatureColors.ink, size: 22),
      ),
    );
  }
}

// ---- Shared pieces --------------------------------------------------------------
class NatureHeading extends StatelessWidget {
  final String text;
  const NatureHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= NatureBreakpoints.desktop;
    final base = NatureType.greeting.copyWith(fontSize: desktop ? 28 : 25);
    return Semantics(
      header: true,
      child: LayoutBuilder(builder: (context, c) {
        // Text scaling is honoured. Only if the longest word would otherwise
        // break mid-word (very large text on a narrow screen) does the
        // heading step its size down until that word fits.
        final scaler = MediaQuery.textScalerOf(context);
        final longest = text.split(RegExp(r'\s+')).fold('', (a, b) => b.length > a.length ? b : a);
        var style = base;
        for (var size = base.fontSize!; size >= 16; size -= 1) {
          style = base.copyWith(fontSize: size);
          final tp = TextPainter(
            text: TextSpan(text: longest, style: style),
            textScaler: scaler,
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final fits = tp.width <= c.maxWidth;
          tp.dispose();
          if (fits) break;
        }
        return Text(text, style: style);
      }),
    );
  }
}

class NatureStepHeader extends StatelessWidget {
  final int step;
  const NatureStepHeader({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Daily check-in · Step $step of 2', style: NatureType.eyebrow)),
        const SizedBox(width: 12),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 1; i <= 2; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                AnimatedContainer(
                  // Reduced motion: the progress bar fills instantly.
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NatureMotion.selection,
                  width: 26,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step ? NatureColors.forest : NatureColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class NatureNotSavedNote extends StatelessWidget {
  const NatureNotSavedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: ExcludeSemantics(
              child: Icon(Icons.info_outline_rounded, size: 17, color: NatureColors.inkMuted)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(PrototypeCopy.notStoredYet,
              style: NatureType.bodyMuted.copyWith(fontSize: 13)),
        ),
      ],
    );
  }
}

/// A journal note with an ochre margin rule (same treatment as Home's "Today").
class NatureMarginNote extends StatelessWidget {
  final String eyebrow;
  final String text;
  const NatureMarginNote({super.key, required this.eyebrow, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: NatureColors.sunOchre, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: NatureType.eyebrow.copyWith(color: NatureColors.ochreInk)),
          const SizedBox(height: 4),
          Text(text, style: NatureType.bodyMuted),
        ],
      ),
    );
  }
}

/// Secondary action: paper with a strong outline, same height as the
/// printed action.
class NatureQuietButton extends StatelessWidget {
  final String label;

  /// Null disables the button (announced as disabled).
  final VoidCallback? onTap;

  /// Draw the label in the text-safe coral (destructive actions such as Clear).
  final bool caution;
  const NatureQuietButton({super.key, required this.label, required this.onTap, this.caution = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: SenseTappable(
        semanticLabel: label,
        onTap: onTap,
        focusColor: NatureColors.focus,
        hoverColor: NatureColors.hover,
        borderRadius: NatureRadii.mdBorder,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: NatureRadii.mdBorder,
            border: Border.all(
                color: onTap == null ? NatureColors.border : NatureColors.borderStrong, width: 1.5),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: NatureType.button.copyWith(
                  color: onTap == null
                      ? NatureColors.inkMuted
                      : (caution ? NatureColors.coralInk : NatureColors.forest),
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ---- Slider ---------------------------------------------------------------------
class NatureSlider extends StatelessWidget {
  final String semanticLabel;
  final int value;
  final String minLabel;
  final String maxLabel;

  /// Null disables the slider (announced as disabled).
  final ValueChanged<int>? onChanged;
  final bool warm;
  const NatureSlider({super.key,
    required this.semanticLabel,
    required this.value,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
    this.warm = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = warm ? NatureColors.coralInk : NatureColors.forest;
    final ends = NatureType.bodyMuted.copyWith(fontSize: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The value on its own line, end labels under the ends of the track:
        // each label gets half the width, so words never break at 2x text.
        ExcludeSemantics(
          child: Text('$value of 5',
              style: NatureType.label.copyWith(fontWeight: FontWeight.w600, color: active)),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: active,
            inactiveTrackColor: NatureColors.border,
            thumbColor: active,
            overlayColor: active.withValues(alpha: 0.14),
            activeTickMarkColor: NatureColors.paper,
            inactiveTickMarkColor: NatureColors.borderStrong,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 0, pressedElevation: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.2),
            trackShape: const RoundedRectSliderTrackShape(),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: MergeSemantics(
            child: Semantics(
              label: semanticLabel,
              child: Slider(
                semanticFormatterCallback: (v) => '${v.round()} of 5',
                value: value.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(builder: (context, c) {
            // Each end label gets half the width while its longest word fits
            // there; otherwise the two stack (min left, max right) so no word
            // ever breaks.
            final scaler = MediaQuery.textScalerOf(context);
            double longest(String t) {
              var w = 0.0;
              for (final word in t.split(RegExp(r'\s+'))) {
                final tp = TextPainter(
                  text: TextSpan(text: word, style: ends),
                  textScaler: scaler,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                )..layout();
                w = math.max(w, tp.width);
                tp.dispose();
              }
              return w;
            }
            final half = (c.maxWidth - 12) / 2;
            if (longest(minLabel) <= half && longest(maxLabel) <= half) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(minLabel, style: ends)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(maxLabel, textAlign: TextAlign.right, style: ends)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(minLabel, style: ends),
                const SizedBox(height: 2),
                Text(maxLabel, textAlign: TextAlign.right, style: ends),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ---- Illustrated separator --------------------------------------------------------
/// A hairline rule with a small hand-drawn sprig in the middle.
class SprigRule extends StatelessWidget {
  const SprigRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(height: 22, width: double.infinity, child: CustomPaint(painter: _SprigPainter())),
    );
  }
}

class _SprigPainter extends CustomPainter {
  const _SprigPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final rule = Paint()
      ..color = NatureColors.border
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, cy + 1), Offset(cx - 26, cy + 1), rule);
    canvas.drawLine(Offset(cx + 26, cy + 1), Offset(size.width, cy + 1), rule);

    final stem = Paint()
      ..color = NatureColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(cx - 17, cy + 3)
          ..quadraticBezierTo(cx, cy - 2, cx + 17, cy + 3),
        stem);
    final leaf = Paint()..color = NatureColors.meadow;
    final edge = Paint()
      ..color = NatureColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    void drawLeaf(double x, double y, double angle, double len) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.42, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.3, 0, 0)
        ..close();
      canvas.drawPath(p.shift(const Offset(0.6, 0.7)), leaf); // off-register plate
      canvas.drawPath(p, edge);
      canvas.restore();
    }

    drawLeaf(cx - 10, cy + 0.6, -2.5, 8);
    drawLeaf(cx - 4, cy - 0.4, -1.9, 7);
    drawLeaf(cx + 4, cy - 0.4, -1.25, 7);
    drawLeaf(cx + 10, cy + 0.6, -0.6, 8);
    canvas.drawCircle(Offset(cx + 0.6, cy - 3.2), 2.2, Paint()..color = NatureColors.sunOchre);
    canvas.drawCircle(
        Offset(cx, cy - 3.8),
        2.2,
        Paint()
          ..color = NatureColors.ochreInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_SprigPainter old) => false;
}

// ---- Still-water band ----------------------------------------------------------------
/// A quiet, static landscape: low sun, layered hills, still water with a
/// broken reflection and a few reeds. Original artwork; decorative.
class StillWaterBand extends StatelessWidget {
  /// Horizontal position of the sun (fraction of the width).
  final double sunX;

  /// Tear the bottom edge into the page colour (used where the band meets
  /// bare page, on desktop).
  final bool tornBottom;
  const StillWaterBand({super.key, this.sunX = 0.7, this.tornBottom = false});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
          child: CustomPaint(painter: _StillWaterPainter(sunX, tornBottom), size: Size.infinite)),
    );
  }
}

class _StillWaterPainter extends CustomPainter {
  final double sunX;
  final bool tornBottom;
  const _StillWaterPainter(this.sunX, this.tornBottom);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * 0.6;
    final rect = Offset.zero & size;

    // Sky.
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NatureColors.skyHigh, NatureColors.skyHorizon],
          ).createShader(Rect.fromLTWH(0, 0, w, horizon)));

    // Low sun with a soft halo and an off-register plate.
    // Phones: the sun peeks over the hills. Desktop (tall band): it rides
    // clear of the far ridge so it stays visible beside the sheet.
    final sun = Offset(w * sunX, horizon - (tornBottom ? h * 0.29 : math.min(h * 0.16, 44)));
    final r = math.min(h * 0.11, 30.0);
    canvas.drawCircle(sun, r * 2.6, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.28));
    canvas.drawCircle(sun, r * 1.7, Paint()..color = NatureColors.sunGlow.withValues(alpha: 0.38));
    canvas.drawCircle(sun + const Offset(1.5, 1.5), r, Paint()..color = NatureColors.sunOchre);
    canvas.drawCircle(
        sun,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = NatureColors.ochreInk.withValues(alpha: 0.7));

    // A carved-contour cloud drifting across the sky (static).
    _cloud(canvas, Offset(w * 0.24, h * 0.22), math.min(w * 0.11, 70));

    // Hills: far, middle, near, each a cut-paper plane with a lit edge.
    _ridge(canvas, size, horizon, seed: 11, amp: h * 0.17, base: horizon - h * 0.02,
        color: NatureColors.mistRange, step: 0.11);
    _ridge(canvas, size, horizon, seed: 4, amp: h * 0.11, base: horizon,
        color: NatureColors.eucalyptus, step: 0.15);
    _ridge(canvas, size, horizon, seed: 9, amp: h * 0.06, base: horizon + 1,
        color: NatureColors.pineMid, step: 0.2, leftOnly: true);

    // Still water.
    final water = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
        water,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(NatureColors.riverBlue, NatureColors.skyHorizon, 0.55)!,
              Color.lerp(NatureColors.riverBlue, NatureColors.sky, 0.25)!,
            ],
          ).createShader(water));

    // Broken sun reflection and ripple lines.
    final rnd = math.Random(5);
    final glint = Paint()
      ..color = NatureColors.sunGlow.withValues(alpha: 0.9)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = horizon + 7 + i * 8.0;
      if (y > h - 46) break;
      final half = r * (1.1 - i * 0.14) + rnd.nextDouble() * 4;
      canvas.drawLine(Offset(sun.dx - half, y), Offset(sun.dx + half, y), glint);
    }
    final ripple = Paint()
      ..color = NatureColors.paper.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = horizon + 10 + rnd.nextDouble() * (h - horizon - 52);
      final x = rnd.nextDouble() * w;
      final len = 18 + rnd.nextDouble() * 44;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), ripple);
    }

    // Reeds at the left water edge.
    final reed = Paint()
      ..color = NatureColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final rx = math.min(w * 0.08, 56.0);
    for (var i = 0; i < 7; i++) {
      final x = rx + i * 5.5 + rnd.nextDouble() * 3;
      final top = horizon - 8 - rnd.nextDouble() * 22;
      canvas.drawPath(
          Path()
            ..moveTo(x, horizon + 14)
            ..quadraticBezierTo(x + 1, (top + horizon) / 2, x + 3 + rnd.nextDouble() * 4, top),
          reed);
    }
    canvas.drawOval(
        Rect.fromCenter(center: Offset(rx + 17, horizon - 22), width: 4, height: 11),
        Paint()..color = NatureColors.ochreInk.withValues(alpha: 0.8));

    if (tornBottom) {
      final tr = math.Random(8);
      final edge = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 6) {
        edge.lineTo(x, h - 12 + tr.nextDouble() * 6 + math.sin(x / 41) * 2.5);
      }
      edge
        ..lineTo(w, h)
        ..close();
      canvas.drawShadow(edge, NatureColors.ink, 5, false);
      canvas.drawPath(edge, Paint()..color = NatureColors.background);
    }
  }

  void _ridge(Canvas canvas, Size size, double horizon,
      {required int seed,
      required double amp,
      required double base,
      required Color color,
      required double step,
      bool leftOnly = false}) {
    final w = size.width;
    final rnd = math.Random(seed);
    final end = leftOnly ? w * 0.42 : w;
    final path = Path()..moveTo(0, base);
    var prev = Offset(0, base - amp * (0.4 + rnd.nextDouble() * 0.5));
    path.lineTo(prev.dx, prev.dy);
    for (var t = step; t <= 1.0001; t += step) {
      final x = end * t;
      final fall = leftOnly ? (1 - t) : 1.0;
      final y = base - amp * fall * (0.35 + rnd.nextDouble() * 0.65);
      final mid = Offset((prev.dx + x) / 2, math.min(prev.dy, y) - amp * 0.12);
      path.quadraticBezierTo(mid.dx, mid.dy, x, y);
      prev = Offset(x, y);
    }
    path
      ..lineTo(end, base)
      ..close();
    canvas.drawShadow(path, NatureColors.ink, 2, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = NatureColors.paper.withValues(alpha: 0.35));
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final p = Path()
      ..moveTo(c.dx - s, c.dy + s * 0.28)
      ..cubicTo(c.dx - s * 1.2, c.dy - s * 0.05, c.dx - s * 0.7, c.dy - s * 0.3, c.dx - s * 0.45, c.dy - s * 0.12)
      ..cubicTo(c.dx - s * 0.35, c.dy - s * 0.55, c.dx + s * 0.25, c.dy - s * 0.6, c.dx + s * 0.32, c.dy - s * 0.15)
      ..cubicTo(c.dx + s * 0.7, c.dy - s * 0.35, c.dx + s * 1.15, c.dy - s * 0.05, c.dx + s, c.dy + s * 0.28)
      ..close();
    canvas.drawPath(p.shift(const Offset(1.5, 1.8)), Paint()..color = NatureColors.mistRange.withValues(alpha: 0.6));
    canvas.drawPath(p, Paint()..color = NatureColors.cream);
    canvas.drawPath(
        Path()
          ..moveTo(c.dx - s * 0.5, c.dy + s * 0.08)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.05, c.dx + s * 0.55, c.dy + s * 0.1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = NatureColors.eucalyptus);
  }

  @override
  bool shouldRepaint(_StillWaterPainter old) => old.sunX != sunX || old.tornBottom != tornBottom;
}
