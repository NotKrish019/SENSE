import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/prototype_copy.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/stress_summary_card.dart';
import '../widgets/insight_card.dart';
import '../widgets/sense_chips.dart';

import 'check_in_screen.dart';
import 'journal_screen.dart';
import 'sleep_screen.dart';
import 'workload_screen.dart';
import 'voice_screen.dart';
import 'activity_screen.dart';
import 'insights_screen.dart';
import 'insight_detail_screen.dart';
import 'settings_screen.dart';
import 'design_showcase_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// Provided by MainShell to switch tabs instead of pushing duplicate
  /// Insights/Profile screens. When null (standalone use), screens are pushed.
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenProfile;

  const DashboardScreen({super.key, this.onOpenInsights, this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar (brand block flexes so large text wraps, not overflows)
              Row(
                children: [
                  Expanded(
                    child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SenseColors.primaryActionGradient,
                        ),
                        child: const Icon(
                          Icons.waves_rounded,
                          color: SenseColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SENSE',
                            style: SenseTypography.labelBold.copyWith(
                              fontSize: 16,
                              letterSpacing: 1.2,
                              color: SenseColors.navy900,
                            ),
                          ),
                          Text(
                            'Daily Well-being Overview',
                            style: SenseTypography.caption.copyWith(
                              color: SenseColors.textSecondary,
                            ),
                          ),
                        ],
                        ),
                      ),
                    ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Developer-only component gallery: compiled out of
                      // release builds (kReleaseMode is a compile-time constant).
                      if (!kReleaseMode)
                        IconButton(
                          icon: const Icon(Icons.style_outlined, color: SenseColors.blue600),
                          tooltip: 'Design System Showcase (developer only)',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DesignShowcaseScreen()),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.shield_outlined, color: SenseColors.navy900),
                        tooltip: 'Profile, privacy & support contacts',
                        onPressed: widget.onOpenProfile ??
                            () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // (Filter chips removed: they highlighted on tap but filtered
              // nothing, and no filtering behaviour is defined.)

              // Hero Current Stress Card (UI Toolkit Board)
              // No baseline exists yet, so show an honest empty state rather
              // than a stress level that was never calculated.
              StressSummaryCard(
                statusText: PrototypeCopy.noBaselineTitle,
                subtitle: PrototypeCopy.noBaselineDescription,
                onTap: widget.onOpenInsights ??
                    () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InsightsScreen()),
                        ),
              ),
              const SizedBox(height: 24),

              // Section Heading: Quick Actions (badge moves to a new line if needed)
              SizedBox(
                width: double.infinity, // lets spaceBetween reach the right edge
                child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Record Daily Indicators',
                    style: SenseTypography.h3.copyWith(
                      color: SenseColors.navy900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SenseProvenanceBadge(text: 'Voluntary Inputs'),
                ],
              ),
              ),
              const SizedBox(height: 12),

              // Quick Action Tiles (3x2 on phones; 2 columns when narrow/large text)
              _ResponsiveTileGrid(
                children: [
                  QuickActionTile(
                    label: 'Check-in',
                    icon: Icons.favorite_border_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CheckInScreen()),
                      );
                    },
                  ),
                  QuickActionTile(
                    label: 'Journal',
                    icon: Icons.menu_book_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const JournalScreen()),
                      );
                    },
                  ),
                  QuickActionTile(
                    label: 'Sleep',
                    icon: Icons.bedtime_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SleepScreen()),
                      );
                    },
                  ),
                  QuickActionTile(
                    label: 'Workload',
                    icon: Icons.layers_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WorkloadScreen()),
                      );
                    },
                  ),
                  QuickActionTile(
                    label: 'Voice',
                    icon: Icons.mic_none_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VoiceScreen()),
                      );
                    },
                  ),
                  QuickActionTile(
                    label: 'Activity',
                    icon: Icons.directions_run_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ActivityScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section Heading: Recent Observation
              SizedBox(
                width: double.infinity, // lets spaceBetween reach the right edge
                child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Observed Pattern',
                    style: SenseTypography.h3.copyWith(
                      color: SenseColors.navy900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SenseProvenanceBadge.sampleData(),
                ],
              ),
              ),
              const SizedBox(height: 12),

              // Insight Card (matching UI Toolkit Board)
              SenseInsightCard(
                title: 'Example observation',
                narrative:
                    'Example: recorded sleep duration and self-reported stress '
                    'changed during the same period. This is illustrative, not '
                    'based on your data.',
                provenance: PrototypeCopy.sampleDataLabel,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InsightDetailScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of quick-action tiles whose row height follows the content, so tiles
/// grow with larger text instead of overflowing a fixed aspect ratio.
/// Uses 2 columns on narrow widths or large text, otherwise 3.
class _ResponsiveTileGrid extends StatelessWidget {
  final List<Widget> children;
  static const double _gap = 12;

  const _ResponsiveTileGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth < 300 || textScale >= 1.5) ? 2 : 3;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final rowChildren = <Widget>[];
          for (var c = 0; c < columns; c++) {
            if (c > 0) rowChildren.add(const SizedBox(width: _gap));
            final idx = i + c;
            rowChildren.add(Expanded(
              // Minimum keeps the toolkit's near-square tiles; content can
              // still make the row taller at larger text sizes.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120),
                child: idx < children.length ? children[idx] : const SizedBox.shrink(),
              ),
            ));
          }
          if (rows.isNotEmpty) rows.add(const SizedBox(height: _gap));
          rows.add(IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren),
          ));
        }
        return Column(children: rows);
      },
    );
  }
}
