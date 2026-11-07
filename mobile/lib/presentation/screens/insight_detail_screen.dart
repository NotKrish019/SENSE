import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_chips.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_navigation.dart';

class InsightDetailScreen extends StatelessWidget {
  final String observationTitle;
  final String primaryFactor;
  final String evidenceSummary;
  final String timeRange;
  final String whatCannotConclude;

  const InsightDetailScreen({
    super.key,
    this.observationTitle = 'Sleep & Workload Co-occurrence',
    this.primaryFactor = 'Rest Consistency (+0.08h sleep)',
    this.evidenceSummary =
        'Your reported sleep duration of 7.8 hours and moderate workload rating coincided with a 18% reduction in subjective stress relative to your 14-day baseline.',
    this.timeRange = 'Oct 24 - Oct 30, 2026',
    this.whatCannotConclude =
        'This statistical co-occurrence reflects observed habits, not a clinical treatment or guaranteed causal relationship.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(title: 'Observation Details'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provenance Tag & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SenseProvenanceBadge(text: 'Longitudinal Analysis'),
                  Text(timeRange, style: SenseTypography.caption),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                observationTitle,
                style: SenseTypography.h2.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 16),

              // Primary Factor Callout
              SenseCard(
                color: SenseColors.surface,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD6EFFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hub_outlined, color: SenseColors.blue600, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Primary Associated Factor',
                            style: SenseTypography.captionMedium.copyWith(
                              color: SenseColors.textSecondary,
                            ),
                          ),
                          Text(
                            primaryFactor,
                            style: SenseTypography.labelBold.copyWith(
                              color: SenseColors.navy900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // What Changed & Evidence
              Text(
                'Observed Patterns in Your Data',
                style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Text(
                  evidenceSummary,
                  style: SenseTypography.body.copyWith(
                    color: SenseColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Boundaries: What the system CANNOT conclude
              Text(
                'Scientific Scope & Boundaries',
                style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                color: const Color(0xFFFBFDFF),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.do_not_disturb_on_outlined, color: SenseColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        whatCannotConclude,
                        style: SenseTypography.caption.copyWith(
                          color: SenseColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Supportive Next Steps (Non-Clinical)
              Text(
                'Supportive Well-being Reflections',
                style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Column(
                  children: [
                    _buildStepRow(
                      Icons.schedule_rounded,
                      'Maintain Bedtime Regularity',
                      'Going to bed within a 30-minute window continues to support baseline equilibrium.',
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    _buildStepRow(
                      Icons.self_improvement_rounded,
                      'Pace Afternoon Demands',
                      'Intentional 5-minute micro-breaks between high-effort tasks buffer acute load spikes.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Back to Insights',
                variant: SenseButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SenseColors.blue600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900)),
              const SizedBox(height: 2),
              Text(body, style: SenseTypography.caption.copyWith(color: SenseColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

