import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/living_landscape.dart';
import '../nature/nature_home_sections.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_tappable.dart';
import 'activity_screen.dart';
import 'check_in_screen.dart';
import 'design_showcase_screen.dart';
import 'insight_detail_screen.dart';
import 'insights_screen.dart';
import 'journal_screen.dart';
import 'settings_screen.dart';
import 'sleep_screen.dart';
import 'voice_screen.dart';
import 'workload_screen.dart';

/// Production Home (Living Landscapes, Phase 1).
///
/// A layered paper-diorama landscape with a journal sheet rising over it:
/// greeting and date, the primary check-in action, today's honest status, the
/// six voluntary inputs, a clearly marked sample observation and the support
/// line. Every action opens its real production screen; Insights and Profile
/// switch tabs through [MainShell] when it provides [onOpenInsights] and
/// [onOpenProfile], and are pushed when the screen is used on its own.
///
/// No user data, stress score or insight is shown: there is none yet.
class DashboardScreen extends StatefulWidget {
  /// Provided by MainShell to switch tabs instead of pushing duplicate
  /// Insights/Profile screens. When null (standalone use), screens are pushed.
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenProfile;

  const DashboardScreen({super.key, this.onOpenInsights, this.onOpenProfile});

  /// Accessible name and tooltip of the profile control (unchanged from the
  /// previous Home, so screen-reader users find it under the same name).
  static const String profileLabel = 'Profile, privacy & support contacts';

  /// The six voluntary inputs with short, honest descriptions of what each
  /// screen does today, and their production destinations.
  static final List<NatureModality> modalities = [
    NatureModality(Icons.wb_twilight_outlined, 'Check-in', 'Mood, energy and stress',
        () => const CheckInScreen()),
    NatureModality(Icons.menu_book_outlined, 'Journal', 'Write freely · not saved yet',
        () => const JournalScreen()),
    NatureModality(Icons.bedtime_outlined, 'Sleep', 'Duration, timing and rest',
        () => const SleepScreen()),
    NatureModality(Icons.layers_outlined, 'Workload', 'Demand, effort and deadlines',
        () => const WorkloadScreen()),
    NatureModality(Icons.mic_none_rounded, 'Voice', 'Planned · demo only, no audio recorded',
        () => const VoiceScreen()),
    NatureModality(Icons.directions_walk_rounded, 'Activity',
        'Manual entry · no health app connected', () => const ActivityScreen()),
  ];

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  void _openInsights() =>
      widget.onOpenInsights != null ? widget.onOpenInsights!() : _open(const InsightsScreen());

  void _openProfile() =>
      widget.onOpenProfile != null ? widget.onOpenProfile!() : _open(const SettingsScreen());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: LayoutBuilder(builder: (context, c) {
          return c.maxWidth >= NatureBreakpoints.desktop ? _desktop(context, c) : _phone(context, c);
        }),
      ),
    );
  }

  // Sheet content shared by all layouts: greeting, primary action, Today.
  Widget _sheetContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NatureWelcome(date: DateTime.now()),
          const SizedBox(height: 22),
          NaturePrintedAction(
            label: "Begin today's check-in",
            onTap: () => _open(const CheckInScreen()),
          ),
          const SizedBox(height: 26),
          NatureTodayEntry(onAbout: _openInsights),
        ],
      );

  Widget get _example => NatureExampleObservation(onOpen: () => _open(const InsightDetailScreen()));
  Widget get _support => NatureSupportLine(onTap: _openProfile);

  /// Developer-only component gallery, compiled out of release builds.
  List<Widget> get _devActions => [
        if (!kReleaseMode)
          SenseTappable(
            semanticLabel: 'Design System Showcase (developer only)',
            tooltip: 'Design System Showcase (developer only)',
            circle: true,
            focusColor: NatureColors.focus,
            hoverColor: NatureColors.hover,
            onTap: () => _open(const DesignShowcaseScreen()),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.style_outlined, color: NatureColors.inkMuted, size: 21),
            ),
          ),
      ];

  // Desktop (>= 1024): the landscape spans the window under the top bar; a
  // floating journal sheet sits over its lower left, leaving the sun, river
  // and rock visible; the inputs and observation follow in wide columns.
  Widget _desktop(BuildContext context, BoxConstraints c) {
    final width = c.maxWidth;
    final sceneH = (MediaQuery.sizeOf(context).height * 0.74).clamp(480.0, 700.0);
    final margin = width > NatureBreakpoints.maxContent + 80
        ? (width - NatureBreakpoints.maxContent) / 2
        : 40.0;
    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  scrollOffset: _scrollOffset,
                  sunAt: const Alignment(0.42, -0.42),
                  rockLeft: 0.42,
                  rockWidth: 0.2,
                ),
              ),
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
                  child: NatureJournalSheet(floating: true, child: _sheetContent()),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(margin, 56, margin, 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NatureWaysToReflect(
                    modalities: DashboardScreen.modalities,
                    open: _open,
                    columns: width >= 1240 ? 3 : 2),
                const SizedBox(height: 56),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _example),
                    const SizedBox(width: 56),
                    Expanded(
                        flex: 5,
                        child: Padding(padding: const EdgeInsets.only(top: 6), child: _support)),
                  ],
                ),
                if (_devActions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Align(alignment: Alignment.centerRight, child: _devActions.first),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Phone and tablet: the landscape runs edge to edge and a journal sheet with
  // a torn top edge rises over its foreground. On tablets the text column is
  // capped at a comfortable reading width and centred.
  Widget _phone(BuildContext context, BoxConstraints c) {
    final width = c.maxWidth;
    final sceneH = (MediaQuery.sizeOf(context).height * 0.46)
        .clamp(300.0, width >= NatureBreakpoints.tablet ? 460.0 : 420.0);
    final side = width > NatureBreakpoints.maxReading + 2 * NatureSpace.gutter
        ? (width - NatureBreakpoints.maxReading) / 2
        : NatureSpace.gutter;
    return ListView(
      controller: _scroll,
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
                scrollOffset: _scrollOffset,
                sunAt: const Alignment(0.5, -0.38),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: sceneH - 54),
              child: NatureJournalSheet(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: side - NatureSpace.gutter),
                  child: _sheetContent(),
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
                  child: NatureMasthead(
                    onProfile: _openProfile,
                    profileLabel: DashboardScreen.profileLabel,
                    actions: _devActions,
                  ),
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
              NatureWaysToReflect(modalities: DashboardScreen.modalities, open: _open),
              const SizedBox(height: 36),
              _example,
              const SizedBox(height: NatureSpace.xl),
              _support,
            ],
          ),
        ),
      ],
    );
  }
}
