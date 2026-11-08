import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/insight_detail_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/voice_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';

/// Task 4: large-text / narrow-width layout matrix for the six input and
/// detail screens (3 widths x 4 text scales x 6 screens = 72 renders), plus
/// Check-in step 1 (12) and two content-heavy state variants (24).
///
/// Overflow errors are NOT ignored: flutter_test fails any test that ends with
/// an uncaught layout error (and prints where it happened).
/// The flutter_test font draws each glyph as a wide square, so this is a
/// stricter check than real fonts; Chrome is checked separately.
void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen,
      {required double width, required double scale}) async {
    tester.view.physicalSize = Size(width * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    await tester.pumpAndSettle();
  }

  /// Scrolls the screen's main vertical list from top to bottom.
  Future<void> scrollThrough(WidgetTester tester) async {
    final vertical = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    if (vertical.evaluate().isEmpty) return;
    for (var i = 0; i < 60; i++) {
      final p = tester.state<ScrollableState>(vertical.first).position;
      if (p.pixels >= p.maxScrollExtent - 0.5) break;
      await tester.drag(vertical.first, const Offset(0, -500), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    final pos = tester.state<ScrollableState>(vertical.first).position;
    expect(pos.pixels, closeTo(pos.maxScrollExtent, 1.0),
        reason: 'scrollThrough should reach the end of the vertical content');
  }

  final screens = <String, Widget Function()>{
    'Journal': () => const JournalScreen(),
    'Sleep': () => const SleepScreen(),
    'Workload': () => const WorkloadScreen(),
    'Activity': () => const ActivityScreen(),
    'Voice': () => const VoiceScreen(),
    'Insight detail': () => const InsightDetailScreen(),
    // Not in the original six, but found clipping in Chrome at 320 px / 2x.
    'Check-in (step 1)': () => const CheckInScreen(),
  };

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      final cfg = '${width.toInt()} px, text ${scale}x';

      for (final entry in screens.entries) {
        testWidgets('${entry.key} fits at $cfg', (tester) async {
          await pumpScreen(tester, entry.value(), width: width, scale: scale);
          await scrollThrough(tester);
        });
      }

      testWidgets('Journal with a long entry and the crisis banner fits at $cfg',
          (tester) async {
        await pumpScreen(tester, const JournalScreen(), width: width, scale: scale);
        await tester.enterText(
          find.byType(TextField),
          'A long week with several deadlines and late nights. ' * 6 +
              'Sometimes I want to die.',
        );
        await tester.pumpAndSettle();
        // Safety behaviour preserved: the support banner appears.
        expect(find.text('Support is Available 24/7'), findsOneWidget);
        await scrollThrough(tester);
      });

      // Phase 4: the simulated recording demo was removed (it looked like a
      // working recorder). Voice now states that it is not available.
      testWidgets('Voice (not-available state, no recording control) fits at $cfg', (tester) async {
        await pumpScreen(tester, const VoiceScreen(), width: width, scale: scale);
        expect(find.text('Not available in this prototype'), findsOneWidget);
        expect(find.byIcon(Icons.mic_rounded), findsNothing);
        await scrollThrough(tester);
      });
    }
  }

  group('Screen-reader labels for icon-only and custom controls', () {
    Future<void> pump(WidgetTester tester, Widget w) =>
        pumpScreen(tester, w, width: 412, scale: 1.0);

    testWidgets('Shared app-bar back button has an accessible label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SleepScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(SleepScreen), findsNothing);
    });

    testWidgets('Workload deadline stepper buttons are labelled', (tester) async {
      await pump(tester, const WorkloadScreen());
      expect(find.byTooltip('One fewer deadline'), findsOneWidget);
      expect(find.byTooltip('One more deadline'), findsOneWidget);
    });

    testWidgets('Voice says no audio is recorded and offers no recording control', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const VoiceScreen());
      expect(
        find.bySemanticsLabel(RegExp(r'^Planned · not built\. Not available in this prototype\. '
            r'There is no recording control\.')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('(Start|Stop) demo')), findsNothing);
      handle.dispose();
    });

    testWidgets('Sleep stars and time pickers are announced with their values',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SleepScreen());
      expect(find.bySemanticsLabel('Rest quality 4 of 5'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Rest quality 4 of 5')),
          isSemantics(isSelected: true, isButton: true));
      expect(find.bySemanticsLabel(RegExp(r'^Bedtime: .*Tap to change')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Wake time: .*Tap to change')), findsOneWidget);
      handle.dispose();
    });

    // Phase 4: the always-off switch was replaced by an explicit status, so
    // nothing on the page looks like it could connect Health Connect.
    testWidgets('Health Connect is announced as not connected, with no switch to operate',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const ActivityScreen());
      expect(
          find.bySemanticsLabel('Health Connect: Not connected · not available in this prototype'),
          findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      handle.dispose();
    });
  });
}
