import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/state/sleep_controller.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/input_bands.dart';
import '../nature/nature_inputs.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_storage_scope.dart';
import '../widgets/sense_tappable.dart';
import 'consent_screen.dart';

/// Production Sleep record (Living Landscapes, Phase 3; persistence
/// Milestone K4).
///
/// An evening page under a dusk sky. The inputs, their order and their
/// meaning are unchanged; every value is entered by hand (nothing is read
/// from a device):
/// 1. total sleep duration: 4.0 to 12.0 hours in half-hour steps, default 7.5
///    (accessible name "Sleep duration", value read as "7.5 hours"), stored
///    as whole minutes (240 to 720);
/// 2. bedtime (default 23:30) and wake time (default 07:00), each opening the
///    time picker ("Bedtime: 11:30 PM. Tap to change."), stored as local
///    24-hour `HH:MM`;
/// 3. subjective rest quality, 1 to 5 stars, default 4 ("Rest quality n of 5",
///    with selected state).
/// Duration is its own answer: it is not calculated from the two times.
///
/// The entry is last night's sleep and belongs to the date you woke up
/// (today). Saving goes through [SleepController] and the app's storage owner
/// (encrypted development storage only, in a debug build with the explicit
/// define); success is shown only after the database transaction committed,
/// and the recent history shows only records that were actually saved. When
/// this build connects no storage, "Save Sleep Record" shows the honest "not
/// saved" message and the history is the labelled sample, as before.
class SleepScreen extends StatefulWidget {
  /// Injected for tests; normally created from the app's storage owner.
  final SleepController? controller;

  const SleepScreen({super.key, this.controller});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  SleepController? _controller;
  bool _ownsController = false;
  final ScrollController _scroll = ScrollController();

  /// A save outcome the status line cannot express from the controller's
  /// state alone (the date changed and the new day could not be read). Shown
  /// inline in the status line, never as an overlay; cleared by the next save.
  String? _notice;

  SleepController get _c => _controller!;

  /// Illustrative values only (labelled "Sample data" on screen), shown only
  /// when this build connects no storage.
  static const List<double> _weekSleep = [7.2, 6.8, 7.5, 8.0, 6.5, 7.8, 7.5];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final injected = widget.controller;
    _ownsController = injected == null;
    _controller = injected ?? SleepController(access: sleepAccessOf(context));
    unawaited(_c.start());
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static TimeOfDay _time(String hhmm) {
    final (h, m) = SleepController.parseHhmm(hhmm);
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final saving = _c.isSaving;
        final connected = _c.persistenceConnected;
        final hours = '${_c.durationHours.toStringAsFixed(1)} hours';
        final bed = _time(_c.bedtime).format(context);
        final wake = _time(_c.wakeTime).format(context);
        final day = _c.wakeDay;
        // Leaving (back control or system back) cannot discard a save in flight.
        return PopScope(
          canPop: !saving,
          child: Theme(
            data: NatureTheme.light,
            child: Scaffold(
              backgroundColor: NatureColors.background,
              body: NatureJournalPage(
                controller: _scroll,
                onBack: () => Navigator.of(context).maybePop(),
                backEnabled: !saving,
                backLabel: 'Back',
                band: (desktop) => DuskBand(tornBottom: desktop, moonX: desktop ? 0.84 : 0.78),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sleep record', style: NatureType.eyebrow),
                    const SizedBox(height: 8),
                    const NatureHeading('How did you sleep?'),
                    const SizedBox(height: 8),
                    // The record belongs to the date of wake-up.
                    Text(
                      day == null
                          ? "Last night's sleep (woke today)"
                          : "Last night's sleep (woke today, ${wakeDayLabel(day.date)})",
                      key: const Key('sleep-wake-day'),
                      style: NatureType.label.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A manual entry of your last sleep. You enter each value yourself; nothing is '
                      'read from a device or sleep tracker.',
                      style: NatureType.bodyMuted,
                    ),
                    const SizedBox(height: 18),
                    _NightSummary(hours: hours, bedtime: bed, wakeTime: wake),
                    const SizedBox(height: 28),
                    NatureQuestion(
                      number: 1,
                      title: 'Total sleep duration',
                      accent: NatureColors.skyInk,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Text(hours,
                                style: NatureType.statusTitle
                                    .copyWith(color: NatureColors.skyInk, fontWeight: FontWeight.w600)),
                          ),
                          SliderTheme(
                            data: natureSliderTheme(NatureColors.skyInk),
                            child: MergeSemantics(
                              child: Semantics(
                                label: 'Sleep duration',
                                child: Slider(
                                  semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)} hours',
                                  value: _c.durationHours,
                                  min: 4.0,
                                  max: 12.0,
                                  divisions: 16,
                                  // Locked while saving: what is on screen is what is written.
                                  onChanged: saving ? null : _c.setDurationHours,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text('4 hours', style: NatureType.bodyMuted.copyWith(fontSize: 13))),
                                Expanded(
                                  child: Text('12 hours',
                                      textAlign: TextAlign.right,
                                      style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    NatureQuestion(
                      number: 2,
                      title: 'Bedtime and wake time',
                      question: 'Duration is entered separately above; it is not calculated from these times.',
                      accent: NatureColors.skyInk,
                      child: LayoutBuilder(builder: (context, c) {
                        final bedField = NatureTimeField(
                            label: 'Bedtime',
                            time: bed,
                            icon: Icons.nightlight_round,
                            onTap: saving ? null : _pickBedtime);
                        final wakeField = NatureTimeField(
                            label: 'Wake time',
                            time: wake,
                            icon: Icons.wb_sunny_outlined,
                            onTap: saving ? null : _pickWakeTime);
                        // Side by side when roomy; stacked when narrow or text is
                        // large, so times never break mid-number.
                        final stacked = c.maxWidth < 380 || MediaQuery.textScalerOf(context).scale(1) > 1.15;
                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [bedField, const SizedBox(height: 10), wakeField],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: bedField),
                            const SizedBox(width: 10),
                            Expanded(child: wakeField),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    NatureQuestion(
                      number: 3,
                      title: 'Subjective rest quality',
                      question: 'Choose from 1 to 5 stars.',
                      accent: NatureColors.skyInk,
                      child: _StarRating(value: _c.quality, onChanged: saving ? null : _c.setQuality),
                    ),
                    const SizedBox(height: 30),
                    const SprigRule(),
                    const SizedBox(height: 22),
                    if (connected)
                      _RecentHistory(controller: _c)
                    else
                      const _SampleHistory(values: _weekSleep),
                    const SizedBox(height: 30),
                    if (connected)
                      _SleepStatus(controller: _c, notice: _notice, onReviewConsent: _openConsent)
                    else
                      const NatureNotSavedNote(),
                    const SizedBox(height: 16),
                    NaturePrintedAction(label: 'Save Sleep Record', icon: null, onTap: _c.canSave ? _saveSleep : null),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<TimeOfDay?> _pick(TimeOfDay initial) => showTimePicker(
        context: context,
        initialTime: initial,
        builder: (context, child) => Theme(data: NatureTheme.light, child: child!),
      );

  void _pickBedtime() async {
    final picked = await _pick(_time(_c.bedtime));
    if (picked != null && mounted) _c.setBedtime(picked.hour, picked.minute);
  }

  void _pickWakeTime() async {
    final picked = await _pick(_time(_c.wakeTime));
    if (picked != null && mounted) _c.setWakeTime(picked.hour, picked.minute);
  }

  void _openConsent() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ConsentScreen(isSettingsMode: true)),
      );

  /// Saves, then reports the outcome INLINE: the live status line just
  /// above Save shows it (saved, updated, denied, failed, date changed), so
  /// no floating message ever covers the Save button.
  Future<void> _saveSleep() async {
    setState(() => _notice = null);
    final result = await _c.save();
    if (!mounted) return;
    if (result == SleepSaveResult.notConnected) {
      // Persistence is not connected in this build: report that honestly.
      showNatureNotSavedMessage(context, 'sleep entry');
      return;
    }
    if (result == SleepSaveResult.dayChangedNotReloaded) {
      setState(() => _notice = _SleepStatus.dayChangedNotReloadedText);
    }
  }
}

const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Wednesday 11 November" for a `YYYY-MM-DD` local date (no locale data).
@visibleForTesting
String wakeDayLabel(String date) {
  final p = date.split('-').map(int.parse).toList();
  final d = DateTime(p[0], p[1], p[2]);
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// An honest, live status line above Save: where the entry is kept and what
/// the last save actually did (Milestone K4).
class _SleepStatus extends StatelessWidget {
  final SleepController controller;

  /// Overrides the state's text with a specific outcome (see [_SleepScreenState._notice]).
  final String? notice;
  final VoidCallback onReviewConsent;
  const _SleepStatus({required this.controller, required this.notice, required this.onReviewConsent});

  static String savedText(bool development) => development
      ? "Last night's sleep was saved in development storage. Development data, not for participants."
      : "Last night's sleep was saved on this device.";
  static const String updatedText = "Today's sleep entry was updated.";
  static const String consentDeniedText =
      'Sleep is turned off in your data and consent preferences, so nothing was saved.';
  static const String unavailableText =
      'Secure storage is unavailable, so your sleep entry cannot be saved right now. Nothing was saved.';
  static const String failedText =
      'Your sleep entry could not be saved. Your answers are still here, so you can try again.';
  static const String dayChangedText = 'The date changed before you saved, so nothing was saved for the earlier '
      "date. This entry is now for today's wake-up date (shown above): answers you changed are kept, the others "
      "show today's saved entry or the starting values. Review them and save again.";
  static const String dayChangedNotReloadedText = 'The date changed before you saved, so nothing was saved, and '
      "today's sleep entry could not be read. Your answers are still on screen; saving again reads today first.";

  String get _text {
    final c = controller;
    final where = c.isDevelopment
        ? 'Saving keeps it in encrypted development storage on this device (development data, not for '
            'participants).'
        : 'Saving keeps it in encrypted storage on this device.';
    return switch (c.phase) {
      SleepPhase.idle || SleepPhase.loading => "Loading today's sleep entry.",
      SleepPhase.editing => c.hasExistingEntry
          ? "You already saved last night's sleep today. It is shown here; saving replaces it. $where"
          : "No sleep entry saved today yet. $where Sleep must be turned on in your data and consent "
              'preferences.',
      SleepPhase.saving => 'Saving your sleep entry.',
      SleepPhase.saved => savedText(c.isDevelopment),
      SleepPhase.updated => updatedText,
      SleepPhase.consentDenied => consentDeniedText,
      SleepPhase.dateChanged => dayChangedText,
      SleepPhase.storageUnavailable => unavailableText,
      SleepPhase.failed =>
        c.dayLoaded ? failedText : "Today's saved sleep entry could not be read. Saving reads it again first.",
      SleepPhase.notConnected => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.isBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(
                  // A static indicator: nothing animates while waiting.
                  child: busy
                      ? const Icon(Icons.hourglass_empty_rounded,
                          key: Key('sleep-busy'), size: 17, color: NatureColors.inkMuted)
                      : const Icon(Icons.info_outline_rounded, size: 17, color: NatureColors.inkMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(notice ?? _text,
                    key: const Key('sleep-status'), style: NatureType.bodyMuted.copyWith(fontSize: 13)),
              ),
            ],
          ),
        ),
        if (controller.phase == SleepPhase.consentDenied) ...[
          const SizedBox(height: 4),
          NatureTextLink(label: 'Review data and consent preferences', onTap: onReviewConsent),
        ],
      ],
    );
  }
}

/// The last seven wake-up days from the records actually saved (Milestone
/// K4). A day without a record shows "no entry", never zero hours.
class _RecentHistory extends StatelessWidget {
  final SleepController controller;
  const _RecentHistory({required this.controller});

  static const List<String> _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final day = controller.wakeDay;
    final records = controller.history;
    final heading = Semantics(
        header: true, child: const Text('Your last 7 days', style: NatureType.sectionTitle));
    if (day == null || records == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 4),
          const Text('Your saved sleep entries will appear here.',
              key: Key('sleep-history-unavailable'), style: NatureType.bodyMuted),
        ],
      );
    }
    final p = day.date.split('-').map(int.parse).toList();
    final byDate = {for (final r in records) r.entry.day.date: r.entry.durationMinutes};
    final days = [
      for (var i = SleepController.historyDays - 1; i >= 0; i--) DateTime(p[0], p[1], p[2] - i),
    ];
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final spoken = days.map((d) {
      final m = byDate[key(d)];
      return '${_short[d.weekday - 1]} ${m == null ? 'no entry' : '${(m / 60).toStringAsFixed(1)} hours'}';
    }).join(', ');
    final saved = byDate.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 4),
        Text(
          saved == 0
              ? 'No sleep entries saved in the last 7 days yet.'
              : 'From your saved entries${controller.isDevelopment ? ' (development data)' : ''}, by the day you '
                  'woke up. Days without an entry are left empty.',
          key: const Key('sleep-history-note'),
          style: NatureType.bodyMuted,
        ),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          label: 'Your last 7 days, saved entries: $spoken',
          child: ExcludeSemantics(
            child: Row(
              key: const Key('sleep-history'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 64,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: byDate[key(d)] == null
                                ? Container(
                                    width: 14,
                                    height: 2,
                                    color: NatureColors.border,
                                  )
                                : Container(
                                    width: 14,
                                    height: (byDate[key(d)]! / 600.0 * 64).clamp(10.0, 64.0),
                                    decoration: const BoxDecoration(
                                      color: NatureColors.skyInk,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            byDate[key(d)] == null ? '–' : '${(byDate[key(d)]! / 60).toStringAsFixed(1)}h',
                            maxLines: 1,
                            style: NatureType.bodyMuted.copyWith(fontSize: 12, color: NatureColors.ink),
                          ),
                        ),
                        Text(_short[d.weekday - 1],
                            style: NatureType.bodyMuted.copyWith(fontSize: 11), maxLines: 1),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Your entry (manual)": the night at a glance, moon to sun, with the
/// duration. A reflection of the answers below, read as one sentence.
class _NightSummary extends StatelessWidget {
  final String hours;
  final String bedtime;
  final String wakeTime;
  const _NightSummary({required this.hours, required this.bedtime, required this.wakeTime});

  @override
  Widget build(BuildContext context) {
    final time = NatureType.label.copyWith(fontWeight: FontWeight.w600);
    return Semantics(
      container: true,
      label: 'Your entry (manual): $hours, bedtime $bedtime, wake time $wakeTime',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: NatureColors.paper,
            borderRadius: NatureRadii.mdBorder,
            border: Border.all(color: NatureColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your entry (manual)', style: NatureType.bodyMuted.copyWith(fontSize: 13)),
              const SizedBox(height: 2),
              Text(hours, style: NatureType.statusTitle.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) {
                Widget item(IconData icon, Color color, String t) => ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 17, color: color),
                        const SizedBox(width: 5),
                        Flexible(child: Text(t, style: time)),
                      ]),
                    );
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    item(Icons.nightlight_round, NatureColors.skyInk, bedtime),
                    const SizedBox(width: 44, height: 12, child: CustomPaint(painter: _ArcPainter())),
                    item(Icons.wb_sunny_outlined, NatureColors.ochreInk, wakeTime),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = NatureColors.borderStrong
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var x = 2.0; x < size.width - 2; x += 6) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 2.5, size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => false;
}

/// Five star buttons. Selected: filled star, bold number and an outlined
/// paper tile; unselected: outline star. The states differ by shape, weight
/// and outline, not colour alone.
class _StarRating extends StatelessWidget {
  final int value;

  /// Null while saving (the stars are disabled).
  final ValueChanged<int>? onChanged;
  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        final rating = i + 1;
        final selected = value == rating;
        return Flexible(
          child: SenseTappable(
            semanticLabel: 'Rest quality $rating of 5',
            selected: selected,
            onTap: onChanged == null ? null : () => onChanged!(rating),
            focusColor: NatureColors.focus,
            hoverColor: NatureColors.paper,
            borderRadius: NatureRadii.smBorder,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? NatureColors.paper : null,
                borderRadius: NatureRadii.smBorder,
                border: Border.all(
                    color: selected ? NatureColors.skyInk : Colors.transparent, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: selected ? NatureColors.skyInk : NatureColors.inkMuted,
                    size: 30,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$rating',
                    style: NatureType.label.copyWith(
                      color: selected ? NatureColors.ink : NatureColors.inkMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// The example 7-day history: clearly sample data, read as one sentence.
class _SampleHistory extends StatelessWidget {
  final List<double> values;
  const _SampleHistory({required this.values});

  @override
  Widget build(BuildContext context) {
    final spoken = values.map((v) => v.toStringAsFixed(1)).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
                header: true, child: const Text('Example 7-day sleep history', style: NatureType.sectionTitle)),
            const NatureSampleTag(),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Illustrative values, not your recorded sleep.', style: NatureType.bodyMuted),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          label: 'Example 7-day sleep history, sample data: $spoken hours',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final h = values[i];
                final last = i == values.length - 1;
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 64,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: (h / 10.0 * 64).clamp(10.0, 64.0),
                            decoration: BoxDecoration(
                              color: last ? NatureColors.skyInk : NatureColors.riverBlue.withValues(alpha: 0.55),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${h.toStringAsFixed(0)}h',
                          maxLines: 1,
                          style: NatureType.bodyMuted.copyWith(fontSize: 12, color: NatureColors.ink),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
