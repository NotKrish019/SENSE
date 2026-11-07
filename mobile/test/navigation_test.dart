import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/dashboard_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/widgets/sense_navigation.dart';

/// Task 3: bottom navigation, Profile destination, Back behaviour, and
/// large-text / narrow-viewport layouts. Overflow errors are NOT ignored:
/// any RenderFlex overflow fails the test.
void main() {
  setUp(ConsentPreferences.instance.reset);

  Future<void> pumpShell(
    WidgetTester tester, {
    double width = 412,
    double height = 915,
    double textScale = 1.0,
    Widget home = const MainShell(),
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  Finder tab(String label) => find.bySemanticsLabel('$label tab');

  /// A bottom-navigation item (scoped to the bar: screens may reuse the words).
  Finder nav(String label) =>
      find.descendant(of: find.byType(SenseBottomNavBar), matching: find.text(label));

  NavigatorState rootNav(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  testWidgets('Home is shown first and the Tools tab no longer exists', (tester) async {
    await pumpShell(tester);
    expect(find.text('Daily Well-being Overview'), findsOneWidget);
    expect(find.text('Tools'), findsNothing);
    expect(nav('Home'), findsOneWidget);
    expect(nav('Insights'), findsOneWidget);
    expect(nav('Profile'), findsOneWidget);
  });

  testWidgets('Insights and Profile tabs switch destinations without pushing routes',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(nav('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Longitudinal Insights'), findsOneWidget);
    expect(rootNav(tester).canPop(), isFalse);

    await tester.tap(nav('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Longitudinal Insights'), findsNothing);
    expect(rootNav(tester).canPop(), isFalse);

    await tester.tap(nav('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Well-being Overview'), findsOneWidget);
  });

  testWidgets('Repeated tab taps keep exactly one dashboard and no extra routes',
      (tester) async {
    await pumpShell(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(nav('Home'));
      await tester.tap(nav('Insights'));
      await tester.tap(nav('Insights'));
      await tester.tap(nav('Profile'));
      await tester.pumpAndSettle();
    }
    expect(find.byType(DashboardScreen, skipOffstage: false), findsOneWidget);
    expect(rootNav(tester).canPop(), isFalse);
  });

  testWidgets('Active tab is exposed as selected (not colour alone)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpShell(tester);
    expect(tester.getSemantics(tab('Home')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(tab('Insights')), isSemantics(isSelected: false));

    await tester.tap(nav('Insights'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(tab('Insights')), isSemantics(isSelected: true));
    expect(tester.getSemantics(tab('Home')), isSemantics(isSelected: false));
    expect(find.bySemanticsLabel('New daily check-in'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Centre action opens the existing check-in; Back returns to the tab',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(nav('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New daily check-in'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckInScreen), findsOneWidget);

    // Check-in uses its own back arrow (not the default back button).
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byType(CheckInScreen), findsNothing);
    expect(find.text('Profile & settings'), findsOneWidget);
  });

  testWidgets('Dashboard hero card and shield icon switch tabs (no duplicates)',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('No pattern yet'));
    await tester.pumpAndSettle();
    expect(find.text('Longitudinal Insights'), findsOneWidget);
    expect(tester.getSemantics(tab('Insights')), isSemantics(isSelected: true));
    expect(rootNav(tester).canPop(), isFalse);

    await tester.tap(nav('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile, privacy & support contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(rootNav(tester).canPop(), isFalse);
  });

  testWidgets('System Back on a non-Home tab returns to Home', (tester) async {
    await pumpShell(tester);
    await tester.tap(nav('Insights'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Daily Well-being Overview'), findsOneWidget);
    expect(find.text('Longitudinal Insights'), findsNothing);
  });

  testWidgets('Profile → review consent → Done returns to Profile with shared choices',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(nav('Profile'));
    await tester.pumpAndSettle();
    final entry = find.text('Review data and consent preferences');
    await tester.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('Currently on: none (not saved)'), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    await tester.tap(find.text('M1 · Structured check-ins'));
    await tester.pumpAndSettle();
    final done = find.text('Done');
    await tester.scrollUntilVisible(done, 250,
        scrollable: find.descendant(
            of: find.byType(ConsentScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Currently on: M1 Structured check-ins (not saved)'), findsOneWidget);
  });

  testWidgets('Profile shows an honest placeholder, not invented account data',
      (tester) async {
    await pumpShell(tester, home: const MainShell(initialIndex: MainTab.profile));
    expect(find.text('Profile setup is not available yet'), findsOneWidget);
    expect(find.textContaining('usr_'), findsNothing);
    expect(find.textContaining('Calibrated'), findsNothing);
  });

  // ---- Large text and narrow viewports ------------------------------------
  // The flutter_test font draws every glyph as a wide square, so passing here
  // is a stricter check than Chrome with real fonts.
  // Scrolls the on-screen VERTICAL list (not, e.g., a horizontal chip row),
  // and checks that it really reached the end.
  Future<void> scrollThrough(WidgetTester tester) async {
    final vertical = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    if (vertical.evaluate().isEmpty) return;
    // Lazy lists grow their extent while scrolling, so keep going until the
    // end is reached (bounded to avoid an endless loop).
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

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('No overflow at ${width.toInt()} px, text ${scale}x: Home, Insights, Profile',
          (tester) async {
        await pumpShell(tester, width: width, height: 780, textScale: scale);
        await scrollThrough(tester); // Home
        await tester.tap(nav('Insights'));
        await tester.pumpAndSettle();
        await scrollThrough(tester);
        await tester.tap(nav('Profile'));
        await tester.pumpAndSettle();
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('No overflow at ${width.toInt()} px, text ${scale}x: Consent', (tester) async {
        await pumpShell(tester, width: width, height: 780, textScale: scale,
            home: const ConsentScreen());
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
