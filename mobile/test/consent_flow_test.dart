import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/dashboard_screen.dart';
import 'package:mindpulse/presentation/screens/onboarding_screen.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';

/// Consent-flow navigation tests (Task 2): Onboarding → Consent → Dashboard,
/// and Settings → Consent. Preferences are in-memory only.
void main() {
  final prefs = ConsentPreferences.instance;

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    // Phone-sized viewport (Pixel-like 412 x 915 logical px).
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The production Home landscape animates continuously, so pumpAndSettle can
    // only settle with reduced motion. Motion is covered by its own tests.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  Future<void> finishOnboarding(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
  }

  setUp(prefs.reset);

  testWidgets('Completing onboarding opens consent, not the dashboard', (tester) async {
    await pumpApp(tester, const OnboardingScreen());
    await finishOnboarding(tester);
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('Skip also opens consent (no route bypasses it)', (tester) async {
    await pumpApp(tester, const OnboardingScreen());
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('Back from consent returns to the last onboarding slide', (tester) async {
    await pumpApp(tester, const OnboardingScreen());
    await finishOnboarding(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.text('Get Started'), findsOneWidget); // still on slide 3
  });

  testWidgets('Consent lists all six inputs, all off by default', (tester) async {
    await pumpApp(tester, const ConsentScreen());
    for (final m in InputModality.values) {
      final title = find.text('${m.code} · ${m.title}');
      await scrollTo(tester, title);
      expect(title, findsOneWidget);
      expect(prefs.isEnabled(m), isFalse);
    }
    expect(prefs.enabledCount, 0);
  });

  testWidgets('Each preference toggles independently (mixed selection)', (tester) async {
    await pumpApp(tester, const ConsentScreen());
    final journal = find.text('M2 · Journal');
    await scrollTo(tester, journal);
    await tester.tap(journal);
    await tester.pumpAndSettle();
    final voice = find.text('M5 · Voice');
    await scrollTo(tester, voice);
    await tester.tap(voice);
    await tester.pumpAndSettle();

    expect(prefs.isEnabled(InputModality.journal), isTrue);
    expect(prefs.isEnabled(InputModality.voice), isTrue);
    for (final m in [
      InputModality.checkIn,
      InputModality.sleep,
      InputModality.workload,
      InputModality.activity,
    ]) {
      expect(prefs.isEnabled(m), isFalse, reason: '$m should be unaffected');
    }

    await tester.tap(voice); // turn back off
    await tester.pumpAndSettle();
    expect(prefs.isEnabled(InputModality.voice), isFalse);
    expect(prefs.enabledCount, 1);
  });

  testWidgets('Continue with everything off opens the dashboard as the only route',
      (tester) async {
    await pumpApp(tester, const OnboardingScreen());
    await finishOnboarding(tester);
    final cont = find.text('Continue to SENSE');
    await scrollTo(tester, cont);
    await tester.tap(cont);
    await tester.pumpAndSettle();

    expect(prefs.enabledCount, 0);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    expect(nav.canPop(), isFalse, reason: 'Back must not return into onboarding/consent');
  });

  testWidgets('Continue with everything on also opens the dashboard',
      (tester) async {
    for (final m in InputModality.values) {
      prefs.setEnabled(m, true);
    }
    await pumpApp(tester, const ConsentScreen());
    final cont = find.text('Continue to SENSE');
    await scrollTo(tester, cont);
    await tester.tap(cont);
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('Settings opens the same consent screen and returns with choices shown',
      (tester) async {
    await pumpApp(tester, const SettingsScreen());
    final entry = find.text('Review data and consent preferences');
    await scrollTo(tester, entry);
    expect(find.text('Currently on: none (not saved)'), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    final sleep = find.text('M3 · Sleep');
    await scrollTo(tester, sleep);
    await tester.tap(sleep);
    await tester.pumpAndSettle();
    final done = find.text('Done');
    await scrollTo(tester, done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Currently on: M3 Sleep (not saved)'), findsOneWidget);
  });

  testWidgets('Consent screen states the prototype limitations honestly', (tester) async {
    await pumpApp(tester, const ConsentScreen());
    expect(find.textContaining('kept only while the app is open'), findsWidgets);
    expect(find.textContaining('not a substitute for an approved research-participant consent'),
        findsOneWidget);
    expect(find.textContaining('no phone or browser permission is requested'), findsOneWidget);
  });
}
