import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_chips.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_navigation.dart';
import '../widgets/sample_data_banner.dart';
import '../../core/constants/prototype_copy.dart';

class InsightDetailScreen extends StatelessWidget {
  final String observationTitle;
  final String primaryFactor;
  final String evidenceSummary;
  final String timeRange;
  final String whatCannotConclude;
  /// True while the observation is an illustrative example rather than one
  /// computed from the user's saved data (always true in this prototype).
  final bool isSampleData;

  const InsightDetailScreen({
    super.key,
    this.observationTitle = 'Sleep and stress changed in the same week',
    this.primaryFactor = 'Recorded sleep duration · Self-reported stress',
    this.evidenceSummary =
        'In this example, recorded sleep duration was longer and self-reported '
        'stress was lower during the same week. The two changed together; this '
        'does not show that one caused the other.',
    this.timeRange = 'Example week',
    this.whatCannotConclude =
        '${PrototypeCopy.noCausalClaim} SENSE does not yet produce observations '
        'from your own data.',
    this.isSampleData = true,
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
              if (isSampleData) ...[
                const SenseSampleDataBanner(),
                const SizedBox(height: 16),
              ],
              // Provenance Tag & Title
              SizedBox(
                width: double.infinity, // lets spaceBetween reach the right edge
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    isSampleData
                        ? const SenseProvenanceBadge.sampleData()
                        : const SenseProvenanceBadge(text: 'Observed pattern'),
                    Text(timeRange, style: SenseTypography.caption),
                  ],
                ),
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
                            'Indicators involved',
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
                isSampleData ? 'What this example shows' : 'What changed in your recorded data',
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
                'What this cannot tell you',
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
                'General well-being ideas',
                style: SenseTypography.h3.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 8),
              SenseCard(
                child: Column(
                  children: [
                    _buildStepRow(
                      Icons.schedule_rounded,
                      'A regular bedtime',
                      'Some people find a consistent bedtime helpful. This is general '
                      'information, not advice based on your data.',
                    ),
                    const Divider(color: SenseColors.border, height: 20),
                    _buildStepRow(
                      Icons.self_improvement_rounded,
                      'Short breaks',
                      'Some people find short breaks between demanding tasks help them '
                      'pace their day. This is general information, not a treatment.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SenseButton(
                label: 'Back',
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

