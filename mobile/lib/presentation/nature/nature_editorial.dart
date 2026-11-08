// Living Landscapes design system: PRODUCTION code (Phase 2).
//
// Editorial building blocks for reading pages: section headings, an open
// ruled index row (the same treatment as Home's "Ways to reflect"), and an
// honest information dialog.

import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_tappable.dart';
import 'nature_home_sections.dart' show NaturePrintedIconWell;

/// A section heading (announced as a heading) with an optional short lede.
class NatureSectionHeading extends StatelessWidget {
  final String title;
  final String? lede;
  const NatureSectionHeading(this.title, {super.key, this.lede});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: NatureType.sectionTitle)),
        if (lede != null) ...[
          const SizedBox(height: 4),
          Text(lede!, style: NatureType.bodyMuted),
        ],
      ],
    );
  }
}

/// One entry of an open, ruled index: printed icon well, title, detail and a
/// chevron that moves on hover. One accessible button named "Title. Detail".
class NatureIndexRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  /// Draw the title in the text-safe coral (destructive actions such as Erase).
  final bool caution;

  const NatureIndexRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.caution = false,
  });

  @override
  State<NatureIndexRow> createState() => _NatureIndexRowState();
}

class _NatureIndexRowState extends State<NatureIndexRow> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return SenseTappable(
      semanticLabel: '${widget.title}. ${widget.detail}',
      onTap: widget.onTap,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.hover,
      onHover: (v) => setState(() => _active = v),
      onHighlightChanged: (v) => setState(() => _active = v),
      borderRadius: NatureRadii.smBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: LayoutBuilder(builder: (context, c) {
            // The icon well is decorative: on narrow screens with large text
            // it steps aside so the title's longest word never breaks.
            final titleStyle = NatureType.label;
            final longest =
                widget.title.split(' ').fold('', (a, b) => b.length > a.length ? b : a);
            final tp = TextPainter(
              text: TextSpan(text: longest, style: titleStyle),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            final showWell = c.maxWidth - 46 - 16 - 32 >= tp.width;
            tp.dispose();
            return Row(
            children: [
              if (showWell) ...[
                NaturePrintedIconWell(icon: widget.icon, settled: _active),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: NatureType.label.copyWith(
                            color: widget.caution ? NatureColors.coralInk : NatureColors.ink)),
                    const SizedBox(height: 2),
                    Text(widget.detail, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                offset: Offset(_active ? 0.18 : 0, 0),
                duration: MediaQuery.of(context).disableAnimations ? Duration.zero : NatureMotion.selection,
                curve: NatureMotion.ease,
                child: const Icon(Icons.chevron_right_rounded, color: NatureColors.inkMuted),
              ),
            ],
            );
          }),
        ),
      ),
    );
  }
}

/// Hairline-separated list of index rows.
class NatureIndex extends StatelessWidget {
  final List<Widget> rows;
  const NatureIndex({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows) ...[
          const Divider(height: 1, thickness: 1, color: NatureColors.divider),
          r,
        ],
        const Divider(height: 1, thickness: 1, color: NatureColors.divider),
      ],
    );
  }
}

/// An information dialog in the Living Landscapes style (paper surface, ink
/// text, one forest "OK" action). Used for honest "not available yet" notes.
Future<void> showNatureInfoDialog(BuildContext context, {required String title, required String message}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Theme(
      data: NatureTheme.light,
      child: AlertDialog(
        backgroundColor: NatureColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: NatureRadii.mdBorder),
        title: Text(title, style: NatureType.sectionTitle),
        content: Text(message, style: NatureType.body),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: NatureColors.forest,
              minimumSize: const Size(64, 48),
              textStyle: NatureType.label.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
