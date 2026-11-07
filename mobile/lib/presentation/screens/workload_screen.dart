import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';

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
  bool _isSaving = false;

  double get _calculatedIndex {
    return 0.5 * _mentalDemand + 0.5 * _effortRating + 0.2 * _deadlinesCount.clamp(0, 5);
  }

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Workload Demand',
                          style: SenseTypography.captionMedium.copyWith(
                            color: SenseColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Index: ${_calculatedIndex.toStringAsFixed(1)} / 6.0',
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

              // Mental Demand Rating
              Text(
                'Mental Demand (NASA-TLX)',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 — Very Light', style: SenseTypography.caption),
                        Text(
                          '$_mentalDemand / 5',
                          style: SenseTypography.labelBold.copyWith(color: SenseColors.blue800),
                        ),
                        Text('5 — Intense', style: SenseTypography.caption),
                      ],
                    ),
                    Slider(
                      value: _mentalDemand.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: SenseColors.blue600,
                      inactiveColor: const Color(0xFFD6EFFC),
                      onChanged: (v) => setState(() => _mentalDemand = v.round()),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 — Minimal', style: SenseTypography.caption),
                        Text(
                          '$_effortRating / 5',
                          style: SenseTypography.labelBold.copyWith(color: SenseColors.blue800),
                        ),
                        Text('5 — Exhausting', style: SenseTypography.caption),
                      ],
                    ),
                    Slider(
                      value: _effortRating.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: SenseColors.blue600,
                      inactiveColor: const Color(0xFFD6EFFC),
                      onChanged: (v) => setState(() => _effortRating = v.round()),
                    ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming deliverables:',
                      style: SenseTypography.body,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: SenseColors.blue600),
                          onPressed: _deadlinesCount > 0
                              ? () => setState(() => _deadlinesCount--)
                              : null,
                        ),
                        Text(
                          '$_deadlinesCount',
                          style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: SenseColors.blue600),
                          onPressed: () => setState(() => _deadlinesCount++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Save Workload Rating',
                icon: Icons.save_rounded,
                isLoading: _isSaving,
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
    setState(() => _isSaving = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workload metrics added to personal baseline.'),
            backgroundColor: SenseColors.navy900,
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }
}
