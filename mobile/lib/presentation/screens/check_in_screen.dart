import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';
import '../widgets/sense_inputs.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  int _currentStep = 1;
  int _selectedMood = 3; // 1 to 5
  int _perceivedStress = 2; // 1 to 5
  int _motivationLevel = 3; // 1 to 5
  bool _isSaved = false;

  final List<Map<String, dynamic>> _moodOptions = [
    {'val': 1, 'icon': '😔', 'label': 'Very Low'},
    {'val': 2, 'icon': '🙁', 'label': 'Low'},
    {'val': 3, 'icon': '😐', 'label': 'Neutral'},
    {'val': 4, 'icon': '🙂', 'label': 'Good'},
    {'val': 5, 'icon': '😄', 'label': 'Great'},
  ];

  @override
  Widget build(BuildContext context) {
    if (_isSaved) {
      return Scaffold(
        backgroundColor: SenseColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE6F6FF),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: SenseColors.blue800,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Check-in complete — not saved',
                  style: SenseTypography.h2.copyWith(color: SenseColors.navy900),
                ),
                const SizedBox(height: 10),
                Text(
                  'Thank you for trying the check-in. In this prototype your answers '
                  'are not saved and no personal baseline is updated.',
                  style: SenseTypography.body.copyWith(
                    color: SenseColors.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SenseButton(
                  label: 'Return to Dashboard',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: SenseAppBar(
        title: 'Daily Check-in',
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.center,
            child: Text(
              'Step $_currentStep of 2',
              style: SenseTypography.captionMedium.copyWith(
                color: SenseColors.blue800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6EFFC),
                  borderRadius: SenseRadii.pillBorder,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _currentStep == 1 ? 0.5 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: SenseColors.primaryActionGradient,
                      borderRadius: SenseRadii.pillBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_currentStep == 1) ...[
                Text(
                  'How are you feeling right now?',
                  style: SenseTypography.h2.copyWith(color: SenseColors.navy900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select the state that best represents your current mood valence.',
                  style: SenseTypography.bodySecondary,
                ),
                const SizedBox(height: 20),

                // Mood Selection Grid (Emoticons + text labels): options are sized
                // from the available width — 5 per row normally, 3 per row
                // (wrapping) on narrow screens or with large text, and 2 per row
                // if the widest label (bold, as when selected) would otherwise
                // be broken mid-word.
                LayoutBuilder(builder: (context, constraints) {
                  const gap = 8.0;
                  final textScaler = MediaQuery.textScalerOf(context);
                  final scale = textScaler.scale(1.0);
                  double widestLabel = 0;
                  for (final opt in _moodOptions) {
                    final tp = TextPainter(
                      text: TextSpan(
                        text: opt['label'] as String,
                        style: SenseTypography.caption
                            .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                      textDirection: TextDirection.ltr,
                      textScaler: textScaler,
                      maxLines: 1,
                    )..layout();
                    if (tp.width > widestLabel) widestLabel = tp.width;
                    tp.dispose();
                  }
                  double widthFor(int n) =>
                      ((constraints.maxWidth - gap * (n - 1)) / n).floorToDouble();
                  var perRow = (constraints.maxWidth < 330 || scale >= 1.3) ? 3 : 5;
                  while (perRow > 2 && widestLabel + 4 > widthFor(perRow)) {
                    perRow = perRow == 5 ? 3 : 2;
                  }
                  final itemWidth = widthFor(perRow);
                  return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _moodOptions.map((opt) {
                    final isSelected = (_selectedMood == opt['val']);
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: 'Mood: ${opt['label']}',
                      excludeSemantics: true,
                      child: GestureDetector(
                      onTap: () => setState(() => _selectedMood = opt['val'] as int),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: itemWidth,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? SenseColors.navy900 : SenseColors.white,
                          borderRadius: SenseRadii.mdBorder,
                          border: Border.all(
                            color: isSelected ? SenseColors.navy900 : SenseColors.border,
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? SenseShadows.recessed : SenseShadows.card,
                        ),
                        child: Column(
                          children: [
                            Text(
                              opt['icon'] as String,
                              style: const TextStyle(fontSize: 26),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              opt['label'] as String,
                              textAlign: TextAlign.center,
                              style: SenseTypography.caption.copyWith(
                                color: isSelected ? SenseColors.white : SenseColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  }).toList(),
                  );
                }),
                const SizedBox(height: 32),

                // Motivation Level
                Text(
                  'Motivation / Energy Level',
                  style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
                ),
                const SizedBox(height: 6),
                Text(
                  'How energetic or motivated do you feel to complete tasks today?',
                  style: SenseTypography.bodySecondary,
                ),
                const SizedBox(height: 16),
                SenseCard(
                  child: Column(
                    children: [
                      SenseSliderLabels(
                        minLabel: 'Low Energy',
                        valueLabel: 'Rating: $_motivationLevel / 5',
                        maxLabel: 'High Energy',
                      ),
                      Slider(
                        value: _motivationLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _motivationLevel = v.round()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                SenseButton(
                  label: 'Continue to Stress Rating',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => setState(() => _currentStep = 2),
                ),
              ] else ...[
                Text(
                  'Perceived Stress Level',
                  style: SenseTypography.h2.copyWith(color: SenseColors.navy900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rate your subjective perceived stress today (adapted EMA subscale).',
                  style: SenseTypography.bodySecondary,
                ),
                const SizedBox(height: 20),

                SenseCard(
                  child: Column(
                    children: [
                      SenseSliderLabels(
                        minLabel: '1 — Relaxed',
                        valueLabel: 'Score: $_perceivedStress / 5',
                        maxLabel: '5 — Very Stressed',
                        valueStyle: SenseTypography.labelBold.copyWith(
                          color: _perceivedStress >= 4 ? SenseColors.warning : SenseColors.blue800,
                        ),
                      ),
                      Slider(
                        value: _perceivedStress.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: _perceivedStress >= 4
                            ? SenseColors.warning
                            : SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _perceivedStress = v.round()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Non-clinical observation notice
                SenseCard(
                  color: SenseColors.surface,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: SenseColors.blue800,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Planned: once saving is connected, your ratings will be compared '
                          'with your own history, and single unusual days will be smoothed out '
                          'before any pattern is shown. This is not active yet — ratings are '
                          'not saved in this prototype.',
                          style: SenseTypography.caption.copyWith(
                            color: SenseColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SenseButton(
                        label: 'Back',
                        variant: SenseButtonVariant.secondary,
                        onPressed: () => setState(() => _currentStep = 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SenseButton(
                        label: 'Save Check-in',
                        onPressed: _handleSave,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    // No persistence yet: go straight to the honest "not saved" state instead
    // of simulating a saving delay.
    setState(() => _isSaved = true);
  }
}
