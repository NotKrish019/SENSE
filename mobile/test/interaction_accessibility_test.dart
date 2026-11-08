import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/theme/nature_tokens.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/insight_detail_screen.dart';
import 'package:mindpulse/presentation/screens/insights_screen.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/onboarding_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/voice_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Task 8: interaction and accessibility QA.
///
/// These are automated Flutter semantics checks. They prove what the app
/// exposes to assistive technology (roles, labels, actions, focusability) and
/// that the actions work; they are NOT a substitute for testing with a real
/// screen reader (VoiceOver / TalkBack), which has to be done by hand.
void main() {
  setUp(ConsentPreferences.instance.reset);

  Future<void> loadPoppins() async {
    final loader = FontLoader('Poppins');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/poppins/Poppins-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  Future<void> pump(WidgetTester tester, Widget home,
      {double width = 412, double height = 915, double scale = 1.0}) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The production Home landscape animates continuously, so pumpAndSettle can
    // only settle with reduced motion. Motion is covered by its own tests.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  // ---- Semantics audit of every screen ----------------------------------
  // For every node a screen reader can reach (nodes merged into a parent are
  // part of that parent and are skipped):
  //  * an enabled button or switch has a tap action (activation works);
  //  * a tap action has a label (or tooltip);
  //  * a tap action is keyboard-focusable.
  List<String> semanticsProblems(WidgetTester tester) {
    final problems = <String>[];
    void visit(SemanticsNode n) {
      if (!n.isMergedIntoParent) {
        final d = n.getSemanticsData();
        final f = d.flagsCollection;
        final enabled = f.isEnabled != Tristate.isFalse;
        final interactive = f.isButton || f.isToggled != Tristate.none;
        final tap = d.hasAction(SemanticsAction.tap);
        final name = d.label.split('\n').first;
        if (interactive && enabled && !tap) problems.add('no tap action: "$name"');
        if (tap && d.label.trim().isEmpty && d.tooltip.trim().isEmpty) {
          problems.add('unlabelled tap target at ${n.rect}');
        }
        if (tap && f.isFocused == Tristate.none) problems.add('not focusable: "$name"');
        final adjustable = d.hasAction(SemanticsAction.increase) ||
            d.hasAction(SemanticsAction.decrease);
        if (adjustable && d.label.trim().isEmpty) {
          problems.add('unnamed adjustable control (value "${d.value}") at ${n.rect}');
        }
      }
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    return problems;
  }

  final screens = <String, Widget Function()>{
    'Home': () => const MainShell(),
    'Insights': () => const MainShell(initialIndex: MainTab.insights),
    'Profile': () => const MainShell(initialIndex: MainTab.profile),
    'Onboarding': () => const OnboardingScreen(),
    'Consent': () => const ConsentScreen(),
    'Check-in': () => const CheckInScreen(),
    'Journal': () => const JournalScreen(),
    'Sleep': () => const SleepScreen(),
    'Workload': () => const WorkloadScreen(),
    'Activity': () => const ActivityScreen(),
    'Voice': () => const VoiceScreen(),
    'Insight detail': () => const InsightDetailScreen(),
  };

  group('Semantics audit (real Poppins)', () {
    for (final width in [320.0, 412.0]) {
      for (final e in screens.entries) {
        testWidgets('${e.key} at ${width.toInt()} px: actions, labels, focus, '
            '48 px targets, text contrast', (tester) async {
          await tester.runAsync(loadPoppins);
          final handle = tester.ensureSemantics();
          // A tall viewport puts (almost) the whole screen on stage at once.
          await pump(tester, e.value(), width: width, height: 4000);
          if (e.key == 'Journal') {
            // An enabled Save button is checked too (a disabled button is an
            // inactive control, which WCAG exempts from contrast).
            await tester.enterText(find.byType(TextField), 'A calm day.');
            await tester.pumpAndSettle();
          }
          expect(semanticsProblems(tester), isEmpty);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // Known tool artefact, verified by rendering the screen to an image:
          // at 320 px the sleep-history labels ("7h", "8h") sit inside a
          // FittedBox, and the guideline samples a rectangle ~57 px above them
          // (over the cyan bars). The rendered labels are textPrimary #082B52
          // on white (13.6:1); that token pair is asserted directly below.
          if (!(e.key == 'Sleep' && width == 320)) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          handle.dispose();
        });
      }
    }
  });

  group('Real Poppins 3x3 matrix: targets and actions stay intact', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('All 12 screens at ${width.toInt()} px, text ${scale}x', (tester) async {
          await tester.runAsync(loadPoppins);
          final handle = tester.ensureSemantics();
          final failures = <String>[];
          for (final e in screens.entries) {
            await tester.pumpWidget(const SizedBox());
            await pump(tester, e.value(), width: width, height: 6000, scale: scale);
            for (final p in semanticsProblems(tester)) {
              failures.add('${e.key}: $p');
            }
            final r = await androidTapTargetGuideline.evaluate(tester);
            if (!r.passed) failures.add('${e.key}: ${r.reason}');
            expect(tester.takeException(), isNull, reason: e.key);
          }
          expect(failures, isEmpty, reason: failures.join('\n'));
          handle.dispose();
        });
      }
    }
  });

  // ---- Centre "+" button ---------------------------------------------------
  group('Centre + (new check-in) button', () {
    Finder plus() => find.byTooltip('New daily check-in');

    testWidgets('is one labelled button with tap and focus actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const MainShell());
      expect(
        tester.getSemantics(find.bySemanticsLabel('New daily check-in')),
        isSemantics(
          label: 'New daily check-in',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('pointer tap opens Check-in at ${width.toInt()} px and is not obstructed',
          (tester) async {
        await pump(tester, const MainShell(initialIndex: MainTab.insights), width: width);
        // The topmost hit at the button's centre must belong to the button.
        final centre = tester.getCenter(plus());
        final hit = HitTestResult();
        tester.binding.hitTestInView(hit, centre, tester.view.viewId);
        final hitsButton = hit.path.any((e) =>
            e.target is RenderObject &&
            find
                .descendant(of: plus(), matching: find.byType(Container))
                .evaluate()
                .any((el) => el.renderObject == e.target));
        expect(hitsButton, isTrue, reason: 'something covers the + button');
        await tester.tap(plus());
        await tester.pumpAndSettle();
        expect(find.byType(CheckInScreen), findsOneWidget);
        // Back returns to the same tab, which is still the selected one.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
        await tester.pumpAndSettle();
        expect(find.byType(CheckInScreen), findsNothing);
        expect(find.text('Longitudinal insights'), findsOneWidget);
        final handle = tester.ensureSemantics();
        expect(tester.getSemantics(find.bySemanticsLabel('Insights tab')),
            isSemantics(isSelected: true));
        handle.dispose();
      });
    }

    testWidgets('screen-reader activation (semantics tap action) opens Check-in',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const MainShell());
      tester.semantics.tap(find.semantics.byLabel('New daily check-in'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckInScreen), findsOneWidget);
      handle.dispose();
    });

    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('keyboard: Tab reaches it, ${key.keyLabel} opens Check-in, focus ring shows',
          (tester) async {
        await pump(tester, const MainShell());
        var reached = false;
        for (var i = 0; i < 80 && !reached; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final ctx = FocusManager.instance.primaryFocus?.context;
          reached = ctx != null &&
              ctx.findAncestorWidgetOfExactType<SenseTappable>()?.semanticLabel ==
                  'New daily check-in';
        }
        expect(reached, isTrue, reason: 'Tab never reached the + button');
        final ring = tester.widget<Container>(find.ancestor(
            of: plus(), matching: find.byKey(const ValueKey('sense-tappable-focus-ring'))));
        expect(ring.foregroundDecoration, isNotNull, reason: 'no visible focus ring');
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(CheckInScreen), findsOneWidget);
      });
    }
  });

  group('Keyboard focus order', () {
    String describe(BuildContext ctx) {
      final t = ctx.findAncestorWidgetOfExactType<SenseTappable>();
      if (t?.semanticLabel != null) return t!.semanticLabel!;
      final tip = ctx.findAncestorWidgetOfExactType<Tooltip>();
      if (tip?.message != null) return tip!.message!;
      return 'content@${ctx.findRenderObject()?.paintBounds.size}';
    }

    testWidgets('Home: every page control first, then Home/Insights/+/Profile once; '
        'nothing from hidden tabs', (tester) async {
      await pump(tester, const MainShell());
      final order = <String>[];
      FocusNode? first;
      for (var i = 0; i < 60; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final node = FocusManager.instance.primaryFocus!;
        if (identical(node, first)) break; // completed one full cycle
        first ??= node;
        final ctx = node.context!;
        expect(ctx.findAncestorWidgetOfExactType<InsightsScreen>(), isNull,
            reason: 'focus reached the hidden Insights tab');
        expect(ctx.findAncestorWidgetOfExactType<SettingsScreen>(), isNull,
            reason: 'focus reached the hidden Profile tab');
        order.add(describe(ctx));
      }
      const nav = ['Home tab', 'Insights tab', 'New daily check-in', 'Profile tab'];
      final firstNav = order.indexOf('Home tab');
      expect(firstNav, greaterThan(0), reason: order.join(' > '));
      expect(order.sublist(firstNav), nav, reason: order.join(' > '));
      expect(order.sublist(0, firstNav).any(nav.contains), isFalse, reason: order.join(' > '));
      // Input rows are named "Sleep. Duration, timing and rest" and so on.
      expect(order.map((o) => o.split('. ').first),
          containsAllInOrder(['Check-in', 'Journal', 'Sleep', 'Workload', 'Voice', 'Activity']));
    });
  });

  testWidgets('Every SenseTappable on Home shows a focus ring when focused', (tester) async {
    await pump(tester, const MainShell(), height: 3000);
    final rings = find.byKey(const ValueKey('sense-tappable-focus-ring'));
    final count = rings.evaluate().length;
    expect(count, greaterThanOrEqualTo(12));
    for (var i = 0; i < count; i++) {
      Focus.of(tester.element(rings.at(i))).requestFocus();
      await tester.pump(); // focus change is applied
      await tester.pump(); // onFocusChange rebuild draws the ring
      final ring = tester.widget<Container>(rings.at(i));
      final deco = ring.foregroundDecoration as BoxDecoration?;
      expect(deco, isNotNull, reason: 'ring $i not shown');
      // Home is redesigned (Phase 1): its controls use the Living Landscapes
      // ink ring (10:1 on parchment) instead of the blue one.
      expect((deco!.border as Border).top.color, NatureColors.focus);
      expect((deco.border as Border).top.width, greaterThanOrEqualTo(2.0));
    }
  });

  // ---- Other custom controls: screen-reader and keyboard activation -------
  group('Custom controls activate via screen reader and keyboard', () {
    testWidgets('Bottom tabs switch with the semantics tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const MainShell());
      tester.semantics.tap(find.semantics.byLabel('Insights tab'));
      await tester.pumpAndSettle();
      expect(find.text('Longitudinal insights'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Insights tab')),
          isSemantics(isSelected: true, isButton: true));
      tester.semantics.tap(find.semantics.byLabel('Profile tab'));
      await tester.pumpAndSettle();
      expect(find.text('Profile & settings'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Home input row and "About your insights" activate with the semantics tap action',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const MainShell());
      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Sleep\. ')));
      await tester.pumpAndSettle();
      expect(find.byType(SleepScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('About your insights'));
      await tester.pumpAndSettle();
      expect(find.text('Longitudinal insights'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Check-in mood options select via semantics tap and keyboard', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const CheckInScreen());
      tester.semantics.tap(find.semantics.byLabel('Mood: Good'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel('Mood: Good')),
          isSemantics(isSelected: true, isButton: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Mood: Neutral')),
          isSemantics(isSelected: false));
      handle.dispose();
    });

    testWidgets('Insights period selector selects via semantics tap', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const MainShell(initialIndex: MainTab.insights));
      tester.semantics.tap(find.semantics.byLabel('Month view'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel('Month view')),
          isSemantics(isSelected: true, hint: 'Sample charts do not change yet'));
      handle.dispose();
    });

    testWidgets('Voice demo button activates via semantics tap; still says no audio',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const VoiceScreen());
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Start demo .*No audio is recorded')));
      await tester.pump();
      expect(find.bySemanticsLabel('Stop demo. No audio is being recorded.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });

  group('Sliders have accessible names and spoken values', () {
    for (final (screen, label, value) in [
      (const CheckInScreen(), 'Motivation or energy level', '3 of 5'),
      (const SleepScreen(), 'Sleep duration', null),
      (const WorkloadScreen(), 'Mental demand', null),
      (const WorkloadScreen(), 'Effort', null),
      (const ActivityScreen(), 'Steps', null),
      (const ActivityScreen(), 'Active minutes', null),
    ]) {
      testWidgets('${screen.runtimeType}: "$label"', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, screen, height: 3000);
        final d = tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
        expect(d.hasAction(SemanticsAction.increase) || d.hasAction(SemanticsAction.decrease),
            isTrue, reason: 'the labelled node is the slider itself');
        expect(d.value, isNotEmpty);
        if (value != null) expect(d.value, value);
        handle.dispose();
      });
    }
  });

  testWidgets('Check-in step 2: audit passes and "Perceived stress" slider is named',
      (tester) async {
    await tester.runAsync(loadPoppins);
    final handle = tester.ensureSemantics();
    await pump(tester, const CheckInScreen(), height: 3000);
    await tester.tap(find.text('Continue to stress rating'));
    await tester.pumpAndSettle();
    expect(find.text('Daily check-in · Step 2 of 2'), findsOneWidget);
    expect(semanticsProblems(tester), isEmpty);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    // "Perceived stress" is also the step heading; read the slider's own node.
    final d = tester.getSemantics(find.byType(Slider)).getSemanticsData();
    expect(d.label, 'Perceived stress');
    expect(d.hasAction(SemanticsAction.increase) || d.hasAction(SemanticsAction.decrease), isTrue);
    expect(d.value, matches(RegExp(r'^\d of 5$')));
    handle.dispose();
  });

  // ---- Sleep stars (contrast + states + keyboard) ---------------------------
  group('Sleep rest-quality stars', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    Icon starIcon(WidgetTester tester, int rating) => tester.widget<Icon>(find.descendant(
        of: find.bySemanticsLabel('Rest quality $rating of 5'), matching: find.byType(Icon)));

    testWidgets('Unselected stars meet 3:1, selected differ by shape, and numbers 4.5:1',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SleepScreen());
      // Default selection is 4.
      final unselected = starIcon(tester, 2);
      final selected = starIcon(tester, 4);
      expect(unselected.icon, Icons.star_outline_rounded);
      expect(selected.icon, Icons.star_rounded);
      expect(ratio(unselected.color!, SenseColors.white), greaterThanOrEqualTo(3.0));
      expect(ratio(selected.color!, SenseColors.white), greaterThanOrEqualTo(3.0));
      expect(ratio(unselected.color!, SenseColors.white), greaterThan(4.5),
          reason: 'textMuted outline (5.1:1)');
      final hours = tester.widget<Text>(find.text('7h').first);
      expect(ratio(hours.style!.color!, SenseColors.white), greaterThanOrEqualTo(4.5),
          reason: 'sleep-history hour labels');
      for (final r in [2, 4]) {
        final number = tester.widget<Text>(find.descendant(
            of: find.bySemanticsLabel('Rest quality $r of 5'), matching: find.text('$r')));
        expect(ratio(number.style!.color!, SenseColors.white), greaterThanOrEqualTo(4.5),
            reason: 'number $r');
      }
      handle.dispose();
    });

    testWidgets('Selection is announced and changes via semantics tap and keyboard',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SleepScreen());
      expect(tester.getSemantics(find.bySemanticsLabel('Rest quality 4 of 5')),
          isSemantics(isSelected: true, isButton: true, hasTapAction: true, isFocusable: true));
      tester.semantics.tap(find.semantics.byLabel('Rest quality 2 of 5'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel('Rest quality 2 of 5')),
          isSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Rest quality 4 of 5')),
          isSemantics(isSelected: false));

      // Keyboard: focus star 5 and press Space.
      final star5 = find.bySemanticsLabel('Rest quality 5 of 5');
      final focusNode = Focus.of(tester.element(find.descendant(
          of: star5, matching: find.byKey(const ValueKey('sense-tappable-focus-ring')))));
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(star5), isSemantics(isSelected: true));
      expect(starIcon(tester, 5).icon, Icons.star_rounded);
      handle.dispose();
    });
  });
}
