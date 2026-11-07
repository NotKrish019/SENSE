import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_tappable.dart';
import '../widgets/sample_data_banner.dart';
import '../widgets/sense_chips.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';
import '../widgets/sense_inputs.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  double _sleepHours = 7.5;
  int _sleepQuality = 4; // 1 to 5
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  final List<double> _weekSleep = [7.2, 6.8, 7.5, 8.0, 6.5, 7.8, 7.5];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(title: 'Sleep Record'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Summary Card
              SenseCard(
                color: SenseColors.surface,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD6EFFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bedtime_outlined,
                        color: SenseColors.blue600,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your entry (manual)',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${_sleepHours.toStringAsFixed(1)} hours',
                          style: SenseTypography.h3.copyWith(
                            color: SenseColors.navy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Duration Slider
              Text(
                'Total Sleep Duration',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Column(
                  children: [
                    SenseSliderLabels(
                      minLabel: '4.0 hrs',
                      valueLabel: '${_sleepHours.toStringAsFixed(1)} hrs',
                      maxLabel: '12.0 hrs',
                      valueStyle: SenseTypography.h2.copyWith(
                        color: SenseColors.blue800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    MergeSemantics(child: Semantics(
                      // Name merged into the slider's own node (Task 8): it previously had none.
                      label: 'Sleep duration',
                      child: Slider(
                        semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)} hours',
                        value: _sleepHours,
                        min: 4.0,
                        max: 12.0,
                        divisions: 16,
                        activeColor: SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _sleepHours = v),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bedtime and Wake-up timing: side by side when roomy, stacked when
              // narrow or text is large (so times never break mid-number).
              LayoutBuilder(
                builder: (context, constraints) {
                  final bedtimeCard = SenseCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bedtime', style: SenseTypography.caption),
                          const SizedBox(height: 6),
                          SenseTappable(
                            semanticLabel: 'Bedtime: ${_bedtime.format(context)}. Tap to change.',
                            onTap: _pickBedtime,
                            borderRadius: SenseRadii.smBorder,
                            child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 48),
                                child: Row(
                                  children: [
                                    const Icon(Icons.nightlight_round, size: 18, color: SenseColors.blue600),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _bedtime.format(context),
                                        style: SenseTypography.labelBold.copyWith(
                                          color: SenseColors.navy900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ),
                        ],
                      ),
                    );
                  final wakeCard = SenseCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wake Time', style: SenseTypography.caption),
                          const SizedBox(height: 6),
                          SenseTappable(
                            semanticLabel: 'Wake time: ${_wakeTime.format(context)}. Tap to change.',
                            onTap: _pickWakeTime,
                            borderRadius: SenseRadii.smBorder,
                            child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 48),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wb_sunny_outlined, size: 18, color: SenseColors.cyan500),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _wakeTime.format(context),
                                        style: SenseTypography.labelBold.copyWith(
                                          color: SenseColors.navy900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ),
                        ],
                      ),
                    );
                  final stacked = constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(1.0) > 1.15;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [bedtimeCard, const SizedBox(height: 12), wakeCard],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: bedtimeCard),
                      const SizedBox(width: 12),
                      Expanded(child: wakeCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Sleep Quality Rating
              Text(
                'Subjective Rest Quality',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (i) {
                    final rating = i + 1;
                    final isSelected = (_sleepQuality == rating);
                    // Unselected: outline star in textMuted (5.1:1 on white,
                    // was grey 1.9:1) and number in textSecondary (6.0:1).
                    // Selected: filled Electric Blue star (3.1:1, non-text) and
                    // bold Ocean Blue number, so the states differ by shape,
                    // weight and colour, not colour alone.
                    return SenseTappable(
                      semanticLabel: 'Rest quality $rating of 5',
                      selected: isSelected,
                      onTap: () => setState(() => _sleepQuality = rating),
                      borderRadius: SenseRadii.mdBorder,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isSelected ? SenseColors.blue600 : SenseColors.textMuted,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$rating',
                              style: SenseTypography.caption.copyWith(
                                color: isSelected ? SenseColors.blue800 : SenseColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Recent 7-Day Sleep Trend
              SizedBox(
                width: double.infinity, // lets spaceBetween reach the right edge
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Example 7-day sleep history',
                      style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
                    ),
                    const SenseProvenanceBadge.sampleData(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SenseCard(
                // Fixed bar area; the label row below grows with text size.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final h = _weekSleep[i];
                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 45,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 16,
                                height: (h / 10.0 * 45).clamp(8.0, 45.0),
                                decoration: BoxDecoration(
                                  color: i == 6 ? SenseColors.blue600 : SenseColors.cyan300,
                                  borderRadius: SenseRadii.smBorder,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${h.toStringAsFixed(0)}h',
                              maxLines: 1,
                              // 11 px (was 10) in the primary text colour, so
                              // the small glyphs stay clearly readable.
                              style: SenseTypography.caption.copyWith(
                                fontSize: 11,
                                color: SenseColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Save Sleep Record',
                icon: Icons.save_rounded,
                onPressed: _saveSleep,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _pickBedtime() async {
    final picked = await showTimePicker(context: context, initialTime: _bedtime);
    if (picked != null) setState(() => _bedtime = picked);
  }

  void _pickWakeTime() async {
    final picked = await showTimePicker(context: context, initialTime: _wakeTime);
    if (picked != null) setState(() => _wakeTime = picked);
  }

  void _saveSleep() {
    // Persistence is not connected yet: report that honestly.
    showPrototypeNotSavedMessage(context, 'sleep entry');
  }
}
