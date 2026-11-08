import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/redesign/mood_glyph.dart';
import 'package:mindpulse/presentation/redesign/mood_glyph_data.dart';
import 'package:mindpulse/presentation/redesign/nature_check_in_preview.dart';
import 'package:mindpulse/presentation/redesign/nature_home_preview.dart';
import 'package:mindpulse/presentation/redesign/nature_tokens.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Redesign: the Living Landscapes check-in prototype. Same mood model, step
/// sequence, scales, semantics and honest "not saved" outcome as the
/// production check-in; new visual system with the approved mood symbols.
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

  Future<void> pump(WidgetTester tester,
      {double width = 412,
      double height = 915,
      double scale = 1.0,
      bool motion = false,
      Widget home = const NatureCheckInPreview()}) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !motion);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  NatureCheckInPreviewState state(WidgetTester t) =>
      t.state<NatureCheckInPreviewState>(find.byType(NatureCheckInPreview));
  Finder tile(int v) => find.byKey(ValueKey('mood-$v'));
  BoxDecoration surface(WidgetTester t, int v) =>
      t.widget<AnimatedContainer>(find.byKey(ValueKey('mood-surface-$v'))).decoration! as BoxDecoration;
  double badgeScale(WidgetTester t, int v) =>
      t.widget<AnimatedScale>(find.byKey(ValueKey('mood-check-$v'))).scale;
  Text labelOf(WidgetTester t, int v) =>
      t.widget<Text>(find.descendant(of: tile(v), matching: find.text(labels[v - 1])));

  Future<void> tapText(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  // ---- Mood model --------------------------------------------------------------
  group('Mood model is the production one', () {
    test('Values, order and labels are the production mood model exactly', () {
      // Phase 1: the production model is the public CheckInScreen.moodOptions
      // (it was a private list of maps with emoji before).
      expect(natureMoodOptions, CheckInScreen.moodOptions);
      expect(natureMoodOptions.map((o) => o.value), [1, 2, 3, 4, 5]);
      expect(natureMoodOptions.map((o) => o.label), labels);
    });

    test('Defaults match production (mood 3, stress 2, motivation 3)', () {
      final prod = File('lib/presentation/screens/check_in_screen.dart').readAsStringSync();
      final proto = File('lib/presentation/redesign/nature_check_in_preview.dart').readAsStringSync();
      for (final field in ['_selectedMood', '_perceivedStress', '_motivationLevel', '_currentStep']) {
        final re = RegExp('int $field = (\\d);');
        expect(re.firstMatch(proto)!.group(1), re.firstMatch(prod)!.group(1), reason: field);
      }
    });

    testWidgets('Production check-in now uses the approved symbols, not emoji (Phase 1)',
        (t) async {
      await pump(t, home: const CheckInScreen());
      for (final emoji in ['😔', '🙁', '😐', '🙂', '😄']) {
        expect(find.text(emoji), findsNothing);
      }
      expect(find.byType(MoodGlyph), findsNWidgets(5));
    });
  });

  // ---- Artwork ---------------------------------------------------------------------
  group('Mood symbols', () {
    test('Drawing data matches the approved SVG sources shape for shape', () {
      const files = [
        'mood_1_very_low.svg',
        'mood_2_low.svg',
        'mood_3_neutral.svg',
        'mood_4_good.svg',
        'mood_5_great.svg',
      ];
      for (var v = 1; v <= 5; v++) {
        final svg = File('../docs/redesign/mood-symbols/${files[v - 1]}').readAsStringSync();
        final body = svg.replaceAll(RegExp(r'<defs>.*?</defs>', dotAll: true), '');
        final shapes = RegExp(r'<(path|circle)\s([^>]*?)/>').allMatches(body).map((m) {
          String a(String k) => RegExp('$k="([^"]*)"').firstMatch(m.group(2)!)!.group(1)!;
          if (m.group(1) == 'path') return a('d');
          String g(String k) => double.parse(a(k)).toString().replaceAll(RegExp(r'\.0$'), '');
          return 'circle:${g('cx')},${g('cy')},${g('r')}';
        }).toList();
        expect(moodGlyphLayers[v]!.map((l) => l.path).toList(), shapes, reason: files[v - 1]);
        expect(svg, contains('<title id="mood-$v-t">${labels[v - 1]}</title>'));
      }
    });

    test('Every path parses', () {
      for (final layers in moodGlyphLayers.values) {
        for (final l in layers) {
          expect(parseSvgPath(l.path).getBounds().isEmpty, isFalse, reason: l.path);
          if (l.clip != null) parseSvgPath(l.clip!);
        }
      }
      expect(() => parseSvgPath('M0 0 A1 1 0 0 0 2 2'), throwsFormatException);
    });

    test('Distinguishing features are in the data (not colour alone)', () {
      int strokes(int v, Color c) => moodGlyphLayers[v]!
          .where((l) => l.stroke == c)
          .map((l) => RegExp(r'M').allMatches(l.path).length)
          .fold(0, (a, b) => a + b);
      const rain = Color(0xFF3E6E6A);
      expect(strokes(1, rain), 9, reason: 'Very Low: nine heavy rain strokes');
      expect(strokes(2, rain), 3, reason: 'Low: three drizzle marks');
      for (final v in [3, 4, 5]) {
        expect(strokes(v, rain), 0, reason: 'no rain in $v');
      }
      bool hasSun(int v) => moodGlyphLayers[v]!.any((l) => l.path.startsWith('circle:') && l.stroke != null);
      expect([1, 2, 3, 4, 5].map(hasSun), [false, false, false, true, true]);
      int rays(int v) => moodGlyphLayers[v]!
          .where((l) => l.path.contains('Q') && l.fill == const Color(0xFFE5AE56))
          .map((l) => 'Z'.allMatches(l.path).length)
          .fold(0, (a, b) => a + b);
      expect(rays(4), 7, reason: 'Good: partial rays, cloud in front');
      expect(rays(5), 12, reason: 'Great: full ring of rays');
    });

    testWidgets('Glyphs are decorative and paint at every size', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(children: [
          for (var v = 1; v <= 5; v++)
            for (final s in [24.0, 40.0, 60.0]) MoodGlyph(value: v, size: s),
        ]),
      ));
      expect(t.takeException(), isNull);
      expect(find.byType(MoodGlyph), findsNWidgets(15));
      expect(t.getSize(find.byType(MoodGlyph).first), const Size(24, 24));
      expect(find.descendant(of: find.byType(MoodGlyph), matching: find.byType(ExcludeSemantics)),
          findsNWidgets(15));
      handle.dispose();
    });
  });

  // ---- Selection ---------------------------------------------------------------------
  group('Mood selection', () {
    testWidgets('Five tiles in order, Neutral selected by default (real Poppins)', (t) async {
      await t.runAsync(loadPoppins);
      await pump(t);
      final xs = [for (var v = 1; v <= 5; v++) t.getCenter(tile(v)).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      final ys = {for (var v = 1; v <= 5; v++) t.getCenter(tile(v)).dy};
      expect(ys, hasLength(1), reason: 'one row at 412 px');
      expect(state(t).selectedMood, 3);
    });

    for (var v = 1; v <= 5; v++) {
      testWidgets('Selecting ${labels[v - 1]} sets value $v with every selected cue', (t) async {
        await pump(t);
        await t.tap(tile(v));
        await t.pumpAndSettle();
        expect(state(t).selectedMood, v);
        for (var o = 1; o <= 5; o++) {
          final sel = o == v;
          final d = surface(t, o);
          final border = (d.border! as Border).top;
          expect(border.width, sel ? MoodTile.outlineSelected : MoodTile.outline);
          expect(border.color, sel ? NatureColors.forest : NatureColors.borderStrong);
          expect(d.color, sel ? NatureColors.paper : NatureColors.background);
          expect(badgeScale(t, o), sel ? 1.0 : 0.0, reason: 'check badge on $o');
          expect(labelOf(t, o).style!.fontWeight, sel ? FontWeight.w600 : FontWeight.w500);
          expect(labelOf(t, o).style!.color, sel ? NatureColors.ink : NatureColors.inkMuted);
        }
      });
    }

    testWidgets('Accessible names, roles and selected state for all five', (t) async {
      final handle = t.ensureSemantics();
      await pump(t);
      for (var v = 1; v <= 5; v++) {
        expect(
            t.getSemantics(find.bySemanticsLabel('Mood: ${labels[v - 1]}')),
            isSemantics(
                label: 'Mood: ${labels[v - 1]}',
                isButton: true,
                isSelected: v == 3,
                hasSelectedState: true,
                isFocusable: true,
                hasEnabledState: true,
                isEnabled: true,
                hasTapAction: true,
                hasFocusAction: true));
      }
      // The symbol and visible label are not announced separately.
      expect(find.bySemanticsLabel('Neutral'), findsNothing);
      handle.dispose();
    });

    testWidgets('Screen-reader activation selects and announces the new state', (t) async {
      final handle = t.ensureSemantics();
      await pump(t);
      t.semantics.tap(find.semantics.byLabel('Mood: Low'));
      await t.pumpAndSettle();
      expect(state(t).selectedMood, 2);
      expect(t.getSemantics(find.bySemanticsLabel('Mood: Low')), isSemantics(isSelected: true));
      expect(t.getSemantics(find.bySemanticsLabel('Mood: Neutral')), isSemantics(isSelected: false));
      handle.dispose();
    });

    testWidgets('Keyboard: Tab order is back, then moods 1 to 5; Space and Enter select; ring shows',
        (t) async {
      await pump(t);
      String? focusedLabel() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<SenseTappable>()
          ?.semanticLabel;
      final order = <String>[];
      for (var i = 0; i < 6; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        order.add(focusedLabel() ?? '?');
      }
      expect(order, ['Back to Home', for (final l in labels) 'Mood: $l']);

      // Focus is on Great now. Enter selects it; the focus ring is drawn.
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(state(t).selectedMood, 5);
      final ring = t.widget<Container>(find.descendant(
          of: tile(5), matching: find.byKey(const ValueKey('sense-tappable-focus-ring'))));
      final deco = ring.foregroundDecoration! as BoxDecoration;
      expect((deco.border! as Border).top.color, NatureColors.focus);
      expect((deco.border! as Border).top.width, 2.5);
      // The ring is drawn outside the selected outline, not on top of it.
      final ringRect = t.getRect(find.descendant(
          of: tile(5), matching: find.byKey(const ValueKey('sense-tappable-focus-ring'))));
      final surfaceRect = t.getRect(find.byKey(const ValueKey('mood-surface-5')));
      expect(ringRect.left, surfaceRect.left - MoodTile.focusGap);
      expect(ringRect.bottom, surfaceRect.bottom + MoodTile.focusGap);

      // Shift+Tab back to Good and press Space.
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Mood: Good');
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(state(t).selectedMood, 4);
    });

    testWidgets('Selection animates gently when motion is allowed, instantly when reduced',
        (t) async {
      await pump(t, motion: true);
      expect(t.widget<AnimatedScale>(find.byKey(const ValueKey('mood-check-1'))).duration,
          NatureMotion.selection);
      await t.tap(tile(1));
      await t.pump(const Duration(milliseconds: 60));
      final mid = t.widget<AnimatedContainer>(find.byKey(const ValueKey('mood-surface-1')));
      expect(mid.duration, NatureMotion.selection);
      await t.pumpAndSettle();
      expect(state(t).selectedMood, 1);

      await pump(t, motion: false);
      expect(t.widget<AnimatedScale>(find.byKey(const ValueKey('mood-check-1'))).duration,
          Duration.zero);
    });

    testWidgets('Tiles are at least 48 x 48 and fully on screen at every width', (t) async {
      for (final w in [320.0, 360.0, 412.0, 768.0, 1024.0, 1440.0]) {
        await pump(t, width: w);
        for (var v = 1; v <= 5; v++) {
          final r = t.getRect(tile(v));
          expect(r.width, greaterThanOrEqualTo(48), reason: '$w px');
          expect(r.height, greaterThanOrEqualTo(48), reason: '$w px');
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(w));
        }
      }
    });

    testWidgets('Five across from 360 px; an ordered list at 320 px and with large text', (t) async {
      bool oneRow() => {for (var v = 1; v <= 5; v++) t.getCenter(tile(v)).dy}.length == 1;
      bool topToBottom() {
        final ys = [for (var v = 1; v <= 5; v++) t.getCenter(tile(v)).dy];
        return ys.toSet().length == 5 && ys.join() == ([...ys]..sort()).join();
      }

      await t.runAsync(loadPoppins);
      for (final w in [360.0, 412.0, 768.0, 1280.0]) {
        await pump(t, width: w);
        expect(oneRow(), isTrue, reason: '$w px');
      }
      await pump(t, width: 320);
      expect(topToBottom(), isTrue, reason: '320 px');
      await pump(t, width: 412, scale: 2.0);
      expect(topToBottom(), isTrue, reason: '412 px at 2x');
    });
  });

  // ---- Flow --------------------------------------------------------------------------
  group('Check-in flow (same sequence as production)', () {
    testWidgets('Home > Begin today\'s check-in > redesigned check-in > back to Home', (t) async {
      await pump(t, height: 3000, home: const NatureHomePreview());
      await t.tap(find.bySemanticsLabel("Begin today's check-in"));
      await t.pumpAndSettle();
      expect(find.byType(NatureCheckInPreview), findsOneWidget);
      expect(find.byType(CheckInScreen), findsNothing);
      await t.tap(find.byTooltip('Back to Home'));
      await t.pumpAndSettle();
      expect(find.byType(NatureCheckInPreview), findsNothing);
      expect(find.byType(NatureHomePreview), findsOneWidget);
    });

    testWidgets('Step 1 > step 2 > Back keeps answers > finish > honest page > Home', (t) async {
      await pump(t, height: 1600, home: const NatureHomePreview());
      await t.tap(find.bySemanticsLabel("Begin today's check-in"));
      await t.pumpAndSettle();

      expect(find.text('Daily check-in · Step 1 of 2'), findsOneWidget);
      expect(find.text('How are you feeling right now?'), findsOneWidget);
      expect(find.text('How energetic or motivated do you feel to complete tasks today?'),
          findsOneWidget);
      await t.tap(tile(2));
      await t.pumpAndSettle();
      await tapText(t, 'Continue to stress rating');

      expect(state(t).currentStep, 2);
      expect(find.text('Daily check-in · Step 2 of 2'), findsOneWidget);
      expect(find.text('Rate your subjective perceived stress today (adapted EMA subscale).'),
          findsOneWidget);
      await tapText(t, 'Back');
      expect(state(t).currentStep, 1);
      expect(state(t).selectedMood, 2, reason: 'answers kept when going back');
      await tapText(t, 'Continue to stress rating');
      await tapText(t, 'Finish check-in');

      expect(find.text('Check-in complete, not saved'), findsOneWidget);
      expect(find.textContaining('your answers are not saved'), findsOneWidget);
      await tapText(t, 'Return to Home');
      expect(find.byType(NatureCheckInPreview), findsNothing);
      expect(find.byType(NatureHomePreview), findsOneWidget);
    });

    testWidgets('Sliders: production names, 1 to 5 in steps of 1, read as "n of 5"', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, height: 1600);
      final mot = find.bySemanticsLabel('Motivation or energy level');
      expect(t.getSemantics(mot), isSemantics(value: '3 of 5', isSlider: true));
      final s1 = t.widget<Slider>(find.byType(Slider));
      expect([s1.min, s1.max, s1.divisions], [1, 5, 4]);
      t.semantics.performAction(
          find.semantics.byLabel('Motivation or energy level'), SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(t.getSemantics(mot), isSemantics(value: '4 of 5'));

      await tapText(t, 'Continue to stress rating');
      // "Perceived stress" is also the step heading; check the slider's own node.
      expect(t.getSemantics(find.byType(Slider)),
          isSemantics(label: 'Perceived stress', value: '2 of 5', isSlider: true));
      expect(t.getSemantics(find.text('Perceived stress')), isSemantics(isHeader: true));
      final s2 = t.widget<Slider>(find.byType(Slider));
      expect([s2.min, s2.max, s2.divisions], [1, 5, 4]);
      handle.dispose();
    });
  });

  // ---- Honesty ------------------------------------------------------------------------
  List<String> allText(WidgetTester t) => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '')
      .toList();

  testWidgets('Honest wording on every step: nothing claims to be saved, no clinical claims, '
      'no em dashes', (t) async {
    await pump(t, height: 1800);
    final seen = <String>[...allText(t)];
    await tapText(t, 'Continue to stress rating');
    seen.addAll(allText(t));
    await tapText(t, 'Finish check-in');
    seen.addAll(allText(t));

    final all = seen.join('\n');
    expect(all, isNot(contains('—')), reason: 'em dash in user-facing text');
    for (final s in RegExp(r'.{0,12}saved', caseSensitive: false).allMatches(all)) {
      expect(s.group(0)!.toLowerCase(), contains('not saved'), reason: s.group(0));
    }
    for (final bad in ['diagnos', 'detected', 'successfully', 'your stress level', 'clinically']) {
      expect(all.toLowerCase(), isNot(contains(bad)));
    }
    expect(all, contains('optional'));
    expect(all, contains('Planned, not active yet'));
  });

  // ---- Responsive + accessibility matrix (real Poppins) ------------------------------
  List<String> semanticsProblems(WidgetTester tester) {
    final problems = <String>[];
    void visit(SemanticsNode n) {
      if (!n.isMergedIntoParent) {
        final d = n.getSemanticsData();
        final f = d.flagsCollection;
        final tap = d.hasAction(SemanticsAction.tap);
        final name = d.label.split('\n').first;
        if (f.isButton && f.isEnabled != Tristate.isFalse && !tap) problems.add('no tap action: "$name"');
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

  Future<void> checkPage(WidgetTester t, Set<String> found) async {
    final v = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    for (var i = 0; i < 60; i++) {
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
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: all three steps fit, no broken '
          'words, scroll to the end, 48 px labelled focusable targets', (t) async {
        await t.runAsync(loadPoppins);
        final handle = t.ensureSemantics();
        final height = width >= NatureBreakpoints.desktop ? 900.0 : 780.0;
        await pump(t, width: width, height: height, scale: scale);
        final found = <String>{};
        await checkPage(t, found);
        await tapText(t, 'Continue to stress rating');
        await checkPage(t, found);
        await tapText(t, 'Finish check-in');
        await checkPage(t, found);
        expect(found, isEmpty, reason: found.join('\n'));
        expect(t.takeException(), isNull);
        handle.dispose();
      });
    }
  }

  testWidgets('Text contrast guideline passes on both steps (real Poppins)', (t) async {
    await t.runAsync(loadPoppins);
    final handle = t.ensureSemantics();
    await pump(t, height: 1800);
    await expectLater(t, meetsGuideline(textContrastGuideline));
    await tapText(t, 'Continue to stress rating');
    await expectLater(t, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  test('Contrast of the selection cues and slider colours', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(ratio(NatureColors.forest, NatureColors.paper), greaterThanOrEqualTo(3)); // selected outline
    expect(ratio(NatureColors.borderStrong, NatureColors.background), greaterThanOrEqualTo(3)); // unselected
    expect(ratio(NatureColors.ink, NatureColors.paper), greaterThanOrEqualTo(4.5)); // selected label
    expect(ratio(NatureColors.inkMuted, NatureColors.background), greaterThanOrEqualTo(4.5)); // unselected label
    expect(ratio(NatureColors.coralInk, NatureColors.paper), greaterThanOrEqualTo(4.5)); // warm value text
    expect(ratio(NatureColors.focus, NatureColors.background), greaterThanOrEqualTo(3)); // focus ring
  });
}
