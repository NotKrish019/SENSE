import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/stress_summary_card.dart';
import '../widgets/insight_card.dart';
import '../widgets/sense_chips.dart';
import '../widgets/sense_navigation.dart';

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
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Sleep', 'Workload', 'Activity', 'Voice', 'Journal'];

  @override
  Widget build(BuildContext context) {
    if (_currentNavIndex == 1) {
      return const InsightsScreen();
    } else if (_currentNavIndex == 2) {
      return const DesignShowcaseScreen(); // Tools tab -> Design System Showcase
    } else if (_currentNavIndex == 3) {
      return const SettingsScreen();
    }

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
              // Header bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      Column(
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
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.style_outlined, color: SenseColors.blue600),
                        tooltip: 'Design System Showcase',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DesignShowcaseScreen()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.shield_outlined, color: SenseColors.navy900),
                        tooltip: 'Privacy & Crisis Support',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Chips matching UI Toolkit Board
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _filters[i];
                    return SenseFilterChip(
                      label: f,
                      isSelected: _selectedFilter == f,
                      onTap: () => setState(() => _selectedFilter = f),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Hero Current Stress Card (UI Toolkit Board)
              StressSummaryCard(
                statusText: 'Moderate',
                scoreFraction: 0.52,
                subtitle: 'Within your normal baseline corridor (Day 15/14 calibrated)',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InsightsScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Section Heading: Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const SizedBox(height: 12),

              // 3x2 Quick Action Tiles (matching UI Toolkit Board)
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Observed Pattern',
                    style: SenseTypography.h3.copyWith(
                      color: SenseColors.navy900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SenseStatusTag(level: StressStatusLevel.good, customLabel: 'Aligned'),
                ],
              ),
              const SizedBox(height: 12),

              // Insight Card (matching UI Toolkit Board)
              SenseInsightCard(
                title: 'Insight',
                narrative:
                    'Your stress is lower today, likely due to better sleep and a lighter workload.',
                provenance: 'Observed pattern',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InsightDetailScreen(
                        observationTitle: 'Sleep & Workload Co-occurrence',
                        primaryFactor: 'Rest Consistency (+0.08h sleep)',
                        evidenceSummary:
                            'Your reported sleep duration of 7.8 hours and moderate workload rating coincided with a 18% reduction in subjective stress relative to your 14-day baseline.',
                        timeRange: 'Oct 24 - Oct 30, 2026',
                        whatCannotConclude:
                            'This statistical co-occurrence reflects observed habits, not a clinical treatment or guaranteed causal relationship.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SenseBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (idx) => setState(() => _currentNavIndex = idx),
        onAddTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheckInScreen()),
          );
        },
      ),
    );
  }
}
