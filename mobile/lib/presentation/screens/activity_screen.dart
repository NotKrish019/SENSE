import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/input_bands.dart';
import '../nature/nature_inputs.dart';
import '../nature/nature_widgets.dart';

/// Production Physical activity (Living Landscapes, Phase 4).
///
/// Manual entry only. Fields, ranges, defaults and order are unchanged:
/// 1. daily step count: 1,000 to 20,000 in steps of 500, default 6,800
///    (accessible name "Steps", value read as shown: "6,800 steps");
/// 2. active exercise minutes: 0 to 120 in steps of 5, default 35
///    ("Active minutes", "35 minutes").
/// Health Connect is NOT connected: no permission is requested and no data is
/// read. Until Phase 4 this was an always-off switch that only showed an
/// "unavailable" message; it looked operable, so it is now an explicit
/// "not connected" status. "Save Activity Entry" shows the honest
/// "not saved" message: persistence is not connected.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _steps = 6800;
  int _activeMinutes = 35;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static String _thousands(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final steps = '${_thousands(_steps)} steps';
    final minutes = '$_activeMinutes active minutes';
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          band: (desktop) => TrailBand(tornBottom: desktop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Activity · manual entry', style: NatureType.eyebrow),
              const SizedBox(height: 8),
              const NatureHeading('Physical activity'),
              const SizedBox(height: 8),
              const Text(
                'Two values you enter yourself. Nothing is read from a phone, watch or health app.',
                style: NatureType.bodyMuted,
              ),
              const SizedBox(height: 18),
              // "Your entry (manual)": restates the two answers below.
              Semantics(
                container: true,
                label: 'Your entry (manual): $steps, $minutes',
                child: ExcludeSemantics(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: NatureColors.paper,
                      borderRadius: NatureRadii.mdBorder,
                      border: Border.all(color: NatureColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your entry (manual)', style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 18,
                          runSpacing: 4,
                          children: [
                            Text(steps, style: NatureType.statusTitle.copyWith(fontWeight: FontWeight.w600)),
                            Text(minutes, style: NatureType.statusTitle.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              NatureQuestion(
                number: 1,
                title: 'Daily step count',
                source: 'Manual entry',
                child: _RangeInput(
                  valueText: steps,
                  semanticLabel: 'Steps',
                  value: _steps.toDouble(),
                  min: 1000,
                  max: 20000,
                  step: 500,
                  minLabel: '1,000',
                  maxLabel: '20,000',
                  format: (v) => '${_thousands(v.round())} steps',
                  onChanged: (v) => setState(() => _steps = v.round()),
                ),
              ),
              const SizedBox(height: 28),
              NatureQuestion(
                number: 2,
                title: 'Active exercise minutes',
                child: _RangeInput(
                  valueText: '$_activeMinutes minutes',
                  semanticLabel: 'Active minutes',
                  value: _activeMinutes.toDouble(),
                  min: 0,
                  max: 120,
                  step: 5,
                  minLabel: '0 minutes',
                  maxLabel: '120 minutes',
                  format: (v) => '${v.round()} minutes',
                  onChanged: (v) => setState(() => _activeMinutes = v.round()),
                ),
              ),
              const SizedBox(height: 30),
              Semantics(
                header: true,
                child: const Text('Where activity data comes from', style: NatureType.sectionTitle),
              ),
              const SizedBox(height: 12),
              const _Source(
                icon: Icons.edit_note_rounded,
                name: 'Manual entry',
                status: 'Available · not saved',
                available: true,
              ),
              const SizedBox(height: 10),
              const _Source(
                icon: Icons.sync_disabled_rounded,
                name: 'Health Connect',
                status: 'Not connected · not available in this prototype',
                available: false,
              ),
              const SizedBox(height: 12),
              const Text(
                'No permission is requested and no activity data is read. If Health Connect is '
                'added later, it would read only daily step totals, with your explicit permission, '
                'and no GPS or background location tracking.',
                style: NatureType.bodyMuted,
              ),
              const SizedBox(height: 30),
              const NatureNotSavedNote(),
              const SizedBox(height: 16),
              NaturePrintedAction(label: 'Save Activity Entry', icon: null, onTap: _saveActivity),
            ],
          ),
        ),
      ),
    );
  }

  void _saveActivity() {
    // Persistence is not connected yet: report that honestly.
    showNatureNotSavedMessage(context, 'activity entry');
  }
}

/// A labelled slider with its value above and its range ends below.
///
/// Phase 4 accessibility correction: a Material [Slider] with `divisions`
/// rounds its value to the nearest division, so the step default 6,800 (not
/// on the 500-step grid from 1,000) was drawn and announced as 7,000 while
/// the page showed 6,800. This input keeps the exact value instead:
/// * the slider is continuous, so the thumb sits at the real value;
/// * pointer and touch changes snap to the same grid ([step] from [min]);
/// * keyboard arrows and the screen reader's increase / decrease actions move
///   to the next or previous grid value (6,800 -> 7,000 or 6,500, then by
///   [step]), clamped to [min] and [max];
/// * the spoken value is [valueText], exactly the text shown on screen.
/// Range, step and defaults are unchanged.
class _RangeInput extends StatefulWidget {
  final String valueText;
  final String semanticLabel;
  final double value;
  final double min;
  final double max;
  final double step;
  final String minLabel;
  final String maxLabel;

  /// Spoken form of a value other than the current one (for the increase /
  /// decrease previews), in the same format as [valueText].
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  const _RangeInput({
    required this.valueText,
    required this.semanticLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.minLabel,
    required this.maxLabel,
    required this.format,
    required this.onChanged,
  });

  @override
  State<_RangeInput> createState() => _RangeInputState();
}

class _RangeInputState extends State<_RangeInput> {
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  double get _next {
    final k = ((widget.value - widget.min) / widget.step + 1e-9).floor() + 1;
    return (widget.min + k * widget.step).clamp(widget.min, widget.max);
  }

  double get _previous {
    final k = ((widget.value - widget.min) / widget.step - 1e-9).ceil() - 1;
    return (widget.min + k * widget.step).clamp(widget.min, widget.max);
  }

  double _snap(double v) =>
      (widget.min + ((v - widget.min) / widget.step).round() * widget.step).clamp(widget.min, widget.max);

  void _set(double v) {
    if (v != widget.value) widget.onChanged(v);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowUp) {
      _set(_next);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowDown) {
      _set(_previous);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final ends = NatureType.bodyMuted.copyWith(fontSize: 13);
    final canIncrease = w.value < w.max;
    final canDecrease = w.value > w.min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(w.valueText,
              style: NatureType.statusTitle.copyWith(color: NatureColors.forest, fontWeight: FontWeight.w600)),
        ),
        SliderTheme(
          data: natureSliderTheme(NatureColors.forest),
          // One slider node for assistive technology, carrying the exact value.
          child: Semantics(
            container: true,
            slider: true,
            label: w.semanticLabel,
            value: w.valueText,
            increasedValue: canIncrease ? w.format(_next) : null,
            decreasedValue: canDecrease ? w.format(_previous) : null,
            onIncrease: canIncrease ? () => _set(_next) : null,
            onDecrease: canDecrease ? () => _set(_previous) : null,
            focusable: true,
            focused: _focus.hasFocus,
            child: ExcludeSemantics(
              child: Slider(
                focusNode: _focus,
                value: w.value,
                min: w.min,
                max: w.max,
                onChanged: (v) => _set(_snap(v)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Text(w.minLabel, style: ends)),
              Expanded(child: Text(w.maxLabel, textAlign: TextAlign.right, style: ends)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A data source and its status, in words (the icon is decorative).
class _Source extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final bool available;
  const _Source({required this.icon, required this.name, required this.status, required this.available});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$name: $status',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: available ? NatureColors.sageWash : NatureColors.paper,
            borderRadius: NatureRadii.smBorder,
            border: Border.all(
              color: available ? NatureColors.forest : NatureColors.borderStrong,
              width: available ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: available ? NatureColors.forest : NatureColors.inkMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: NatureType.label.copyWith(fontWeight: FontWeight.w600)),
                    Text(status,
                        style: NatureType.bodyMuted.copyWith(
                            fontSize: 13, color: available ? NatureColors.forest : NatureColors.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
