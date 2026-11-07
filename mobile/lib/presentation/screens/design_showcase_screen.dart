import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_chips.dart';
import '../widgets/sense_inputs.dart';
import '../widgets/sense_charts.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/stress_summary_card.dart';
import '../widgets/insight_card.dart';
import '../widgets/sense_navigation.dart';

class DesignShowcaseScreen extends StatefulWidget {
  const DesignShowcaseScreen({super.key});

  @override
  State<DesignShowcaseScreen> createState() => _DesignShowcaseScreenState();
}

class _DesignShowcaseScreenState extends State<DesignShowcaseScreen> {
  bool _toggleVal = true;
  double _sliderVal = 3.0;
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(
        title: 'SENSE UI Toolkit Showcase',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6EFFC),
                  borderRadius: SenseRadii.pillBorder,
                ),
                child: Text(
                  'Visual Design Specification 1.0 (design.md)',
                  style: SenseTypography.captionMedium.copyWith(
                    color: SenseColors.blue800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Design System & Tokens',
                style: SenseTypography.h1.copyWith(color: SenseColors.navy900),
              ),
              const SizedBox(height: 6),
              Text(
                'Authoritative implementation of the SENSE UI Toolkit Board.',
                style: SenseTypography.bodySecondary,
              ),
              const SizedBox(height: 24),

              // 1. Color Palette Swatches
              _buildSectionHeader('1. Colour Palette Swatches'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSwatch('Navy 900', '#012F5F', SenseColors.navy900, SenseColors.white),
                  _buildSwatch('Blue 800', '#02549B', SenseColors.blue800, SenseColors.white),
                  _buildSwatch('Accent 600', '#059BE0', SenseColors.blue600, SenseColors.white),
                  _buildSwatch('Highlight 500', '#07CCFC', SenseColors.cyan500, SenseColors.navy900),
                  _buildSwatch('Soft Cyan 300', '#58E2F9', SenseColors.cyan300, SenseColors.navy900),
                  _buildSwatch('Canvas', '#E6F6FF', SenseColors.background, SenseColors.navy900, hasBorder: true),
                  _buildSwatch('Surface', '#F4F7F7', SenseColors.surface, SenseColors.navy900, hasBorder: true),
                  _buildSwatch('White', '#FFFFFF', SenseColors.white, SenseColors.navy900, hasBorder: true),
                ],
              ),
              const SizedBox(height: 28),

              // 2. Buttons & Actions
              _buildSectionHeader('2. Buttons & Component States'),
              SenseCard(
                child: Column(
                  children: [
                    SenseButton(
                      label: 'Primary Action (Get Started)',
                      icon: Icons.arrow_forward_rounded,
                      variant: SenseButtonVariant.primary,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SenseButton(
                            label: 'Secondary (Save)',
                            variant: SenseButtonVariant.secondary,
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SenseButton(
                            label: 'Outline (+ Add)',
                            icon: Icons.add,
                            isIconTrailing: false,
                            variant: SenseButtonVariant.outline,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SenseButton(
                            label: 'Disabled',
                            variant: SenseButtonVariant.primary,
                            onPressed: null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SenseButton(
                            label: 'Loading...',
                            isLoading: true,
                            variant: SenseButtonVariant.secondary,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 3. Inputs & Controls
              _buildSectionHeader('3. Inputs & Interactive Controls'),
              SenseCard(
                child: Column(
                  children: [
                    const SenseInputField(
                      label: 'Text Field (with Leading Icon)',
                      hintText: 'Enter your note...',
                      prefixIcon: Icons.edit_note_rounded,
                    ),
                    const SizedBox(height: 16),
                    SenseToggleSwitch(
                      label: 'Toggle Control (Cyan Pill)',
                      value: _toggleVal,
                      onChanged: (v) => setState(() => _toggleVal = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Continuous Slider', style: SenseTypography.labelBold),
                        Text('${_sliderVal.toStringAsFixed(1)} / 5.0', style: SenseTypography.captionMedium),
                      ],
                    ),
                    Slider(
                      value: _sliderVal,
                      min: 1.0,
                      max: 5.0,
                      activeColor: SenseColors.blue600,
                      inactiveColor: const Color(0xFFD6EFFC),
                      onChanged: (v) => setState(() => _sliderVal = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 4. Chips, Tags & Status Badges
              _buildSectionHeader('4. Chips, Tags & Provenance Badges'),
              SenseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['All', 'Sleep', 'Workload', 'Activity', 'Voice', 'Journal'].map((f) {
                        return SenseFilterChip(
                          label: f,
                          isSelected: _selectedFilter == f,
                          onTap: () => setState(() => _selectedFilter = f),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: SenseColors.border),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SenseStatusTag(level: StressStatusLevel.good, customLabel: 'Good'),
                        SenseStatusTag(level: StressStatusLevel.moderate, customLabel: 'Moderate'),
                        SenseStatusTag(level: StressStatusLevel.high, customLabel: 'High'),
                        SenseProvenanceBadge(text: 'You reported'),
                        SenseProvenanceBadge(text: 'Observed pattern'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 5. Neumorphic Surfaces & Hero Card
              _buildSectionHeader('5. Hero Card & Quick Action Tile'),
              // Component preview with illustrative values only.
              const StressSummaryCard(
                statusText: 'Sample state',
                scoreFraction: 0.52,
                subtitle: 'Sample data — component preview, not a real stress level.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: QuickActionTile(
                      label: 'Check-in',
                      icon: Icons.favorite_border_rounded,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionTile(
                      label: 'Sleep',
                      icon: Icons.bedtime_outlined,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionTile(
                      label: 'Workload',
                      icon: Icons.layers_outlined,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 6. Data Visuals & Charts
              _buildSectionHeader('6. Charts & Data Visuals'),
              const SenseSplineTrendChart(
                values: [2.8, 3.2, 3.0, 3.4, 2.9, 2.4, 2.2],
                title: 'Stress Trend',
                subtitle: 'Component preview',
                isSampleData: true,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SenseWeeklyBarChart(
                      dayFractions: const [0.35, 0.45, 0.65, 0.50, 0.70, 0.85, 0.40],
                      isSampleData: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    flex: 2,
                    child: SenseDonutQualityChart(percentage: 72, isSampleData: true),
                  ),
                ],
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: SenseTypography.h3.copyWith(
          color: SenseColors.navy900,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSwatch(String name, String hex, Color color, Color textColor, {bool hasBorder = false}) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: SenseRadii.mdBorder,
        border: hasBorder ? Border.all(color: SenseColors.border, width: 1.2) : null,
        boxShadow: SenseShadows.recessed,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 24),
          Text(
            name,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Text(
            hex,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

