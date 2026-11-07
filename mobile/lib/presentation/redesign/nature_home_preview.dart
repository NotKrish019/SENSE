import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/prototype_copy.dart';
import '../screens/activity_screen.dart';
import '../screens/check_in_screen.dart';
import '../screens/insight_detail_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sleep_screen.dart';
import '../screens/voice_screen.dart';
import '../screens/workload_screen.dart';
import '../widgets/sense_logo.dart';
import '../widgets/sense_tappable.dart';
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
/// detail. Insights and Profile still use the current design.
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
                      onCheckIn: () => _open(const CheckInScreen()),
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
                  onCheckIn: () => _open(const CheckInScreen()),
                ),
              ),
      ),
    );
  }
}

/// Greeting by local time of day (no personal data).
String natureGreeting(int hour) {
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
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

    final cta = _PrintedAction(
      label: "Begin today's check-in",
      onTap: () => open(const CheckInScreen()),
    );
    final today = _TodayEntry(onAbout: openInsights);
    final example = _ExampleObservation(onOpen: () => open(const InsightDetailScreen()));
    final support = _SupportLine(onTap: openProfile);

    final sheetContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Welcome(date: now),
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
                  child: const IgnorePointer(child: CustomPaint(painter: _TornEdgePainter())),
                ),
                SizedBox(height: sceneH + 40),
                Padding(
                  padding: EdgeInsets.only(left: margin, top: sceneH * 0.2),
                  child: SizedBox(
                    width: 470,
                    child: _JournalSheet(
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
                  _WaysToReflect(open: open, columns: width >= 1240 ? 3 : 2),
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
              child: _JournalSheet(
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
                  child: _Masthead(onProfile: openProfile),
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
              _WaysToReflect(open: open, columns: 1),
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

/// A sheet of journal paper laid over the landscape: torn top edge, a soft
/// shadow onto the scene, faint ruled lines. A surface with a reason: it is
/// where today's words are written.
class _JournalSheet extends StatelessWidget {
  final Widget child;
  final bool floating;
  const _JournalSheet({required this.child, this.floating = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SheetPainter(floating: floating),
      child: Padding(
        padding: EdgeInsets.fromLTRB(NatureSpace.gutter, floating ? 34 : 36, NatureSpace.gutter, floating ? 26 : 8),
        child: child,
      ),
    );
  }
}

class _TornEdgePainter extends CustomPainter {
  const _TornEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(8);
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, 6 + r.nextDouble() * 6 + math.sin(x / 41) * 2.5);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawShadow(path, NatureColors.ink, 6, false);
    canvas.drawPath(path, Paint()..color = NatureColors.background);
  }

  @override
  bool shouldRepaint(_TornEdgePainter old) => false;
}

class _SheetPainter extends CustomPainter {
  final bool floating;
  _SheetPainter({required this.floating});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(3);
    final path = Path()..moveTo(0, 14);
    // Torn top edge: small irregular fibres.
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, 8 + r.nextDouble() * 6 + math.sin(x / 37) * 2);
    }
    if (floating) {
      // Floating sheet: torn top, clean sides, gently rounded bottom.
      path
        ..lineTo(size.width, size.height - 10)
        ..quadraticBezierTo(size.width, size.height, size.width - 10, size.height)
        ..lineTo(10, size.height)
        ..quadraticBezierTo(0, size.height, 0, size.height - 10)
        ..close();
    } else {
      path
        ..lineTo(size.width, size.height + 2)
        ..lineTo(0, size.height + 2)
        ..close();
    }
    canvas.drawShadow(path, NatureColors.ink, floating ? 14 : 8, false);
    canvas.drawPath(path, Paint()..color = NatureColors.paper);
    // Fibre edge highlight and faint ruled lines near the top.
    canvas.drawPath(
      Path()..addPath(path, Offset.zero),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = NatureColors.border,
    );
    final rule = Paint()
      ..strokeWidth = 1
      ..color = NatureColors.skyTeal.withValues(alpha: 0.12);
    for (var y = 40.0; y < math.min(size.height - 8, 220); y += 28) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), rule);
    }
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.floating != floating;
}

// ---- Masthead (phone/tablet) -------------------------------------------------
class _Masthead extends StatelessWidget {
  final VoidCallback onProfile;
  const _Masthead({required this.onProfile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Wordmark(),
        const Spacer(),
        SenseTappable(
          semanticLabel: 'Profile, privacy and support contacts',
          tooltip: 'Profile, privacy and support contacts',
          circle: true,
          focusColor: NatureColors.focus,
          hoverColor: NatureColors.paleSage,
          onTap: onProfile,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.shield_outlined, color: NatureColors.ink, size: 23),
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    // Logo geometry unchanged; single-colour forest variant for this theme.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SenseLogoMark(size: 28, variant: SenseLogoVariant.mono, color: NatureColors.forest),
        const SizedBox(width: 10),
        Text('SENSE',
            style: NatureType.label.copyWith(
                fontWeight: FontWeight.w600, letterSpacing: 2.2, color: NatureColors.forest)),
      ],
    );
  }
}

// ---- Welcome -------------------------------------------------------------------
class _Welcome extends StatelessWidget {
  final DateTime date;
  const _Welcome({required this.date});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= NatureBreakpoints.desktop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE d MMMM').format(date), style: NatureType.eyebrow),
        const SizedBox(height: 6),
        Text(natureGreeting(date.hour),
            style: NatureType.greeting.copyWith(fontSize: desktop ? 34 : 28)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const Text(
            'This is a quiet place to notice how you are doing. '
            'Everything here is optional, and you can stop at any time.',
            style: NatureType.bodyMuted,
          ),
        ),
      ],
    );
  }
}

// ---- Today: a journal entry with an ochre margin rule --------------------------
class _TodayEntry extends StatelessWidget {
  final VoidCallback onAbout;
  const _TodayEntry({required this.onAbout});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: NatureColors.sunOchre, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today', style: NatureType.eyebrow),
          const SizedBox(height: 4),
          Text(PrototypeCopy.noBaselineTitle, style: NatureType.statusTitle),
          const SizedBox(height: 6),
          Text(PrototypeCopy.noBaselineDescription, style: NatureType.bodyMuted),
          const SizedBox(height: 2),
          _TextLink(label: 'About your insights', onTap: onAbout),
        ],
      ),
    );
  }
}

// ---- Primary action: a printed button with a misregistered ochre layer --------
class _PrintedAction extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrintedAction({required this.label, required this.onTap});

  @override
  State<_PrintedAction> createState() => _PrintedActionState();
}

class _PrintedActionState extends State<_PrintedAction> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // The forest "print" sits 4 px off its ochre layer; pressing settles it
    // onto the ochre (a tactile, physical press without shadows).
    final settle = _pressed ? 4.0 : (_hover ? 1.5 : 0.0);
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: 4,
            top: 4,
            right: -4,
            bottom: -4,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: NatureColors.sunOchre,
                borderRadius: BorderRadius.all(Radius.circular(NatureRadii.md)),
              ),
            ),
          ),
          AnimatedContainer(
              duration: NatureMotion.press,
              curve: NatureMotion.ease,
              transform: Matrix4.translationValues(settle, settle, 0),
              child: SenseTappable(
                semanticLabel: widget.label,
                onTap: widget.onTap,
                focusColor: NatureColors.focus,
                borderRadius: NatureRadii.mdBorder,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                onHover: (v) => setState(() => _hover = v),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: _pressed ? NatureColors.forestDeep : NatureColors.primary,
                    borderRadius: NatureRadii.mdBorder,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(widget.label,
                            style: NatureType.button.copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded,
                          color: NatureColors.primaryForeground, size: 20),
                    ],
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

// ---- Ways to reflect -------------------------------------------------------------
class _Modality {
  final IconData icon;
  final String title;
  final String detail;
  final Widget Function() screen;
  const _Modality(this.icon, this.title, this.detail, this.screen);
}

// Short, honest descriptions of what each screen does in this prototype.
final _modalities = <_Modality>[
  _Modality(Icons.wb_twilight_outlined, 'Check-in', 'Mood, energy and stress',
      () => const CheckInScreen()),
  _Modality(Icons.menu_book_outlined, 'Journal', 'Write freely · not saved yet',
      () => const JournalScreen()),
  _Modality(Icons.bedtime_outlined, 'Sleep', 'Duration, timing and rest',
      () => const SleepScreen()),
  _Modality(Icons.layers_outlined, 'Workload', 'Demand, effort and deadlines',
      () => const WorkloadScreen()),
  _Modality(Icons.mic_none_rounded, 'Voice', 'Planned · demo only, no audio recorded',
      () => const VoiceScreen()),
  _Modality(Icons.directions_walk_rounded, 'Activity', 'Manual entry · no health app connected',
      () => const ActivityScreen()),
];

class _WaysToReflect extends StatelessWidget {
  final void Function(Widget) open;
  final int columns;
  const _WaysToReflect({required this.open, this.columns = 1});

  @override
  Widget build(BuildContext context) {
    // An open, ruled index (no card panel): hairlines between entries, the
    // way a contents page is set. One column on phones, two or three on
    // wider screens.
    Widget entry(_Modality m) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, thickness: 1, color: NatureColors.divider),
            _ModalityRow(modality: m, onTap: () => open(m.screen()), first: false, last: false),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ways to reflect', style: NatureType.sectionTitle),
        const SizedBox(height: 4),
        const Text('Choose any, or none. Each one is voluntary.', style: NatureType.bodyMuted),
        const SizedBox(height: 14),
        if (columns == 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in _modalities) entry(m),
              const Divider(height: 1, thickness: 1, color: NatureColors.divider),
            ],
          )
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 40.0;
            final itemW = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              children: [
                for (final m in _modalities)
                  SizedBox(width: itemW, child: entry(m)),
              ],
            );
          }),
      ],
    );
  }
}

class _ModalityRow extends StatefulWidget {
  final _Modality modality;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  const _ModalityRow({required this.modality, required this.onTap, required this.first, required this.last});

  @override
  State<_ModalityRow> createState() => _ModalityRowState();
}

class _ModalityRowState extends State<_ModalityRow> {
  bool _active = false; // hover or press

  @override
  Widget build(BuildContext context) {
    final r = const Radius.circular(NatureRadii.md);
    final m = widget.modality;
    return SenseTappable(
      semanticLabel: '${m.title}. ${m.detail}',
      onTap: widget.onTap,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.paleSage.withValues(alpha: 0.45),
      onHover: (v) => setState(() => _active = v),
      onHighlightChanged: (v) => setState(() => _active = v),
      borderRadius: BorderRadius.vertical(
          top: widget.first ? r : Radius.zero, bottom: widget.last ? r : Radius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _PrintedIconWell(icon: m.icon, settled: _active),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: NatureType.label),
                    const SizedBox(height: 2),
                    Text(m.detail, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                offset: Offset(_active ? 0.18 : 0, 0),
                duration: NatureMotion.selection,
                curve: NatureMotion.ease,
                child: const Icon(Icons.chevron_right_rounded, color: NatureColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon in a sage well with an off-register outline ring (the risograph
/// signature). On hover/press the ring settles into register.
class _PrintedIconWell extends StatelessWidget {
  final IconData icon;
  final bool settled;
  const _PrintedIconWell({required this.icon, required this.settled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 4,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: NatureColors.paleSage, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: NatureColors.forest),
            ),
          ),
          AnimatedPositioned(
            duration: NatureMotion.selection,
            curve: NatureMotion.ease,
            left: settled ? 2 : 4,
            top: settled ? 4 : 0,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NatureColors.forest.withValues(alpha: 0.55), width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Example observation (sample data) -------------------------------------
class _ExampleObservation extends StatelessWidget {
  final VoidCallback onOpen;
  const _ExampleObservation({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      decoration: BoxDecoration(
        color: NatureColors.surfaceQuiet,
        borderRadius: NatureRadii.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SampleTag(),
          const SizedBox(height: 10),
          const Text('An example observation', style: NatureType.sectionTitle),
          const SizedBox(height: 6),
          const Text(
            'Example: recorded sleep duration and self-reported stress changed during the '
            'same period.',
            style: NatureType.body,
          ),
          const SizedBox(height: 8),
          const Text(
            'This is illustrative, not based on your data, and it does not mean one caused '
            'the other.',
            style: NatureType.bodyMuted,
          ),
          _TextLink(label: 'View example details', onTap: onOpen),
        ],
      ),
    );
  }
}

class _SampleTag extends StatelessWidget {
  const _SampleTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NatureColors.paper,
        borderRadius: NatureRadii.smBorder,
        border: Border.all(color: NatureColors.borderStrong),
      ),
      child: Text(PrototypeCopy.sampleDataLabel,
          style: NatureType.eyebrow.copyWith(color: NatureColors.ink, fontSize: 12)),
    );
  }
}

// ---- Support ------------------------------------------------------------------
class _SupportLine extends StatelessWidget {
  final VoidCallback onTap;
  const _SupportLine({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: NatureColors.divider),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: ExcludeSemantics(
                child: Icon(Icons.favorite_border_rounded, size: 18, color: NatureColors.coralInk),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TextLink(
                label: 'Need to talk to someone now? Support contacts are in Profile.',
                onTap: onTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SenseTappable(
      semanticLabel: label,
      onTap: onTap,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.paleSage.withValues(alpha: 0.5),
      borderRadius: NatureRadii.smBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(label, style: NatureType.link),
        ),
      ),
    );
  }
}

// ---- Navigation -------------------------------------------------------------------
/// The check-in action: forest disc with an off-register ochre ring.
class _CheckInDisc extends StatelessWidget {
  const _CheckInDisc();
  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Positioned(
            left: 3,
            top: 3,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NatureColors.sunOchre, width: 2.5),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: NatureColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: NatureColors.primaryForeground, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Phone/tablet bottom bar: paper surface, hairline top border, a forest
/// indicator above the active item (not colour alone).
class NatureBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCheckIn;

  const NatureBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: NatureColors.surface,
          border: Border(top: BorderSide(color: NatureColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 66, maxWidth: NatureBreakpoints.maxReading),
              child: Row(
                children: [
                  _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  _navItem(1, Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: SenseTappable(
                        semanticLabel: 'New daily check-in',
                        tooltip: 'New daily check-in',
                        circle: true,
                        focusColor: NatureColors.focus,
                        onTap: onCheckIn,
                        child: const _CheckInDisc(),
                      ),
                    ),
                  ),
                  _navItem(2, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final active = index == currentIndex;
    final color = active ? NatureColors.forest : NatureColors.inkMuted;
    return Expanded(
      child: SenseTappable(
        semanticLabel: '$label tab',
        selected: active,
        focusColor: NatureColors.focus,
        hoverColor: NatureColors.paleSage.withValues(alpha: 0.5),
        borderRadius: NatureRadii.mdBorder,
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: NatureMotion.selection,
                curve: NatureMotion.ease,
                width: active ? 22 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: NatureColors.forest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(active ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: NatureType.label.copyWith(
                    fontSize: 12,
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop header: wordmark, text tabs with an underline indicator, and the
/// check-in action as a labelled button.
class NatureTopBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCheckIn;

  /// On Home the bar takes the sky colour so it reads as part of the scene.
  final bool overSky;

  const NatureTopBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCheckIn,
    this.overSky = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: overSky ? NatureColors.skyHigh : NatureColors.background,
        border: overSky ? null : const Border(bottom: BorderSide(color: NatureColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NatureBreakpoints.maxContent + 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Row(
                children: [
                  const _Wordmark(),
                  const Spacer(),
                  for (final (i, label) in const ['Home', 'Insights', 'Profile'].indexed)
                    _tab(i, label),
                  const SizedBox(width: 24),
                  SenseTappable(
                    semanticLabel: 'New daily check-in',
                    tooltip: 'New daily check-in',
                    focusColor: NatureColors.focus,
                    borderRadius: NatureRadii.mdBorder,
                    onTap: onCheckIn,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: NatureColors.primary,
                        borderRadius: NatureRadii.mdBorder,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: NatureColors.primaryForeground, size: 20),
                          const SizedBox(width: 8),
                          Text('New check-in',
                              style: NatureType.button.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, String label) {
    final active = index == currentIndex;
    return SenseTappable(
      semanticLabel: '$label tab',
      selected: active,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.paleSage.withValues(alpha: 0.5),
      borderRadius: NatureRadii.smBorder,
      onTap: () => onTap(index),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: NatureType.label.copyWith(
                    color: active ? NatureColors.forest : NatureColors.inkMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  )),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: NatureMotion.selection,
                curve: NatureMotion.ease,
                width: active ? 24 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: NatureColors.forest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
