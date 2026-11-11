// Living Landscapes design system: PRODUCTION code (Phase 3).
//
// Input building blocks for the manual-entry screens (Journal, Sleep,
// Workload): a numbered question with a separate response area, a time
// field, a count stepper, the shared slider styling, and honest "not saved"
// and confirmation messages. Every control is a SenseTappable or a Material
// control with a merged accessible name.

import 'package:flutter/material.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_tappable.dart';

/// Slider styling shared by Living Landscapes sliders (same as [NatureSlider]).
SliderThemeData natureSliderTheme(Color active) => SliderThemeData(
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
    );

/// A small printed numeral with an off-register ring: the position of a
/// question in its sequence. Decorative (the title carries the meaning).
class NatureStepNumeral extends StatelessWidget {
  final int number;
  final Color accent;
  const NatureStepNumeral({super.key, required this.number, this.accent = NatureColors.forest});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          children: [
            Positioned(
              left: 3,
              top: 3,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.16)),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.4),
              ),
              child: MediaQuery.withNoTextScaling(
                child: Text('$number',
                    style: NatureType.label.copyWith(color: accent, fontWeight: FontWeight.w600, height: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One question in a manual-entry sequence.
///
/// Explanatory content (title, optional source note, the question itself) is
/// set as text on the page; what the person enters sits below it in a
/// response area with a tinted ground and a margin rule, so the two never
/// read as the same kind of thing.
class NatureQuestion extends StatelessWidget {
  final int number;
  final String title;

  /// Where the question comes from, e.g. "Adapted from NASA-TLX".
  final String? source;

  /// The question as asked (explanatory text).
  final String? question;

  /// The response control(s).
  final Widget child;

  /// Numeral and margin rule colour (decorative).
  final Color accent;

  const NatureQuestion({
    super.key,
    required this.number,
    required this.title,
    required this.child,
    this.source,
    this.question,
    this.accent = NatureColors.forest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NatureStepNumeral(number: number, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                // Title and source note are announced as one heading
                // ("Mental demand, adapted from NASA-TLX"), so the heading is
                // never confused with the control's own name.
                child: Semantics(
                  header: true,
                  label: source == null ? title : '$title, ${source![0].toLowerCase()}${source!.substring(1)}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: NatureType.sectionTitle),
                        if (source != null) ...[
                          const SizedBox(height: 2),
                          Text(source!, style: NatureType.eyebrow),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (question != null) ...[
          const SizedBox(height: 8),
          Text(question!, style: NatureType.bodyMuted),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: NatureColors.sageWash,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(NatureRadii.sm),
              bottomRight: Radius.circular(NatureRadii.sm),
            ),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// A time value that opens a picker: label, icon and the time, one button
/// announced as "<label>: <time>. Tap to change."
class NatureTimeField extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;

  /// Null disables the field (announced as disabled), for example while a
  /// save is in progress.
  final VoidCallback? onTap;
  const NatureTimeField({
    super.key,
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SenseTappable(
      semanticLabel: onTap == null ? '$label: $time' : '$label: $time. Tap to change.',
      onTap: onTap,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.paper,
      borderRadius: NatureRadii.smBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: NatureRadii.smBorder,
          border: Border.all(color: NatureColors.borderStrong),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: NatureColors.skyInk),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                  Text(time, style: NatureType.label.copyWith(fontWeight: FontWeight.w600, fontSize: 17)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: NatureColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// A whole-number stepper: two round 48 px buttons (with tooltips, which are
/// also their accessible names) around a value announced as a live region.
class NatureCountStepper extends StatelessWidget {
  final int count;

  /// Null when the value cannot go lower (the button is then disabled).
  final VoidCallback? onDecrement;

  /// Null when the value cannot go higher (the button is then disabled).
  final VoidCallback? onIncrement;
  final String decrementLabel;
  final String incrementLabel;

  /// Spoken form of the value, e.g. "2 deadlines".
  final String valueLabel;

  const NatureCountStepper({
    super.key,
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.valueLabel,
  });

  Widget _button(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return SenseTappable(
      semanticLabel: label,
      tooltip: label,
      circle: true,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.paper,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? NatureColors.forest : NatureColors.border, width: 1.5),
        ),
        child: Icon(icon, color: enabled ? NatureColors.forest : NatureColors.inkMuted, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(Icons.remove_rounded, decrementLabel, onDecrement),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Semantics(
            liveRegion: true,
            label: valueLabel,
            excludeSemantics: true,
            child: Text('$count',
                textAlign: TextAlign.center,
                style: NatureType.statusTitle.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
        _button(Icons.add_rounded, incrementLabel, onIncrement),
      ],
    );
  }
}

/// The honest "not saved" message after a Save action, in the Living
/// Landscapes style. Same wording as everywhere else
/// ([PrototypeCopy.notSaved]); nothing is written to storage.
void showNatureNotSavedMessage(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(PrototypeCopy.notSaved(what),
            style: NatureType.body.copyWith(color: NatureColors.paper)),
        backgroundColor: NatureColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NatureRadii.smBorder),
        duration: const Duration(seconds: 4),
      ),
    );
}

/// A two-choice confirmation dialog (paper surface). Returns true when the
/// confirming action is chosen.
Future<bool> showNatureConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
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
              textStyle: NatureType.label,
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: destructive ? NatureColors.coralInk : NatureColors.forest,
              minimumSize: const Size(64, 48),
              textStyle: NatureType.label.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// An explicit availability statement (Phase 4): what works today and what
/// does not. The status is carried by the words (eyebrow and title), never
/// by colour or the icon alone, and the panel is read as one sentence.
class NatureStatusPanel extends StatelessWidget {
  /// Short status, e.g. "Planned · not built".
  final String status;
  final String title;
  final String body;
  final IconData icon;

  /// Margin-rule colour (decorative).
  final Color accent;

  const NatureStatusPanel({
    super.key,
    required this.status,
    required this.title,
    required this.body,
    required this.icon,
    this.accent = NatureColors.ochreInk,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$status. $title. $body',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: NatureColors.paper,
            borderRadius: NatureRadii.mdBorder,
            border: Border.all(color: NatureColors.border),
          ),
          child: ClipRRect(
            borderRadius: NatureRadii.mdBorder,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(icon, size: 24, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(status, style: NatureType.eyebrow.copyWith(color: NatureColors.ochreInk)),
                                const SizedBox(height: 2),
                                Text(title, style: NatureType.sectionTitle.copyWith(fontSize: 17)),
                                const SizedBox(height: 4),
                                Text(body, style: NatureType.body),
                              ],
                            ),
                          ),
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
}
