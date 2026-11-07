import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';

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
  bool _isSaving = false;

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Night\'s Rest',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${_sleepHours.toStringAsFixed(1)} Hours Logged',
                          style: SenseTypography.h3.copyWith(
                            color: SenseColors.navy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('4.0 hrs', style: SenseTypography.caption),
                        Text(
                          '${_sleepHours.toStringAsFixed(1)} hrs',
                          style: SenseTypography.h2.copyWith(
                            color: SenseColors.blue800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('12.0 hrs', style: SenseTypography.caption),
                      ],
                    ),
                    Slider(
                      value: _sleepHours,
                      min: 4.0,
                      max: 12.0,
                      divisions: 16,
                      activeColor: SenseColors.blue600,
                      inactiveColor: const Color(0xFFD6EFFC),
                      onChanged: (v) => setState(() => _sleepHours = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bedtime and Wake-up timing
              Row(
                children: [
                  Expanded(
                    child: SenseCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bedtime', style: SenseTypography.caption),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickBedtime,
                            child: Row(
                              children: [
                                const Icon(Icons.nightlight_round, size: 18, color: SenseColors.blue600),
                                const SizedBox(width: 6),
                                Text(
                                  _bedtime.format(context),
                                  style: SenseTypography.labelBold.copyWith(
                                    color: SenseColors.navy900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SenseCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wake Time', style: SenseTypography.caption),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickWakeTime,
                            child: Row(
                              children: [
                                const Icon(Icons.wb_sunny_outlined, size: 18, color: SenseColors.cyan500),
                                const SizedBox(width: 6),
                                Text(
                                  _wakeTime.format(context),
                                  style: SenseTypography.labelBold.copyWith(
                                    color: SenseColors.navy900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    return GestureDetector(
                      onTap: () => setState(() => _sleepQuality = rating),
                      child: Column(
                        children: [
                          Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isSelected ? SenseColors.blue600 : Colors.grey.shade400,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$rating',
                            style: SenseTypography.caption.copyWith(
                              color: isSelected ? SenseColors.blue800 : Colors.grey,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Recent 7-Day Sleep Trend
              Text(
                'Recent 7-Day Trend',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final h = _weekSleep[i];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 16,
                            height: (h / 10.0 * 45).clamp(8.0, 45.0),
                            decoration: BoxDecoration(
                              color: i == 6 ? SenseColors.blue600 : SenseColors.cyan300,
                              borderRadius: SenseRadii.smBorder,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${h.toStringAsFixed(0)}h',
                            style: SenseTypography.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Save Sleep Record',
                icon: Icons.save_rounded,
                isLoading: _isSaving,
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
    setState(() => _isSaving = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep entry logged to local baseline.'),
            backgroundColor: SenseColors.navy900,
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }
}
