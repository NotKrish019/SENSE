import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sample_data_banner.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';
import '../widgets/sense_inputs.dart';

class WorkloadScreen extends StatefulWidget {
  const WorkloadScreen({super.key});

  @override
  State<WorkloadScreen> createState() => _WorkloadScreenState();
}

class _WorkloadScreenState extends State<WorkloadScreen> {
  int _mentalDemand = 3; // 1 to 5
  int _effortRating = 3; // 1 to 5
  int _deadlinesCount = 1;
  int _tasksCompleted = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(title: 'Workload & Demands'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Index Card
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
                        Icons.layers_outlined,
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
                          'Your ratings (self-reported)',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Demand $_mentalDemand/5 · Effort $_effortRating/5 · '
                          '$_deadlinesCount deadline${_deadlinesCount == 1 ? '' : 's'}',
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

              // Mental Demand Rating
              Text(
                'Mental demand (adapted from NASA-TLX)',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 6),
              Text(
                'How much mental and perceptual activity was required (thinking, deciding, calculating)?',
                style: SenseTypography.bodySecondary,
              ),
              const SizedBox(height: 10),
              SenseCard(
                child: Column(
                  children: [
                    SenseSliderLabels(
                      minLabel: '1 — Very Light',
                      valueLabel: '$_mentalDemand / 5',
                      maxLabel: '5 — Intense',
                    ),
                    MergeSemantics(child: Semantics(
                      // Name merged into the slider's own node (Task 8): it previously had none.
                      label: 'Mental demand',
                      child: Slider(
                        semanticFormatterCallback: (v) => '${v.round()} of 5',
                        value: _mentalDemand.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _mentalDemand = v.round()),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Effort Rating
              Text(
                'Effort Invested',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 6),
              Text(
                'How hard did you have to work to accomplish your level of performance?',
                style: SenseTypography.bodySecondary,
              ),
              const SizedBox(height: 10),
              SenseCard(
                child: Column(
                  children: [
                    SenseSliderLabels(
                      minLabel: '1 — Minimal',
                      valueLabel: '$_effortRating / 5',
                      maxLabel: '5 — Exhausting',
                    ),
                    MergeSemantics(child: Semantics(
                      // Name merged into the slider's own node (Task 8): it previously had none.
                      label: 'Effort',
                      child: Slider(
                        semanticFormatterCallback: (v) => '${v.round()} of 5',
                        value: _effortRating.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: SenseColors.blue600,
                        inactiveColor: const Color(0xFFD6EFFC),
                        onChanged: (v) => setState(() => _effortRating = v.round()),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Impending Deadlines Counter
              Text(
                'Impending Deadlines (Next 48 Hours)',
                style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                // Label wraps; the stepper keeps its size. Icon buttons carry
                // tooltips, which also serve as their screen-reader labels.
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Upcoming deliverables:',
                      style: SenseTypography.body,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'One fewer deadline',
                          icon: const Icon(Icons.remove_circle_outline, color: SenseColors.blue600),
                          onPressed: _deadlinesCount > 0
                              ? () => setState(() => _deadlinesCount--)
                              : null,
                        ),
                        Semantics(
                          liveRegion: true,
                          label: '$_deadlinesCount deadlines',
                          excludeSemantics: true,
                          child: Text(
                            '$_deadlinesCount',
                            style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
                          ),
                        ),
                        IconButton(
                          tooltip: 'One more deadline',
                          icon: const Icon(Icons.add_circle_outline, color: SenseColors.blue600),
                          onPressed: () => setState(() => _deadlinesCount++),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Save Workload Rating',
                icon: Icons.save_rounded,
                onPressed: _saveWorkload,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _saveWorkload() {
    // Persistence is not connected yet: report that honestly.
    showPrototypeNotSavedMessage(context, 'workload rating');
  }
}
