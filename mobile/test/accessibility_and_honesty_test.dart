import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/dashboard_screen.dart';
import 'package:mindpulse/presentation/screens/insights_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_chips.dart';
import 'package:mindpulse/presentation/widgets/sense_inputs.dart';

/// Task 5 polish: WCAG contrast of the colour tokens actually used for text,
/// interactive semantics, the removed dashboard filter chips, weekday labels,
/// and regression guards for honest Save / Export / Erase messages.
void main() {
  // ---- helpers --------------------------------------------------------------
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  Future<void> pump(WidgetTester t, Widget w, {double width = 412, double scale = 1.0}) async {
    t.view.physicalSize = Size(width * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    // The production Home landscape animates continuously, so pumpAndSettle can
    // only settle with reduced motion. Motion is covered by its own tests.
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: w));
    await t.pumpAndSettle();
  }

  Finder vertical() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down);

  Future<void> tapVisible(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 250, scrollable: vertical().first);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  /// Any on-screen wording that would claim a privacy/storage operation
  /// succeeded. Must never appear while persistence is not implemented.
  final misleading = RegExp(
    r'(saved to|saved locally|successfully|encrypted|has been (saved|deleted|erased|exported)'
    r'|exported (structured|your|personal)|permanently erased|records have been)',
    caseSensitive: false,
  );
  Finder misleadingText() => find.byWidgetPredicate((w) {
        final text = w is Text ? (w.data ?? w.textSpan?.toPlainText() ?? '') : '';
        return misleading.hasMatch(text);
      });

  // ---- A. Contrast ----------------------------------------------------------
  group('Colour contrast (WCAG 2.2 AA)', () {
    const bg = SenseColors.background, white = SenseColors.white, surface = SenseColors.surface;

    test('body, secondary and muted text reach 4.5:1 on all light surfaces', () {
      for (final fg in [SenseColors.textPrimary, SenseColors.textSecondary, SenseColors.textMuted]) {
        for (final b in [white, bg, surface]) {
          expect(contrast(fg, b), greaterThanOrEqualTo(4.5), reason: '$fg on $b');
        }
      }
    });

    test('accent text (links, active nav labels) reaches 4.5:1', () {
      for (final b in [white, bg, surface]) {
        expect(contrast(SenseColors.textAccent, b), greaterThanOrEqualTo(4.5));
      }
    });

    test('white button labels reach 4.5:1 across the whole primary button gradient', () {
      for (final c in SenseColors.primaryButtonGradient.colors) {
        expect(contrast(white, c), greaterThanOrEqualTo(4.5), reason: 'white on $c');
      }
    });

    test('Electric Blue is reserved for non-text use (>= 3:1) and is NOT text-safe', () {
      expect(contrast(SenseColors.blue600, white), greaterThanOrEqualTo(3.0));
      // Guard: if someone reuses it as small text, this documents why not.
      expect(contrast(SenseColors.blue600, white), lessThan(4.5));
    });

    test('status and hero-card text pairings reach 4.5:1', () {
      expect(contrast(SenseColors.warning, white), greaterThanOrEqualTo(4.5));
      expect(contrast(SenseColors.danger, const Color(0xFFFEF2F2)), greaterThanOrEqualTo(4.5));
      expect(contrast(white, SenseColors.navy900), greaterThanOrEqualTo(4.5));
      // Hero card labels sit on the Ocean Blue -> Navy gradient.
      for (final label in const [Color(0xFFB0D9F7), Color(0xFFC7E4F9)]) {
        expect(contrast(label, SenseColors.blue800), greaterThanOrEqualTo(4.5));
      }
    });

    test('toggle states are distinguishable from a white card (>= 3:1)', () {
      expect(contrast(SenseColors.blue600, white), greaterThanOrEqualTo(3.0)); // on track
      expect(contrast(SenseColors.textMuted, white), greaterThanOrEqualTo(3.0)); // off outline/thumb
    });
  });

  // ---- B. Semantics -----------------------------------------------------------
  group('Interactive semantics', () {
    testWidgets('Home insight link and example observation link are buttons', (t) async {
      final h = t.ensureSemantics();
      await pump(t, DashboardScreen(onOpenInsights: () {}, onOpenProfile: () {}));
      // Phase 1: the status is plain text ("No pattern yet"); its action is the
      // "About your insights" link. The sample card's action is its link.
      expect(find.text('No pattern yet'), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('About your insights')),
          isSemantics(isButton: true, hasTapAction: true));
      await t.scrollUntilVisible(find.text('View example details'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(t.getSemantics(find.bySemanticsLabel('View example details')),
          isSemantics(isButton: true, hasTapAction: true));
      h.dispose();
    });

    testWidgets('Insights period selector exposes the current selection', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const InsightsScreen());
      expect(t.getSemantics(find.bySemanticsLabel('Week view')),
          isSemantics(isButton: true, isSelected: true));
      expect(t.getSemantics(find.bySemanticsLabel('Day view')),
          isSemantics(isButton: true, isSelected: false));
      await t.tap(find.bySemanticsLabel('Day view'));
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Day view')), isSemantics(isSelected: true));
      h.dispose();
    });

    testWidgets('SenseFilterChip exposes button role and selected state', (t) async {
      final h = t.ensureSemantics();
      await pump(t, Scaffold(
        body: Row(children: [
          SenseFilterChip(label: 'Alpha', isSelected: true, onTap: () {}),
          SenseFilterChip(label: 'Beta', isSelected: false, onTap: () {}),
        ]),
      ));
      expect(t.getSemantics(find.bySemanticsLabel('Alpha')),
          isSemantics(isButton: true, isSelected: true));
      expect(t.getSemantics(find.bySemanticsLabel('Beta')),
          isSemantics(isButton: true, isSelected: false));
      h.dispose();
    });

    testWidgets('SenseToggleSwitch exposes switch state and toggles from its row', (t) async {
      final h = t.ensureSemantics();
      var value = false;
      await pump(t, Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SenseToggleSwitch(
            label: 'Example setting',
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ));
      expect(t.getSemantics(find.bySemanticsLabel('Example setting')),
          isSemantics(hasToggledState: true, isToggled: false));
      await t.tap(find.text('Example setting')); // whole row is the target
      await t.pumpAndSettle();
      expect(value, isTrue);
      expect(t.getSemantics(find.bySemanticsLabel('Example setting')),
          isSemantics(hasToggledState: true, isToggled: true));
      h.dispose();
    });
  });

  // ---- C. Filter chips --------------------------------------------------------
  testWidgets('Dashboard no longer shows non-functional filter chips', (t) async {
    await pump(t, DashboardScreen(onOpenInsights: () {}, onOpenProfile: () {}));
    expect(find.byType(SenseFilterChip), findsNothing);
  });

  // ---- D. Weekday labels ------------------------------------------------------
  group('Insights weekday labels', () {
    // Note: the flutter_test font is much wider than Roboto, so "roomy" here
    // means a wide viewport; the 412 px case is verified in Chrome.
    testWidgets('roomy: three-letter labels', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const InsightsScreen(), width: 600, scale: 1.0);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, sample bar'), findsOneWidget);
      h.dispose();
    });

    testWidgets('320 px at 2x: single letters at full size, full names announced',
        (t) async {
      final h = t.ensureSemantics();
      await pump(t, const InsightsScreen(), width: 320, scale: 2.0);
      await t.scrollUntilVisible(find.bySemanticsLabel('Wednesday, sample bar'), 250,
          scrollable: vertical().first);
      expect(find.text('Wed'), findsNothing);
      expect(find.text('W'), findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, sample bar'), findsOneWidget);
      // Not shrunk: no FittedBox scaling the day labels any more.
      final wText = t.widget<Text>(find.text('W'));
      expect(find.ancestor(of: find.byWidget(wText), matching: find.byType(FittedBox)),
          findsNothing);
      h.dispose();
    });
  });

  // ---- E. Honest prototype messages (interaction outcomes) -------------------
  group('Honest Save / Export / Erase outcomes', () {
    testWidgets('Journal: Save says not saved; no success claim', (t) async {
      await pump(t, const JournalScreen());
      await t.enterText(find.byType(TextField), 'An example sentence.');
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Save Reflection'));
      expect(find.text(PrototypeCopy.notSaved('journal entry')), findsOneWidget);
      expect(misleadingText(), findsNothing);
    });

    testWidgets('Check-in: completion screen says not saved; no success claim', (t) async {
      await pump(t, const CheckInScreen());
      await tapVisible(t, find.text('Continue to stress rating'));
      await tapVisible(t, find.text('Finish check-in'));
      expect(find.text('Check-in complete, not saved'), findsOneWidget);
      expect(find.textContaining('your answers are not saved'), findsOneWidget);
      expect(misleadingText(), findsNothing);
    });

    for (final c in [
      (name: 'Sleep', screen: const SleepScreen(), button: 'Save Sleep Record', what: 'sleep entry'),
      (name: 'Workload', screen: const WorkloadScreen(), button: 'Save Workload Rating', what: 'workload rating'),
      (name: 'Activity', screen: const ActivityScreen(), button: 'Save Activity Entry', what: 'activity entry'),
    ]) {
      testWidgets('${c.name}: Save says not saved; no success claim', (t) async {
        await pump(t, c.screen);
        await tapVisible(t, find.text(c.button));
        expect(find.text(PrototypeCopy.notSaved(c.what)), findsOneWidget);
        expect(misleadingText(), findsNothing);
      });
    }

    testWidgets('Export and Erase explain they are unavailable; no success claim', (t) async {
      await pump(t, const SettingsScreen());
      await tapVisible(t, find.text('Export my data'));
      expect(find.text(PrototypeCopy.exportUnavailable), findsOneWidget);
      expect(misleadingText(), findsNothing);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      await tapVisible(t, find.text('Erase my data'));
      expect(find.text(PrototypeCopy.eraseUnavailable), findsOneWidget);
      expect(misleadingText(), findsNothing);
    });

    test('the misleading-claim detector actually catches the old messages', () {
      // Guards the guard: these are the exact pre-Task-1 success messages.
      for (final old in [
        'Journal entry saved locally to encrypted SQLite database.',
        'Exported structured user data JSON fulfilling DPDP Section 12.',
        'All personal records have been permanently erased.',
      ]) {
        expect(misleading.hasMatch(old), isTrue, reason: old);
      }
      // And the honest wording does not trip it.
      for (final ok in [
        PrototypeCopy.notSaved('journal entry'),
        PrototypeCopy.exportUnavailable,
        PrototypeCopy.eraseUnavailable,
      ]) {
        expect(misleading.hasMatch(ok), isFalse, reason: ok);
      }
    });
  });
}
