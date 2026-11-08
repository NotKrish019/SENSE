import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/core/theme/nature_tokens.dart';
import 'package:mindpulse/presentation/nature/living_landscape.dart';
import 'package:mindpulse/presentation/nature/mood_glyph.dart';
import 'package:mindpulse/presentation/nature/mood_glyph_data.dart';
import 'package:mindpulse/presentation/nature/mood_scale.dart';
import 'package:mindpulse/presentation/nature/nature_navigation.dart';
import 'package:mindpulse/presentation/nature/nature_widgets.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/dashboard_screen.dart';
import 'package:mindpulse/presentation/screens/insight_detail_screen.dart';
import 'package:mindpulse/presentation/screens/insights_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/voice_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Phase 1: the Living Landscapes design in the PRODUCTION app (MainShell,
/// DashboardScreen, CheckInScreen), not the isolated preview.
void main() {
  setUp(ConsentPreferences.instance.reset);

  const labels = ['Very Low', 'Low', 'Neutral', 'Good', 'Great'];

  Future<void> loadPoppins() async {
    final loader = FontLoader('Poppins');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/poppins/Poppins-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  // Reduced motion by default: the Home landscape animates forever otherwise.
  // Motion has its own tests below.
  Future<void> pump(WidgetTester t, Widget home,
      {double width = 412, double height = 915, double scale = 1.0, bool motion = false}) async {
    t.view.physicalSize = Size(width * 3, height * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    t.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !motion);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    if (motion) {
      await t.pump(const Duration(milliseconds: 100));
    } else {
      await t.pumpAndSettle();
    }
  }

  Future<void> tapText(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).first);
    await t.pumpAndSettle();
    await t.tap(find.text(text).first);
    await t.pumpAndSettle();
  }

  Future<void> goBack(WidgetTester t) async {
    await t.pageBack();
    await t.pumpAndSettle();
  }

  // ---- Home -------------------------------------------------------------------------
  group('Production Home', () {
    testWidgets('The shell shows the Living Landscapes Home with its landscape and sheet',
        (t) async {
      await pump(t, const MainShell());
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LivingLandscape), findsOneWidget);
      expect(find.text("Begin today's check-in"), findsOneWidget);
      expect(find.text(PrototypeCopy.noBaselineTitle), findsOneWidget);
      expect(find.byType(NatureBottomBar), findsOneWidget);
      expect(find.byType(NatureTopBar), findsNothing);
    });

    testWidgets('Begin today\'s check-in opens the production CheckInScreen', (t) async {
      await pump(t, const MainShell());
      await tapText(t, "Begin today's check-in");
      expect(find.byType(CheckInScreen), findsOneWidget);
      await t.tap(find.byTooltip('Back to Home'));
      await t.pumpAndSettle();
      expect(find.byType(CheckInScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    for (final (label, type) in [
      ('Check-in', CheckInScreen),
      ('Journal', JournalScreen),
      ('Sleep', SleepScreen),
      ('Workload', WorkloadScreen),
      ('Voice', VoiceScreen),
      ('Activity', ActivityScreen),
    ]) {
      testWidgets('"$label" row opens the production ${type.toString()}', (t) async {
        final h = t.ensureSemantics();
        await pump(t, const MainShell(), height: 3000);
        t.semantics.tap(find.semantics.byLabel(RegExp('^$label\\. ')));
        await t.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);
        h.dispose();
      });
    }

    testWidgets('About your insights > Insights tab; example > Insight detail; shield > Profile',
        (t) async {
      final h = t.ensureSemantics();
      await pump(t, const MainShell(), height: 3000);
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      t.semantics.tap(find.semantics.byLabel('About your insights'));
      await t.pumpAndSettle();
      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Insights tab')), isSemantics(isSelected: true));
      expect(nav.canPop(), isFalse, reason: 'a tab switch, not a pushed duplicate');
      t.semantics.tap(find.semantics.byLabel('Home tab'));
      await t.pumpAndSettle();
      t.semantics.tap(find.semantics.byLabel('View example details'));
      await t.pumpAndSettle();
      expect(find.byType(InsightDetailScreen), findsOneWidget);
      await goBack(t);
      t.semantics.tap(find.semantics.byLabel(DashboardScreen.profileLabel));
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Profile tab')), isSemantics(isSelected: true));
      expect(nav.canPop(), isFalse);
      h.dispose();
    });

    testWidgets('Support line opens Profile (support contacts)', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const MainShell(), height: 3000);
      t.semantics.tap(find.semantics
          .byLabel('Need to talk to someone now? Support contacts are in Profile.'));
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Profile tab')), isSemantics(isSelected: true));
      h.dispose();
    });

    testWidgets('Standalone Home pushes Insights and Profile when no tab callbacks are given',
        (t) async {
      final h = t.ensureSemantics();
      await pump(t, const DashboardScreen(), height: 3000);
      t.semantics.tap(find.semantics.byLabel('About your insights'));
      await t.pumpAndSettle();
      expect(find.byType(InsightsScreen), findsOneWidget);
      await goBack(t);
      t.semantics.tap(find.semantics.byLabel(DashboardScreen.profileLabel));
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      h.dispose();
    });

    testWidgets('Honest wording: no pattern yet, sample data marked, inputs described truthfully',
        (t) async {
      await pump(t, const MainShell(), height: 3000);
      expect(find.text(PrototypeCopy.noBaselineTitle), findsOneWidget);
      expect(find.text(PrototypeCopy.noBaselineDescription), findsOneWidget);
      expect(find.text(PrototypeCopy.sampleDataLabel), findsOneWidget);
      expect(find.textContaining('not based on your data'), findsOneWidget);
      expect(find.text('Choose any, or none. Each one is voluntary.'), findsOneWidget);
      expect(find.text('Write freely · not saved yet'), findsOneWidget);
      expect(find.text('Planned · demo only, no audio recorded'), findsOneWidget);
      expect(find.text('Manual entry · no health app connected'), findsOneWidget);
      final all = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join('\n');
      expect(all, isNot(contains('—')), reason: 'em dash in user-facing text');
      for (final bad in ['your stress level is', 'diagnos', 'detected', 'stress score']) {
        expect(all.toLowerCase(), isNot(contains(bad)));
      }
    });

    testWidgets('The landscape is decorative (no semantics)', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const MainShell());
      expect(
          find.descendant(of: find.byType(LivingLandscape), matching: find.byType(ExcludeSemantics)),
          findsWidgets);
      h.dispose();
    });
  });

  // ---- Shell ------------------------------------------------------------------------
  group('Production shell by breakpoint', () {
    testWidgets('Phone and tablet use the bottom bar; desktop uses the top bar', (t) async {
      for (final (w, top) in [(360.0, false), (599.0, false), (768.0, false), (1023.0, false),
        (1024.0, true), (1440.0, true)]) {
        await pump(t, const MainShell(), width: w, height: 900);
        expect(find.byType(NatureTopBar), top ? findsOneWidget : findsNothing, reason: '$w px');
        expect(find.byType(NatureBottomBar), top ? findsNothing : findsOneWidget, reason: '$w px');
      }
    });

    testWidgets('Desktop: tabs switch, New check-in opens the production check-in', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const MainShell(), width: 1280, height: 900);
      t.semantics.tap(find.semantics.byLabel('Insights tab'));
      await t.pumpAndSettle();
      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Insights tab')),
          isSemantics(isSelected: true, isButton: true));
      t.semantics.tap(find.semantics.byLabel('New daily check-in'));
      await t.pumpAndSettle();
      expect(find.byType(CheckInScreen), findsOneWidget);
      h.dispose();
    });

    testWidgets('Tablet and desktop: Insights lays itself out (centred sheet, not stretched)',
        (t) async {
      // Phase 2: Insights and Profile are redesigned and size their own sheet;
      // the interim 760 px wrapper from Phase 1 is gone.
      for (final w in [768.0, 1280.0]) {
        await pump(t, const MainShell(initialIndex: MainTab.insights), width: w, height: 900);
        expect(t.getSize(find.byType(InsightsScreen)).width, w, reason: '$w');
        final sheet = find.descendant(
            of: find.byType(InsightsScreen), matching: find.byType(NatureJournalSheet));
        expect(t.getSize(sheet).width, lessThanOrEqualTo(880), reason: '$w');
        expect(t.getCenter(sheet).dx, closeTo(w / 2, 1), reason: '$w');
      }
    });

    testWidgets('Desktop keyboard order: header first (wordmark tabs, New check-in), then Home',
        (t) async {
      await pump(t, const MainShell(), width: 1280, height: 900);
      final order = <String>[];
      for (var i = 0; i < 6; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        order.add(FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<SenseTappable>()
                ?.semanticLabel ??
            '?');
      }
      expect(order.take(5),
          ['Home tab', 'Insights tab', 'Profile tab', 'New daily check-in', "Begin today's check-in"]);
    });

    testWidgets('Phone keyboard order: page first, then Home/Insights/+/Profile', (t) async {
      await pump(t, const MainShell());
      final order = <String>[];
      FocusNode? first;
      for (var i = 0; i < 40; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        final node = FocusManager.instance.primaryFocus!;
        if (identical(node, first)) break;
        first ??= node;
        order.add(node.context?.findAncestorWidgetOfExactType<SenseTappable>()?.semanticLabel ?? '?');
      }
      expect(order.sublist(order.length - 4),
          ['Home tab', 'Insights tab', 'New daily check-in', 'Profile tab']);
      expect(order.indexOf("Begin today's check-in"), lessThan(order.indexOf('Home tab')));
    });
  });

  // ---- Motion -----------------------------------------------------------------------
  group('Motion', () {
    testWidgets('With motion allowed the Home landscape animates', (t) async {
      await pump(t, const MainShell(), motion: true);
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.pump(const Duration(seconds: 1));
      expect(t.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('Reduced motion: nothing ticks on Home', (t) async {
      await pump(t, const MainShell());
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('A hidden Home tab is paused (TickerMode)', (t) async {
      await pump(t, const MainShell(), motion: true);
      await t.tap(find.descendant(of: find.byType(NatureBottomBar), matching: find.text('Insights')));
      await t.pump(const Duration(milliseconds: 300));
      // The effective ticker state where the landscape lives.
      final ctx = t.element(find.byType(LivingLandscape, skipOffstage: false));
      expect(TickerMode.valuesOf(ctx).enabled, isFalse);
      // The landscape no longer drives frames.
      await t.pump(const Duration(seconds: 1));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });
  });

  // ---- Check-in ---------------------------------------------------------------------
  group('Production Check-in', () {
    CheckInScreenState st(WidgetTester t) => t.state<CheckInScreenState>(find.byType(CheckInScreen));
    Finder tile(int v) => find.byKey(ValueKey('mood-$v'));

    test('Mood model: exact values, order and labels', () {
      expect(CheckInScreen.moodOptions.map((o) => o.value), [1, 2, 3, 4, 5]);
      expect(CheckInScreen.moodOptions.map((o) => o.label), labels);
    });

    test('Each value has its approved symbol (rain 9/3/0/0/0, sun only for 4 and 5)', () {
      int rain(int v) => moodGlyphLayers[v]!
          .where((l) => l.stroke == const Color(0xFF3E6E6A))
          .map((l) => 'M'.allMatches(l.path).length)
          .fold(0, (a, b) => a + b);
      expect([for (var v = 1; v <= 5; v++) rain(v)], [9, 3, 0, 0, 0]);
      bool sun(int v) => moodGlyphLayers[v]!.any((l) => l.path.startsWith('circle:') && l.stroke != null);
      expect([for (var v = 1; v <= 5; v++) sun(v)], [false, false, false, true, true]);
    });

    test('Generated drawing data is the production copy of the SVG sources', () {
      final gen = File('lib/presentation/nature/mood_glyph_data.dart').readAsStringSync();
      expect(gen, contains('GENERATED FILE'));
      expect(gen, contains('docs/redesign/mood-symbols/tools/gen_dart.py'));
      for (final f in ['mood_1_very_low', 'mood_2_low', 'mood_3_neutral', 'mood_4_good', 'mood_5_great']) {
        expect(File('../docs/redesign/mood-symbols/$f.svg').existsSync(), isTrue, reason: f);
      }
    });

    testWidgets('Defaults: mood 3 (Neutral), motivation 3, stress 2, step 1', (t) async {
      await pump(t, const CheckInScreen());
      expect(st(t).selectedMood, 3);
      expect(st(t).motivationLevel, 3);
      expect(st(t).perceivedStress, 2);
      expect(st(t).currentStep, 1);
      expect(find.text('How are you feeling right now?'), findsOneWidget);
      expect(find.byType(MoodGlyph), findsNWidgets(5));
    });

    for (var v = 1; v <= 5; v++) {
      testWidgets('Selecting ${labels[v - 1]} sets $v with all selected cues', (t) async {
        await pump(t, const CheckInScreen());
        await t.tap(tile(v));
        await t.pumpAndSettle();
        expect(st(t).selectedMood, v);
        for (var o = 1; o <= 5; o++) {
          final sel = o == v;
          final d = t.widget<AnimatedContainer>(find.byKey(ValueKey('mood-surface-$o'))).decoration!
              as BoxDecoration;
          expect((d.border! as Border).top.width, sel ? MoodTile.outlineSelected : MoodTile.outline);
          expect((d.border! as Border).top.color, sel ? NatureColors.forest : NatureColors.borderStrong);
          expect(d.color, sel ? NatureColors.paper : NatureColors.background);
          expect(t.widget<AnimatedScale>(find.byKey(ValueKey('mood-check-$o'))).scale, sel ? 1.0 : 0.0);
          final label = t.widget<Text>(find.descendant(of: tile(o), matching: find.text(labels[o - 1])));
          expect(label.style!.fontWeight, sel ? FontWeight.w600 : FontWeight.w500);
        }
      });
    }

    testWidgets('Screen-reader names, roles and selected state; symbols are decorative', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const CheckInScreen());
      for (var v = 1; v <= 5; v++) {
        expect(
            t.getSemantics(find.bySemanticsLabel('Mood: ${labels[v - 1]}')),
            isSemantics(
                label: 'Mood: ${labels[v - 1]}',
                isButton: true,
                hasSelectedState: true,
                isSelected: v == 3,
                isFocusable: true,
                hasTapAction: true));
      }
      expect(find.bySemanticsLabel('Neutral'), findsNothing);
      t.semantics.tap(find.semantics.byLabel('Mood: Great'));
      await t.pumpAndSettle();
      expect(st(t).selectedMood, 5);
      expect(t.getSemantics(find.bySemanticsLabel('Mood: Great')), isSemantics(isSelected: true));
      h.dispose();
    });

    testWidgets('Keyboard: Back then moods 1 to 5; Enter and Space select; ring outside the border',
        (t) async {
      await pump(t, const CheckInScreen());
      String? focused() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<SenseTappable>()
          ?.semanticLabel;
      final order = <String?>[];
      for (var i = 0; i < 6; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        order.add(focused());
      }
      expect(order, ['Back to Home', for (final l in labels) 'Mood: $l']);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(st(t).selectedMood, 5);
      final ringFinder = find.descendant(
          of: tile(5), matching: find.byKey(const ValueKey('sense-tappable-focus-ring')));
      final ring = t.widget<Container>(ringFinder).foregroundDecoration! as BoxDecoration;
      expect((ring.border! as Border).top.color, NatureColors.focus);
      expect(t.getRect(ringFinder).left,
          t.getRect(find.byKey(const ValueKey('mood-surface-5'))).left - MoodTile.focusGap);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(st(t).selectedMood, 4);
    });

    testWidgets('Sliders keep production names, scales and spoken values', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const CheckInScreen(), height: 1600);
      expect(t.getSemantics(find.bySemanticsLabel('Motivation or energy level')),
          isSemantics(value: '3 of 5', isSlider: true));
      final s1 = t.widget<Slider>(find.byType(Slider));
      expect([s1.min, s1.max, s1.divisions], [1, 5, 4]);
      await tapText(t, 'Continue to stress rating');
      expect(t.getSemantics(find.byType(Slider)),
          isSemantics(label: 'Perceived stress', value: '2 of 5', isSlider: true));
      h.dispose();
    });

    testWidgets('Flow: step 1 > step 2 > Back keeps answers > finish > honest page > Home',
        (t) async {
      await pump(t, const MainShell(), height: 1600);
      await t.tap(find.byTooltip('New daily check-in'));
      await t.pumpAndSettle();
      await t.tap(tile(2));
      await t.pumpAndSettle();
      await tapText(t, 'Continue to stress rating');
      expect(st(t).currentStep, 2);
      await tapText(t, 'Back');
      expect(st(t).currentStep, 1);
      expect(st(t).selectedMood, 2);
      await tapText(t, 'Continue to stress rating');
      await tapText(t, 'Finish check-in');
      expect(find.text('Check-in complete, not saved'), findsOneWidget);
      expect(find.textContaining('your answers are not saved'), findsOneWidget);
      await tapText(t, 'Return to Home');
      expect(find.byType(CheckInScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('Honest wording on every step; reduced motion makes selection instant', (t) async {
      await pump(t, const CheckInScreen(), height: 1800);
      expect(t.widget<AnimatedScale>(find.byKey(const ValueKey('mood-check-1'))).duration,
          Duration.zero);
      final seen = <String>[];
      void collect() => seen.addAll(find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? ''));
      collect();
      await tapText(t, 'Continue to stress rating');
      collect();
      await tapText(t, 'Finish check-in');
      collect();
      final all = seen.join('\n');
      expect(all, isNot(contains('—')));
      for (final m in RegExp(r'.{0,12}saved', caseSensitive: false).allMatches(all)) {
        expect(m.group(0)!.toLowerCase(), contains('not saved'), reason: m.group(0));
      }
      expect(all, contains('optional'));
    });

    testWidgets('With motion allowed, selection animates gently (no bounce curve)', (t) async {
      await pump(t, const CheckInScreen(), motion: true);
      final badge = t.widget<AnimatedScale>(find.byKey(const ValueKey('mood-check-1')));
      expect(badge.duration, NatureMotion.selection);
      expect(badge.curve, NatureMotion.ease);
    });
  });

  // ---- Responsive + accessibility matrix (real Poppins) -----------------------------
  List<String> semanticsProblems(WidgetTester t) {
    final problems = <String>[];
    void visit(SemanticsNode n) {
      if (!n.isMergedIntoParent) {
        final d = n.getSemanticsData();
        final f = d.flagsCollection;
        final tap = d.hasAction(SemanticsAction.tap);
        if (f.isButton && f.isEnabled != Tristate.isFalse && !tap) problems.add('no tap: ${d.label}');
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

  Future<void> auditPage(WidgetTester t, Set<String> found) async {
    final v = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    for (var i = 0; i < 80; i++) {
      found.addAll(brokenWords());
      expect(semanticsProblems(t), isEmpty);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
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
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: production Home and Check-in fit, '
          'no broken words, 48 px labelled focusable targets', (t) async {
        await t.runAsync(loadPoppins);
        final h = t.ensureSemantics();
        final height = width >= 1024 ? 900.0 : 780.0;
        final found = <String>{};
        await pump(t, const MainShell(), width: width, height: height, scale: scale);
        await auditPage(t, found);
        await pump(t, const CheckInScreen(), width: width, height: height, scale: scale);
        await auditPage(t, found);
        await tapText(t, 'Continue to stress rating');
        await auditPage(t, found);
        await tapText(t, 'Finish check-in');
        await auditPage(t, found);
        expect(found, isEmpty, reason: found.join('\n'));
        expect(t.takeException(), isNull);
        h.dispose();
      });
    }
  }

  testWidgets('Text contrast guideline passes on production Home and Check-in (real Poppins)',
      (t) async {
    await t.runAsync(loadPoppins);
    final h = t.ensureSemantics();
    await pump(t, const MainShell(), height: 3000);
    await expectLater(t, meetsGuideline(textContrastGuideline));
    await pump(t, const CheckInScreen(), height: 1800);
    await expectLater(t, meetsGuideline(textContrastGuideline));
    h.dispose();
  });

  test('Approved palette tokens and contrast', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(NatureColors.parchment, const Color(0xFFF3EBDD));
    expect(NatureColors.paper, const Color(0xFFFAF7EF));
    expect(NatureColors.paleSage, const Color(0xFFD9E4D4));
    expect(NatureColors.eucalyptus, const Color(0xFFA8BDB0));
    expect(NatureColors.skyTeal, const Color(0xFF78AAA5));
    expect(NatureColors.forest, const Color(0xFF3F6556));
    expect(NatureColors.sunOchre, const Color(0xFFE5AE56));
    expect(NatureColors.dustyCoral, const Color(0xFFD88D83));
    expect(NatureColors.riverBlue, const Color(0xFF789EA5));
    expect(NatureColors.ink, const Color(0xFF293A35));
    expect(NatureColors.inkMuted, const Color(0xFF5A685F));
    for (final bg in [NatureColors.parchment, NatureColors.paper, NatureColors.surfaceQuiet]) {
      expect(ratio(NatureColors.ink, bg), greaterThanOrEqualTo(4.5));
      expect(ratio(NatureColors.inkMuted, bg), greaterThanOrEqualTo(4.5));
      expect(ratio(NatureColors.skyInk, bg), greaterThanOrEqualTo(4.5));
    }
    expect(ratio(NatureColors.primaryForeground, NatureColors.primary), greaterThanOrEqualTo(4.5));
  });

  test('Production web icons use the forest and parchment identity', () {
    final icon = File('assets/branding/sense_app_icon.svg').readAsStringSync();
    final mask = File('assets/branding/sense_app_icon_maskable.svg').readAsStringSync();
    for (final svg in [icon, mask]) {
      expect(svg, contains('#3F6556')); // deep forest tile
      expect(svg, contains('#F3EBDD')); // parchment mark
      expect(svg, contains('#E5AE56')); // ochre centre node
      expect(svg, isNot(contains('#059BE0'))); // old blue gradient gone
    }
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest, contains('"theme_color": "#3F6556"'));
    expect(manifest, contains('"background_color": "#F3EBDD"'));
    expect(manifest, isNot(contains('—')));
  });
}
