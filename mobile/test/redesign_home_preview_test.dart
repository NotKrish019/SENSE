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
import 'package:mindpulse/presentation/redesign/nature_check_in_preview.dart';
import 'package:mindpulse/presentation/redesign/nature_home_preview.dart';
import 'package:mindpulse/presentation/redesign/nature_illustrations.dart';
import 'package:mindpulse/presentation/redesign/nature_tokens.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/insight_detail_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/voice_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';

/// Redesign stage 3: the nature Home prototype. Same behaviour and honesty
/// as the current Home, new visual system, accessibility kept.
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

  // Reduced motion by default: the ambient scene loops forever otherwise, and
  // static layouts are what these checks are about. Motion has its own test.
  Future<void> pump(WidgetTester tester,
      {double width = 412, double height = 915, double scale = 1.0, bool motion = false}) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !motion);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    if (motion) {
      await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const NatureHomePreview()));
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const NatureHomePreview()));
    await tester.pumpAndSettle();
  }

  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  group('Nature tokens: contrast', () {
    const surfaces = {
      'background': NatureColors.background,
      'surface': NatureColors.surface,
      'surfaceQuiet': NatureColors.surfaceQuiet,
    };
    for (final s in surfaces.entries) {
      test('text on ${s.key} meets 4.5:1', () {
        for (final t in [
          NatureColors.textPrimary,
          NatureColors.textSecondary,
          NatureColors.forest,
          NatureColors.skyInk,
          NatureColors.coralInk,
          NatureColors.ochreInk,
        ]) {
          expect(ratio(t, s.value), greaterThanOrEqualTo(4.5), reason: '$t on ${s.key}');
        }
      });
    }
    test('Button text, focus ring and control outline', () {
      expect(ratio(NatureColors.primaryForeground, NatureColors.primary), greaterThanOrEqualTo(4.5));
      expect(ratio(NatureColors.focus, NatureColors.background), greaterThanOrEqualTo(3.0));
      expect(ratio(NatureColors.focus, NatureColors.surface), greaterThanOrEqualTo(3.0));
      expect(ratio(NatureColors.borderStrong, NatureColors.surface), greaterThanOrEqualTo(3.0));
      expect(ratio(NatureColors.forest, NatureColors.surface), greaterThanOrEqualTo(3.0),
          reason: 'selected-tab indicator and icons');
    });
  });

  group('Home preview behaviour (same destinations as the current Home)', () {
    testWidgets('Honest content: no baseline yet, sample data marked, inputs described truthfully',
        (tester) async {
      await pump(tester, height: 3000);
      expect(find.text(PrototypeCopy.noBaselineTitle), findsOneWidget);
      expect(find.text(PrototypeCopy.noBaselineDescription), findsOneWidget);
      expect(find.text(PrototypeCopy.sampleDataLabel), findsOneWidget);
      expect(find.textContaining('not based on your data'), findsOneWidget);
      expect(find.textContaining('does not mean one caused the other'), findsOneWidget);
      expect(find.text('Write freely · not saved yet'), findsOneWidget);
      expect(find.text('Planned · not built, no audio recorded'), findsOneWidget);
      expect(find.text('Manual entry · no health app connected'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+\s?%')), findsNothing, reason: 'no invented scores');
    });

    testWidgets('Illustration is decorative (no semantics)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      expect(find.byType(LivingLandscape), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(LivingLandscape), matching: find.byType(ExcludeSemantics)),
          findsWidgets);
      handle.dispose();
    });

    testWidgets('Primary action and centre + open Check-in', (tester) async {
      await pump(tester, height: 3000);
      await tester.tap(find.bySemanticsLabel("Begin today's check-in"));
      await tester.pumpAndSettle();
      expect(find.byType(NatureCheckInPreview), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New daily check-in'));
      await tester.pumpAndSettle();
      expect(find.byType(NatureCheckInPreview), findsOneWidget);
    });

    for (final (label, type) in [
      ('Journal', JournalScreen),
      ('Sleep', SleepScreen),
      ('Workload', WorkloadScreen),
      ('Voice', VoiceScreen),
      ('Activity', ActivityScreen),
    ]) {
      testWidgets('"$label" row opens the existing screen (via semantics tap)', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, height: 3000);
        tester.semantics.tap(find.semantics.byLabel(RegExp('^$label\\. ')));
        await tester.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);
        handle.dispose();
      });
    }

    testWidgets('Status link → Insights tab; example → Insight detail; shield → Profile',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, height: 3000);
      tester.semantics.tap(find.semantics.byLabel('About your insights'));
      await tester.pumpAndSettle();
      expect(find.text('Longitudinal insights'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Insights tab')),
          isSemantics(isSelected: true, isButton: true));
      tester.semantics.tap(find.semantics.byLabel('Home tab'));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('View example details'));
      await tester.pumpAndSettle();
      expect(find.byType(InsightDetailScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('Profile, privacy and support contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Profile & settings'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Keyboard: Tab reaches the primary action and Enter opens Check-in',
        (tester) async {
      await pump(tester);
      var reached = false;
      for (var i = 0; i < 30 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        reached = FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<Semantics>()
                ?.properties
                .label ==
            "Begin today's check-in";
      }
      expect(reached, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(NatureCheckInPreview), findsOneWidget);
    });
  });

  // ---- Accessibility + layout matrix with the real bundled Poppins --------
  List<String> semanticsProblems(WidgetTester tester) {
    final problems = <String>[];
    void visit(SemanticsNode n) {
      if (!n.isMergedIntoParent) {
        final d = n.getSemanticsData();
        final f = d.flagsCollection;
        final tap = d.hasAction(SemanticsAction.tap);
        final name = d.label.split('\n').first;
        if ((f.isButton) && f.isEnabled != Tristate.isFalse && !tap) {
          problems.add('no tap action: "$name"');
        }
        if (tap && d.label.trim().isEmpty && d.tooltip.trim().isEmpty) {
          problems.add('unlabelled tap target at ${n.rect}');
        }
        if (tap && f.isFocused == Tristate.none) problems.add('not focusable: "$name"');
      }
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    return problems;
  }

  List<String> brokenWords() {
    final problems = <String>[];
    for (final element in find.byType(RichText).evaluate()) {
      final p = element.renderObject as RenderParagraph;
      if (!p.hasSize || p.maxLines == 1 || !p.softWrap) continue;
      final span = p.text;
      if (span is! TextSpan || (span.children?.isNotEmpty ?? false)) continue;
      for (final word in (span.text ?? '').split(RegExp(r'\s+|(?<=-)'))) {
        if (word.length < 2) continue;
        final tp = TextPainter(
          text: TextSpan(text: word, style: span.style),
          textDirection: TextDirection.ltr,
          textScaler: p.textScaler,
          maxLines: 1,
        )..layout();
        if (tp.width > p.size.width + 0.5) problems.add('"$word" in "${span.text}"');
        tp.dispose();
      }
    }
    return problems;
  }

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: no overflow or broken words, '
          'scrolls to the end, 48 px targets, labelled focusable controls', (tester) async {
        await tester.runAsync(loadPoppins);
        final handle = tester.ensureSemantics();
        await pump(tester, width: width, height: 780, scale: scale);
        final found = <String>{...brokenWords()};
        final v = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        for (var i = 0; i < 80; i++) {
          final pos = tester.state<ScrollableState>(v.first).position;
          if (pos.pixels >= pos.maxScrollExtent - 0.5) break;
          await tester.drag(v.first, const Offset(0, -300), warnIfMissed: false);
          await tester.pumpAndSettle();
          found.addAll(brokenWords());
          expect(semanticsProblems(tester), isEmpty);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }
        final pos = tester.state<ScrollableState>(v.first).position;
        expect(pos.pixels, closeTo(pos.maxScrollExtent, 1.0), reason: 'did not reach the end');
        expect(found, isEmpty, reason: found.join('\n'));
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  }

  group('Motion and depth', () {
    testWidgets('Ambient scene animates (layers move) when motion is allowed', (tester) async {
      await pump(tester, motion: true);
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0),
          reason: 'ambient loop should be ticking');
      // Clouds travel by changing their position inside the scene; painters
      // for the sun, birds, plants and water repaint from the same clock.
      List<double> cloudLefts() => tester
          .widgetList<Positioned>(find.descendant(
              of: find.byType(LivingLandscape), matching: find.byType(Positioned)))
          .map((p) => p.left ?? 0)
          .toList();
      final before = cloudLefts();
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 40));
      final after = cloudLefts();
      expect(after, isNot(equals(before)), reason: 'clouds should drift');
      // Independent speeds and directions: at least one cloud moved right and
      // one moved left.
      final deltas = [for (var i = 0; i < before.length; i++) after[i] - before[i]];
      expect(deltas.any((d) => d > 1), isTrue);
      expect(deltas.any((d) => d < -1), isTrue);
      // Leave the screen: animation must stop with the widget.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Reduced motion: nothing ticks, layout is static', (tester) async {
      await pump(tester);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('Hidden tabs pause the scene (TickerMode)', (tester) async {
      await pump(tester, motion: true);
      await tester.tap(find.text('Insights').last);
      // Let the tap's ink ripple and the tab indicator animation finish.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Longitudinal insights'), findsOneWidget);
      expect(SchedulerBinding.instance.transientCallbackCount, 0,
          reason: 'the Home scene is offstage, so its ticker should be muted');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Responsive composition', () {
    for (final width in [768.0, 1024.0, 1280.0, 1440.0]) {
      testWidgets('${width.toInt()} px: correct navigation, capped width, no overflow',
          (tester) async {
        await tester.runAsync(loadPoppins);
        final handle = tester.ensureSemantics();
        await pump(tester, width: width, height: 900);
        final desktop = width >= 1024;
        expect(find.byType(NatureTopBar), desktop ? findsOneWidget : findsNothing);
        expect(find.byType(NatureBottomBar), desktop ? findsNothing : findsOneWidget);
        // The landscape is immersive (full width); text stays at a reading
        // width and the journal sheet overlaps the scene.
        final scene = tester.getRect(find.byType(LivingLandscape));
        expect(scene.width, closeTo(width, 1));
        final greeting = tester.getRect(find.textContaining(RegExp(r'^Good (morning|afternoon|evening)$')));
        expect(greeting.left, greaterThanOrEqualTo(desktop ? 39 : 19));
        final status = tester.getRect(find.text(PrototypeCopy.noBaselineDescription));
        expect(status.width, lessThanOrEqualTo(desktop ? 470 : 640));
        if (desktop) {
          final cta = tester.getRect(find.bySemanticsLabel("Begin today's check-in"));
          expect(cta.bottom, lessThan(900), reason: 'primary action visible without scrolling');
          expect(cta.top, lessThan(scene.bottom), reason: 'the journal sheet floats over the scene');
          expect(cta.right, lessThan(width * 0.5), reason: 'asymmetric: sheet on the left, scene open on the right');
          // The six inputs form an open ruled index: 3 columns at 1240 px+, else 2.
          final lefts = <double>{
            for (final t in ['Check-in', 'Journal', 'Sleep', 'Workload', 'Voice', 'Activity'])
              tester.getRect(find.bySemanticsLabel(RegExp('^$t\\. '))).left.roundToDouble()
          };
          expect(lefts.length, width >= 1240 ? 3 : 2);
          expect(tester.getSemantics(find.bySemanticsLabel('Home tab')),
              isSemantics(isSelected: true, isButton: true, hasTapAction: true, isFocusable: true));
        }
        expect(semanticsProblems(tester), isEmpty);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }

    testWidgets('Desktop navigation: tabs switch and New check-in opens Check-in', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, width: 1280, height: 900);
      tester.semantics.tap(find.semantics.byLabel('Insights tab'));
      await tester.pumpAndSettle();
      expect(find.text('Longitudinal insights'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('New daily check-in'));
      await tester.pumpAndSettle();
      expect(find.byType(NatureCheckInPreview), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Desktop at 2x text still fits (real Poppins)', (tester) async {
      await tester.runAsync(loadPoppins);
      await pump(tester, width: 1024, height: 900, scale: 2.0);
      expect(tester.takeException(), isNull);
      expect(brokenWords(), isEmpty);
    });
  });

  testWidgets('Text contrast guideline passes on the full preview (real Poppins)', (tester) async {
    await tester.runAsync(loadPoppins);
    final handle = tester.ensureSemantics();
    await pump(tester, height: 3000);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
