import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/main.dart';
import 'package:mindpulse/presentation/nature/arrival_art.dart';
import 'package:mindpulse/presentation/nature/nature_widgets.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/onboarding_screen.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';
import 'package:mindpulse/presentation/screens/splash_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_logo.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Phase 5: production Splash, Onboarding and Consent in the Living
/// Landscapes design. Flow, timing, consent identifiers, defaults, state and
/// completion behaviour are unchanged.
void main() {
  final prefs = ConsentPreferences.instance;
  setUp(prefs.reset);

  Future<void> loadPoppins() async {
    final loader = FontLoader('Poppins');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/poppins/Poppins-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  void view(WidgetTester t, {double width = 412, double height = 915, double scale = 1.0, bool reduce = true}) {
    t.view.physicalSize = Size(width * 3, height * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<void> pump(WidgetTester t, Widget home,
      {double width = 412, double height = 915, double scale = 1.0, bool reduce = true}) async {
    view(t, width: width, height: height, scale: scale, reduce: reduce);
    await t.pumpWidget(const SizedBox()); // a fresh app (and Navigator) each time
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await t.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  String allText(WidgetTester t) => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '')
      .join('\n');

  void expectHonest(String all) {
    expect(all, isNot(contains('—')), reason: 'em dash in user-facing text');
    for (final bad in [
      'loading',
      'initialis',
      'connecting',
      'successfully',
      'saved securely',
      'stored securely',
      'encrypted',
      'anonymi',
      'diagnoses your',
      'detects stress',
      'predict',
      'risk score',
      'is recording',
      'synced',
    ]) {
      expect(all.toLowerCase(), isNot(contains(bad)), reason: bad);
    }
  }

  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<SenseTappable>()
      ?.semanticLabel;

  SemanticsData sem(WidgetTester t, Pattern label) => t.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();

  // ---- Splash ------------------------------------------------------------------------
  group('Production Splash', () {
    testWidgets('Forest mark, name, tagline and horizon; no loading claims', (t) async {
      view(t);
      await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()));
      await t.pump();
      expect(t.widget<SenseLogoMark>(find.byType(SenseLogoMark)).variant, SenseLogoVariant.forestBadge);
      expect(find.text('SENSE'), findsOneWidget);
      expect(find.text('Personal Well-being & Stress-Pattern Monitoring'), findsOneWidget);
      expect(find.text('Non-clinical research prototype'), findsOneWidget);
      expect(find.byType(SplashHorizon), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expectHonest(allText(t));
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();
    });

    testWidgets('Timing unchanged: 1.8 s, then onboarding replaces the splash', (t) async {
      view(t);
      await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()));
      expect(SplashScreen.duration, const Duration(milliseconds: 1800));
      await t.pump(const Duration(milliseconds: 1790));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      await t.pump(const Duration(milliseconds: 20));
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(t.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse, reason: 'replaced, not pushed');
    });

    testWidgets('Motion: a short fade-in; none with reduced motion', (t) async {
      double opacity() => t.renderObject<RenderAnimatedOpacity>(find.byType(AnimatedOpacity)).opacity.value;
      view(t, reduce: false);
      await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(opacity(), inExclusiveRange(0.0, 1.0));
      await t.pump(const Duration(milliseconds: 600));
      expect(opacity(), 1.0);
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();

      view(t, reduce: true);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()));
      expect(opacity(), 1.0, reason: 'fully visible on the first frame');
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();
    });
  });

  // ---- Whole flow ----------------------------------------------------------------------
  group('First launch and every later launch', () {
    Future<void> throughOnboarding(WidgetTester t) async {
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tapVisible(t, find.text('Continue'));
      await tapVisible(t, find.text('Continue'));
      await tapVisible(t, find.text('Get Started'));
      expect(find.byType(ConsentScreen), findsOneWidget);
    }

    testWidgets('Splash → Onboarding → Consent → Home, from the real app entry point', (t) async {
      view(t);
      await t.pumpWidget(const SenseApp());
      expect(find.byType(SplashScreen), findsOneWidget);
      await throughOnboarding(t);
      await tapVisible(t, find.text('M3 · Sleep'));
      expect(prefs.isEnabled(InputModality.sleep), isTrue);
      await tapVisible(t, find.text('Continue to SENSE'));
      expect(find.byType(MainShell), findsOneWidget);
      expect(t.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    });

    testWidgets('There is no returning-user shortcut: a new launch starts at Splash again, and '
        'preferences reset (in memory only)', (t) async {
      view(t);
      prefs.setEnabled(InputModality.journal, true);
      // A reload starts a fresh app; the in-memory preferences are recreated (all off).
      prefs.reset();
      await t.pumpWidget(const SenseApp());
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      await throughOnboarding(t);
      for (final m in InputModality.values) {
        expect(prefs.isEnabled(m), isFalse);
      }
      expect(find.text('0 of 6 inputs turned on (kept only while the app is open).'), findsOneWidget);
    });
  });

  // ---- Onboarding --------------------------------------------------------------------
  group('Production Onboarding', () {
    testWidgets('Three steps in the original order with their original meaning', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const OnboardingScreen());
      final steps = OnboardingScreen.steps;
      expect(steps.map((s) => s.badge), [
        'Research goal: personal baselines',
        'Optional multi-modality',
        'Non-clinical research prototype',
      ]);
      expect(steps[0].body, contains('Personal baselines are not calculated yet in this prototype.'));
      expect(steps[1].body,
          'Every input is optional and separate. Skipping an input will never be treated as a sign of stress.');
      expect(steps[2].body, contains('not medical diagnoses'));
      expect(steps[2].body, contains('does not save or share anything you enter'));
      for (var i = 0; i < 3; i++) {
        expect(find.text(steps[i].title), findsOneWidget);
        expect(find.bySemanticsLabel('Step ${i + 1} of 3: ${steps[i].title}'), findsOneWidget);
        expect(find.text('Step ${i + 1} of 3'), findsOneWidget);
        expect(find.byType(OnboardingMotif), findsOneWidget);
        expectHonest(allText(t));
        if (i < 2) await tapVisible(t, find.text('Continue'));
      }
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      h.dispose();
    });

    testWidgets('Each step separates "In this prototype" from "Planned"', (t) async {
      await pump(t, const OnboardingScreen());
      for (var i = 0; i < 3; i++) {
        final s = OnboardingScreen.steps[i];
        expect(find.text('In this prototype: ${s.now}', findRichText: true), findsOneWidget);
        expect(find.text('Planned: ${s.planned}', findRichText: true), findsOneWidget);
        if (i < 2) await tapVisible(t, find.text('Continue'));
      }
      expect(OnboardingScreen.steps[1].planned, contains('Voice'));
      expect(OnboardingScreen.steps[1].now, isNot(contains('Voice')));
    });

    testWidgets('Back returns to the previous step; there is no Back on the first step', (t) async {
      await pump(t, const OnboardingScreen());
      expect(find.text('Back'), findsNothing);
      await tapVisible(t, find.text('Continue'));
      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tapVisible(t, find.text('Back'));
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('Skip and Get Started both open consent on top; Back from consent returns to the step',
        (t) async {
      await pump(t, const OnboardingScreen());
      await tapVisible(t, find.text('Continue'));
      await tapVisible(t, find.text('Skip'));
      expect(find.byType(ConsentScreen), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tapVisible(t, find.text('Continue'));
      await tapVisible(t, find.text('Get Started'));
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(t.widget<ConsentScreen>(find.byType(ConsentScreen)).isSettingsMode, isFalse);
    });

    testWidgets('Keyboard: Skip, then Continue; Enter advances; Back appears after step 1', (t) async {
      await pump(t, const OnboardingScreen());
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Skip');
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Continue');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Reduced motion: steps change without the slide animation', (t) async {
      double page() => t.widget<PageView>(find.byType(PageView)).controller!.page!;
      await pump(t, const OnboardingScreen(), reduce: true);
      await t.tap(find.text('Continue'));
      await t.pump();
      expect(page(), 1.0, reason: 'jumps straight to step 2');
      expect(find.text('Step 2 of 3'), findsOneWidget);

      await pump(t, const OnboardingScreen(), reduce: false);
      await t.tap(find.text('Continue'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(page(), inExclusiveRange(0.0, 1.0), reason: 'slides with normal motion');
      await t.pumpAndSettle();
      expect(page(), 1.0);
    });
  });

  // ---- Consent -----------------------------------------------------------------------
  group('Production Consent', () {
    const status = {
      InputModality.checkIn: 'Available to try · not saved',
      InputModality.journal: 'Available to try · not saved',
      InputModality.sleep: 'Available to try · not saved',
      InputModality.workload: 'Available to try · not saved',
      InputModality.voice: 'Planned · not built',
      InputModality.activity: 'Manual entry only · sync planned',
    };

    testWidgets('Six choices M1 to M6, in order, all off by default, with their status in words', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ConsentScreen(), height: 4000);
      expect(find.byType(GateBand), findsOneWidget);
      expect(InputModality.values.map((m) => m.code), ['M1', 'M2', 'M3', 'M4', 'M5', 'M6']);
      var lastY = -1.0;
      for (final m in InputModality.values) {
        final title = '${m.code} · ${m.title}';
        final y = t.getTopLeft(find.text(title)).dy;
        expect(y, greaterThan(lastY));
        lastY = y;
        final d = sem(t, '$title. ${status[m]}');
        expect(d.flagsCollection.isToggled, Tristate.isFalse);
        expect(d.hasAction(SemanticsAction.tap), isTrue);
        expect(prefs.isEnabled(m), isFalse);
      }
      expect(find.text('Off'), findsNWidgets(6));
      expect(find.text('0 of 6 inputs turned on (kept only while the app is open).'), findsOneWidget);
      expect(find.byType(Switch), findsNothing, reason: 'each row is one accessible toggle');
      h.dispose();
    });

    testWidgets('Choices toggle independently by tap, semantics action and keyboard', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ConsentScreen(), height: 4000);
      await tapVisible(t, find.text('M2 · Journal'));
      expect(prefs.isEnabled(InputModality.journal), isTrue);
      expect(sem(t, 'M2 · Journal. ${status[InputModality.journal]}').flagsCollection.isToggled, Tristate.isTrue);
      expect(find.text('On'), findsOneWidget);

      t.semantics.tap(find.semantics.byLabel('M5 · Voice. Planned · not built'));
      await t.pumpAndSettle();
      expect(prefs.isEnabled(InputModality.voice), isTrue);

      final m6 = find.bySemanticsLabel('M6 · Physical activity. Manual entry only · sync planned');
      Focus.of(t.element(find.descendant(of: m6, matching: find.byKey(const ValueKey('sense-tappable-focus-ring')))))
          .requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(prefs.isEnabled(InputModality.activity), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(prefs.isEnabled(InputModality.activity), isFalse);

      for (final m in [InputModality.checkIn, InputModality.sleep, InputModality.workload]) {
        expect(prefs.isEnabled(m), isFalse);
      }
      expect(prefs.enabledCount, 2);
      expect(find.text('2 of 6 inputs turned on (kept only while the app is open).'), findsOneWidget);
      h.dispose();
    });

    testWidgets('States the prototype reality, with the original wording', (t) async {
      await pump(t, const ConsentScreen(), height: 4000);
      final all = allText(t);
      for (final s in [
        'Your choices are kept only while the app is open. They are not saved and are lost if you refresh or close it.',
        'Turning an input on does not start any data collection, and no phone or browser permission is requested.',
        'It is not a substitute for an approved research-participant consent process.',
        'Planned, not built. No audio is recorded and no microphone permission is requested.',
        'Health Connect and other activity data are not read, and no permission is requested.',
        'Tele-MANAS 14416',
      ]) {
        expect(all, contains(s));
      }
      expectHonest(all);
    });

    testWidgets('Continue to SENSE opens Home as the only route', (t) async {
      await pump(t, const ConsentScreen());
      await tapVisible(t, find.text('Continue to SENSE'));
      expect(find.byType(MainShell), findsOneWidget);
      expect(t.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    });

    testWidgets('Profile review: Done returns to Profile with the shared choices', (t) async {
      await pump(t, const SettingsScreen(isTabRoot: true));
      await tapVisible(t, find.text('Review data and consent preferences'));
      expect(find.text('Profile · data & consent'), findsOneWidget);
      expect(find.text('Continue to SENSE'), findsNothing);
      await tapVisible(t, find.text('M4 · Workload'));
      await tapVisible(t, find.text('Done'));
      expect(find.byType(ConsentScreen), findsNothing);
      expect(find.text('Currently on: M4 Workload (not saved)'), findsOneWidget);
      // Back control also returns.
      await tapVisible(t, find.text('Review data and consent preferences'));
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byType(ConsentScreen), findsNothing);
    });

    testWidgets('Switch motion: the knob moves instantly with reduced motion', (t) async {
      // The knob's horizontal position inside the first switch.
      double knobX() {
        final align = find.byType(AnimatedAlign).first;
        final knob = find.descendant(of: align, matching: find.byType(Container)).first;
        return t.getTopLeft(knob).dx - t.getTopLeft(align).dx;
      }

      await pump(t, const ConsentScreen(), height: 4000, reduce: true);
      final off = knobX();
      await t.tap(find.text('M1 · Structured check-ins'));
      await t.pump();
      final onX = knobX();
      expect(onX, greaterThan(off + 15), reason: 'already at the "on" end after one frame');
      await t.pumpAndSettle();
      expect(knobX(), onX);

      prefs.reset(); // back to all off for the normal-motion run
      await pump(t, const ConsentScreen(), height: 4000, reduce: false);
      await t.tap(find.text('M1 · Structured check-ins'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(knobX(), inExclusiveRange(off, onX), reason: 'moves with normal motion');
      await t.pumpAndSettle();
      expect(knobX(), onX);
    });
  });

  // ---- Shared: desktop, matrix, contrast --------------------------------------------------
  testWidgets('Desktop: onboarding sets motif beside text; consent floats as a centred sheet', (t) async {
    await pump(t, const OnboardingScreen(), width: 1280, height: 900);
    final motif = t.getRect(find.byType(OnboardingMotif));
    final title = t.getRect(find.text(OnboardingScreen.steps[0].title));
    expect(title.left, greaterThan(motif.right), reason: 'side by side');
    await pump(t, const ConsentScreen(), width: 1280, height: 900);
    final sheet = t.getRect(find.byType(NatureJournalSheet));
    expect(sheet.width, lessThanOrEqualTo(760));
    expect((sheet.center.dx - 640).abs(), lessThan(1));
  });

  List<String> semanticsProblems(WidgetTester t) {
    final problems = <String>[];
    void visit(SemanticsNode n) {
      if (!n.isMergedIntoParent) {
        final d = n.getSemanticsData();
        final f = d.flagsCollection;
        final tap = d.hasAction(SemanticsAction.tap);
        final interactive = f.isButton || f.isToggled != Tristate.none;
        if (interactive && f.isEnabled != Tristate.isFalse && !tap) problems.add('no tap: ${d.label}');
        if (tap && d.label.trim().isEmpty && d.tooltip.trim().isEmpty) problems.add('unlabelled ${n.rect}');
        if (tap && f.isFocused == Tristate.none) problems.add('not focusable: ${d.label}');
      }
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    return problems;
  }

  List<String> brokenWords() {
    final problems = <String>[];
    for (final e in find.byType(RichText).evaluate()) {
      final p = e.renderObject as RenderParagraph;
      if (!p.hasSize || p.maxLines == 1 || !p.softWrap) continue;
      final span = p.text;
      if (span is! TextSpan || (span.children?.isNotEmpty ?? false)) continue;
      for (final word in (span.text ?? '').split(RegExp(r'\s+|(?<=-)'))) {
        if (word.length < 2) continue;
        final tp = TextPainter(
            text: TextSpan(text: word, style: span.style),
            textDirection: TextDirection.ltr,
            textScaler: p.textScaler,
            maxLines: 1)
          ..layout();
        if (tp.width > p.size.width + 0.5) problems.add('"$word" in "${span.text}"');
        tp.dispose();
      }
    }
    return problems;
  }

  Future<void> audit(WidgetTester t, Set<String> found, {bool scroll = true}) async {
    final v = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    for (var i = 0; i < 80; i++) {
      found.addAll(brokenWords());
      expect(semanticsProblems(t), isEmpty);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      if (!scroll || v.evaluate().isEmpty) return;
      final pos = t.state<ScrollableState>(v.first).position;
      if (pos.pixels >= pos.maxScrollExtent - 0.5) break;
      await t.drag(v.first, const Offset(0, -300), warnIfMissed: false);
      await t.pumpAndSettle();
    }
    final pos = t.state<ScrollableState>(v.first).position;
    expect(pos.pixels, closeTo(pos.maxScrollExtent, 1.0), reason: 'did not reach the end');
  }

  for (final width in [320.0, 360.0, 412.0, 768.0, 1024.0, 1280.0, 1440.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: Splash, all three onboarding steps '
          'and Consent fit, no broken words, labelled 48 px targets', (t) async {
        await t.runAsync(loadPoppins);
        final h = t.ensureSemantics();
        final height = width >= 1024 ? 900.0 : 780.0;
        final found = <String>{};

        // Splash (audited before its timer fires, then allowed to finish).
        view(t, width: width, height: height, scale: scale);
        await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()));
        await t.pump();
        await audit(t, found, scroll: false);
        expect(t.takeException(), isNull);
        await t.pump(SplashScreen.duration);
        await t.pumpAndSettle();

        // Onboarding, each step.
        await pump(t, const OnboardingScreen(), width: width, height: height, scale: scale);
        for (var i = 0; i < 3; i++) {
          final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          found.addAll(brokenWords());
          expect(semanticsProblems(t), isEmpty);
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          if (page.evaluate().isNotEmpty) {
            await t.drag(page.first, const Offset(0, -2000), warnIfMissed: false);
            await t.pumpAndSettle();
            found.addAll(brokenWords());
          }
          if (i < 2) {
            await t.tap(find.text('Continue'));
            await t.pumpAndSettle();
          }
        }
        expect(t.takeException(), isNull);

        // Consent.
        await pump(t, const ConsentScreen(), width: width, height: height, scale: scale);
        await audit(t, found);
        expect(found, isEmpty, reason: found.join('\n'));
        expect(t.takeException(), isNull);
        h.dispose();
      });
    }
  }

  testWidgets('Text contrast guideline passes on Splash, each onboarding step and Consent', (t) async {
    await t.runAsync(loadPoppins);
    final h = t.ensureSemantics();
    view(t, height: 1600);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()));
    await t.pump();
    await expectLater(t, meetsGuideline(textContrastGuideline), reason: 'Splash');
    await t.pump(SplashScreen.duration);
    await t.pumpAndSettle();
    await pump(t, const OnboardingScreen(), height: 1600);
    for (var i = 0; i < 3; i++) {
      await expectLater(t, meetsGuideline(textContrastGuideline), reason: 'Onboarding step ${i + 1}');
      if (i < 2) await tapVisible(t, find.text('Continue'));
    }
    await pump(t, const ConsentScreen(), height: 4000);
    await tapVisible(t, find.text('M1 · Structured check-ins'));
    await expectLater(t, meetsGuideline(textContrastGuideline), reason: 'Consent');
    h.dispose();
  });
}
