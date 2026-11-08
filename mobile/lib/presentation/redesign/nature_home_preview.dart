
import 'package:flutter/material.dart';

import '../screens/activity_screen.dart';
import '../screens/insight_detail_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sleep_screen.dart';
import '../screens/voice_screen.dart';
import '../screens/workload_screen.dart';
import '../nature/nature_home_sections.dart';
import '../nature/nature_navigation.dart';
import '../nature/nature_widgets.dart';
import 'nature_check_in_preview.dart';

// Moved to production in Phase 1; re-exported for the preview's tests.
export '../nature/nature_navigation.dart' show NatureBottomBar, NatureTopBar;
export '../nature/nature_widgets.dart' show NatureJournalSheet, NaturePrintedAction;
import 'nature_illustrations.dart';
import 'nature_tokens.dart';

/// REDESIGN PROTOTYPE (refined): the Home screen in the "Restorative Nature /
/// Illustrated Journal" style, responsive from 320 px phones to 1440 px
/// desktops.
///
/// Viewable only through `lib/main_redesign_preview.dart`; the live app is
/// unchanged. Behaviour matches `MainShell` + `DashboardScreen`: Home /
/// Insights / + check-in / Profile; the status link opens Insights; the six
/// inputs open their existing screens; the sample observation opens Insight
/// detail. Every check-in entry opens the redesigned check-in prototype
/// (`NatureCheckInPreview`); Insights and Profile still use the current design.
class NatureHomePreview extends StatefulWidget {
  const NatureHomePreview({super.key});

  @override
  State<NatureHomePreview> createState() => _NatureHomePreviewState();
}

class _NatureHomePreviewState extends State<NatureHomePreview> {
  int _index = 0;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _scrollOffset.value = _scroll.offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= NatureBreakpoints.desktop;

    // Hidden tabs stop their animations (TickerMode).
    Widget tab(int i, Widget child) => TickerMode(enabled: _index == i, child: child);
    Widget narrow(Widget child) => desktop
        ? Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760), child: child))
        : child;

    final pages = IndexedStack(
      index: _index,
      children: [
        tab(
          0,
          _NatureHome(
            desktop: desktop,
            controller: _scroll,
            scrollOffset: _scrollOffset,
            open: _open,
            openInsights: () => _select(1),
            openProfile: () => _select(2),
          ),
        ),
        tab(1, narrow(const InsightsScreen(isTabRoot: true))),
        tab(2, narrow(const SettingsScreen(isTabRoot: true))),
      ],
    );

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: desktop
            // Desktop: header navigation comes first in focus order, as on
            // the web.
            ? Column(
                children: [
                  FocusTraversalGroup(
                    child: NatureTopBar(
                      overSky: _index == 0,
                      currentIndex: _index,
                      onTap: _select,
                      onCheckIn: () => _open(const NatureCheckInPreview()),
                    ),
                  ),
                  Expanded(child: FocusTraversalGroup(child: pages)),
                ],
              )
            // Mobile/tablet: page content first, then the bottom bar.
            : FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FocusTraversalGroup(child: pages),
                ),
              ),
        bottomNavigationBar: desktop
            ? null
            : FocusTraversalGroup(
                child: NatureBottomBar(
                  currentIndex: _index,
                  onTap: _select,
                  onCheckIn: () => _open(const NatureCheckInPreview()),
                ),
              ),
      ),
    );
  }
}


class _NatureHome extends StatelessWidget {
  final bool desktop;
  final ScrollController controller;
  final ValueNotifier<double> scrollOffset;
  final void Function(Widget) open;
  final VoidCallback openInsights;
  final VoidCallback openProfile;

  const _NatureHome({
    required this.desktop,
    required this.controller,
    required this.scrollOffset,
    required this.open,
    required this.openInsights,
    required this.openProfile,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final width = mq.width;
    final now = DateTime.now();

    final cta = NaturePrintedAction(
      label: "Begin today's check-in",
      onTap: () => open(const NatureCheckInPreview()),
    );
    final today = NatureTodayEntry(onAbout: openInsights);
    final example = NatureExampleObservation(onOpen: () => open(const InsightDetailScreen()));
    final support = NatureSupportLine(onTap: openProfile);

    final sheetContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NatureWelcome(date: now),
        const SizedBox(height: 22),
        cta,
        const SizedBox(height: 26),
        today,
      ],
    );

    if (desktop) {
      final sceneH = (mq.height * 0.74).clamp(480.0, 700.0);
      final margin = width > NatureBreakpoints.maxContent + 80
          ? (width - NatureBreakpoints.maxContent) / 2
          : 40.0;
      return SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The landscape spans the window; the journal sheet floats over
            // its lower left, leaving the sun, the river and the rock open.
            Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: sceneH,
                  child: LivingLandscape(
                    height: sceneH,
                    scrollOffset: scrollOffset,
                    sunAt: const Alignment(0.42, -0.42),
                    rockLeft: 0.42,
                    rockWidth: 0.2,
                  ),
                ),
                // Torn paper edge where the landscape meets the page.
                Positioned(
                  top: sceneH - 16,
                  left: 0,
                  right: 0,
                  height: 22,
                  child: const IgnorePointer(child: CustomPaint(painter: NatureTornEdgePainter())),
                ),
                SizedBox(height: sceneH + 40),
                Padding(
                  padding: EdgeInsets.only(left: margin, top: sceneH * 0.2),
                  child: SizedBox(
                    width: 470,
                    child: NatureJournalSheet(
                      floating: true,
                      child: sheetContent,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(margin, 56, margin, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NatureWaysToReflect(modalities: _modalities, open: open, columns: width >= 1240 ? 3 : 2),
                  const SizedBox(height: 56),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: example),
                      const SizedBox(width: 56),
                      Expanded(flex: 5, child: Padding(padding: const EdgeInsets.only(top: 6), child: support)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Phone and tablet: the landscape runs edge to edge; a journal sheet with
    // a torn top edge rises over its foreground.
    final sceneH = (mq.height * 0.46).clamp(300.0, width >= NatureBreakpoints.tablet ? 460.0 : 420.0);
    final side = width > NatureBreakpoints.maxReading + 2 * NatureSpace.gutter
        ? (width - NatureBreakpoints.maxReading) / 2
        : NatureSpace.gutter;
    return ListView(
      controller: controller,
      padding: EdgeInsets.zero,
      children: [
        Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: sceneH,
              child: LivingLandscape(
                height: sceneH,
                scrollOffset: scrollOffset,
                sunAt: const Alignment(0.5, -0.38),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: sceneH - 54),
              child: NatureJournalSheet(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: side - NatureSpace.gutter),
                  child: sheetContent,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(side - 4, 4, side - 8, 0),
                  child: NatureMasthead(onProfile: openProfile),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(side, 12, side, NatureSpace.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NatureWaysToReflect(modalities: _modalities, open: open, columns: 1),
              const SizedBox(height: 36),
              example,
              const SizedBox(height: NatureSpace.xl),
              support,
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Ways to reflect -------------------------------------------------------------

// Short, honest descriptions of what each screen does in this prototype.
final _modalities = <NatureModality>[
  NatureModality(Icons.wb_twilight_outlined, 'Check-in', 'Mood, energy and stress',
      () => const NatureCheckInPreview()),
  NatureModality(Icons.menu_book_outlined, 'Journal', 'Write freely · not saved yet',
      () => const JournalScreen()),
  NatureModality(Icons.bedtime_outlined, 'Sleep', 'Duration, timing and rest',
      () => const SleepScreen()),
  NatureModality(Icons.layers_outlined, 'Workload', 'Demand, effort and deadlines',
      () => const WorkloadScreen()),
  NatureModality(Icons.mic_none_rounded, 'Voice', 'Planned · not built, no audio recorded',
      () => const VoiceScreen()),
  NatureModality(Icons.directions_walk_rounded, 'Activity', 'Manual entry · no health app connected',
      () => const ActivityScreen()),
];
