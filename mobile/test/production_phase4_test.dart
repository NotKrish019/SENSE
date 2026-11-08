import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/nature/input_bands.dart';
import 'package:mindpulse/presentation/nature/nature_widgets.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/voice_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Phase 4: production Voice and Physical activity in the Living Landscapes
/// design. Voice is planned, not built: no recorder, timer or waveform.
/// Activity is manual entry only: Health Connect is not connected.
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

  Future<void> pump(WidgetTester t, Widget home,
      {double width = 412, double height = 915, double scale = 1.0, bool reduce = true}) async {
    t.view.physicalSize = Size(width * 3, height * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await t.pumpAndSettle();
  }

  Future<void> pumpPushed(WidgetTester t, Widget screen, {double height = 915}) async {
    await pump(
      t,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      ),
      height: height,
    );
    await t.tap(find.text('open'));
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
      'successfully',
      'has been saved',
      'synced',
      'is recording',
      'recording now',
      'analysing your',
      'your stress level',
      'emotion detected',
      'diagnos',
      'risk score',
      'heart rate',
    ]) {
      expect(all.toLowerCase(), isNot(contains(bad)), reason: bad);
    }
  }

  List<String> tappableLabels(WidgetTester t) => find
      .byType(SenseTappable)
      .evaluate()
      .map((e) => (e.widget as SenseTappable).semanticLabel ?? '')
      .toList();

  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<SenseTappable>()
      ?.semanticLabel;

  // ---- Voice -------------------------------------------------------------------------
  group('Production Voice (planned, not built)', () {
    testWidgets('Explicit unavailable state; research purpose and planned steps', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const VoiceScreen(), height: 2600);
      expect(find.byType(EchoBand), findsOneWidget);
      expect(find.text('Voice check-in'), findsOneWidget);
      expect(
          find.bySemanticsLabel(RegExp(r'^Planned · not built\. Not available in this prototype\. There is no '
              r'recording control\. The microphone is never used and no microphone permission is requested\. '
              r'Nothing is recorded, analysed or saved\.$')),
          findsOneWidget);
      expect(find.textContaining('not validated indicators of stress or emotion'), findsOneWidget);
      expect(find.text('Planned design, not yet built.'), findsOneWidget);
      expect(find.textContaining('no background listening'), findsOneWidget);
      expect(find.text('"${VoiceScreen.suggestedPrompt}"'), findsOneWidget);
      expect(find.textContaining('converted on the device to acoustic features'), findsOneWidget);
      expectHonest(allText(t));
      h.dispose();
    });

    testWidgets('No recorder: no mic button, timer, waveform, slider or result', (t) async {
      await pump(t, const VoiceScreen(), height: 2600);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(find.textContaining('Demo'), findsNothing);
      expect(find.textContaining(RegExp(r'\d\d:\d\d')), findsNothing);
      // The only controls: the back control, the consent link and Back.
      expect(tappableLabels(t).toSet(), {'Back', 'Review data and consent preferences'});
      expect(tappableLabels(t).length, 3);
      final before = allText(t);
      await t.pump(const Duration(seconds: 5));
      expect(allText(t), before, reason: 'nothing changes over time');
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('Consent preference is shown, follows the shared state and opens the consent screen',
        (t) async {
      await pump(t, const VoiceScreen(), height: 2600);
      expect(find.textContaining('Voice is off in your preferences (not saved)'), findsOneWidget);
      ConsentPreferences.instance.setEnabled(InputModality.voice, true);
      await t.pumpAndSettle();
      expect(find.textContaining('Voice is on in your preferences (not saved)'), findsOneWidget);
      expect(find.textContaining('it does not start any recording'), findsOneWidget);
      await tapVisible(t, find.text('Review data and consent preferences'));
      expect(find.byType(ConsentScreen), findsOneWidget);
    });

    testWidgets('Keyboard: Back control, consent link, Back button; Enter activates', (t) async {
      await pumpPushed(t, const VoiceScreen(), height: 2600);
      final order = <String?>[];
      for (var i = 0; i < 3; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        order.add(focusedLabel());
      }
      expect(order, ['Back', 'Review data and consent preferences', 'Back']);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(VoiceScreen), findsNothing, reason: 'Back button pops');
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('Back control returns to the previous screen', (t) async {
      await pumpPushed(t, const VoiceScreen());
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byType(VoiceScreen), findsNothing);
    });
  });

  // ---- Activity ----------------------------------------------------------------------
  group('Production Physical activity (manual entry only)', () {
    testWidgets('Manual fields keep their ranges, defaults and spoken values', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      expect(find.byType(TrailBand), findsOneWidget);
      expect(find.text('Physical activity'), findsOneWidget);
      expect(find.bySemanticsLabel('Your entry (manual): 6,800 steps, 35 active minutes'), findsOneWidget);
      final sliders = t.widgetList<Slider>(find.byType(Slider)).toList();
      expect([for (final s in sliders) (s.min, s.max, s.value)],
          [(1000.0, 20000.0, 6800.0), (0.0, 120.0, 35.0)]);
      expect(t.getSemantics(find.bySemanticsLabel('Steps')).getSemanticsData().value, '6,800 steps');
      expect(t.getSemantics(find.bySemanticsLabel('Active minutes')).getSemanticsData().value, '35 minutes');
      expect(find.textContaining('Nothing is read from a phone, watch or health app'), findsOneWidget);
      expect(find.text(PrototypeCopy.notStoredYet), findsOneWidget);
      expectHonest(allText(t));
      h.dispose();
    });

    testWidgets('Sliders change the values and the summary follows', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      t.semantics.performAction(find.semantics.byLabel('Active minutes'), SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Active minutes')).getSemanticsData().value, '40 minutes');
      expect(find.bySemanticsLabel(RegExp(r'40 active minutes$')), findsOneWidget);
      t.semantics.performAction(find.semantics.byLabel('Steps'), SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Your entry \(manual\): 7,[0-9]{3} steps')), findsOneWidget);
      h.dispose();
    });

    testWidgets('Health Connect is shown as not connected; nothing to switch on', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      expect(find.bySemanticsLabel('Manual entry: Available · not saved'), findsOneWidget);
      expect(find.bySemanticsLabel('Health Connect: Not connected · not available in this prototype'),
          findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('No permission is requested and no activity data is read'), findsOneWidget);
      expect(find.textContaining('no GPS or background location tracking'), findsOneWidget);
      expect(tappableLabels(t).toSet(), {'Back', 'Save Activity Entry'},
          reason: 'no connect or permission control');
      h.dispose();
    });

    testWidgets('Save is honest', (t) async {
      await pump(t, const ActivityScreen());
      await tapVisible(t, find.text('Save Activity Entry'));
      expect(find.text(PrototypeCopy.notSaved('activity entry')), findsOneWidget);
      expectHonest(allText(t));
    });

    testWidgets('Keyboard: Back, the two sliders, then Save by Enter', (t) async {
      await pumpPushed(t, const ActivityScreen(), height: 2600);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Back');
      for (var i = 0; i < 2; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Slider>(), isNotNull);
      }
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(find.text('40 minutes'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Save Activity Entry');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text(PrototypeCopy.notSaved('activity entry')), findsOneWidget);
    });
  });

  // ---- Steps: the spoken value is exactly the displayed value -------------------------
  group('Activity steps slider: exact accessible value (Phase 4 correction)', () {
    SemanticsData steps(WidgetTester t) => t.getSemantics(find.bySemanticsLabel('Steps')).getSemanticsData();
    SemanticsData minutes(WidgetTester t) =>
        t.getSemantics(find.bySemanticsLabel('Active minutes')).getSemanticsData();
    // The value text shown above the slider (the summary repeats it).
    bool shown(String v) => find.text(v).evaluate().length == 2;
    double sliderValue(WidgetTester t, int i) => t.widgetList<Slider>(find.byType(Slider)).elementAt(i).value;
    bool onGrid(double v) => ((v - 1000) / 500) == ((v - 1000) / 500).roundToDouble();

    Future<void> focusSlider(WidgetTester t, int i) async {
      final node = t.widgetList<Slider>(find.byType(Slider)).elementAt(i).focusNode!;
      node.requestFocus();
      await t.pumpAndSettle();
    }

    testWidgets('1-2. Initially 6,800 is displayed, held and announced (semantics tree)', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      expect(shown('6,800 steps'), isTrue);
      expect(sliderValue(t, 0), 6800.0, reason: 'thumb at the real value, not snapped');
      final d = steps(t);
      expect(d.value, '6,800 steps');
      expect(d.flagsCollection.isSlider, isTrue);
      expect(d.increasedValue, '7,000 steps');
      expect(d.decreasedValue, '6,500 steps');
      expect(d.hasAction(SemanticsAction.increase) && d.hasAction(SemanticsAction.decrease), isTrue);
      h.dispose();
    });

    testWidgets('3. Touch: tapping and dragging snap to the 500 grid; shown and spoken agree', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      final r = t.getRect(find.byType(Slider).first);
      await t.tapAt(Offset(r.left + r.width * 0.5, r.center.dy));
      await t.pumpAndSettle();
      var v = sliderValue(t, 0);
      expect(onGrid(v), isTrue, reason: '$v');
      expect(v, isNot(6800.0));
      var label = '${_fmt(v)} steps';
      expect(steps(t).value, label);
      expect(shown(label), isTrue);

      await t.drag(find.byType(Slider).first, Offset(-r.width * 0.2, 0));
      await t.pumpAndSettle();
      v = sliderValue(t, 0);
      expect(onGrid(v), isTrue, reason: '$v');
      label = '${_fmt(v)} steps';
      expect(steps(t).value, label);
      expect(shown(label), isTrue);
      h.dispose();
    });

    testWidgets('4. Keyboard: arrows move to the next grid value; shown and spoken agree', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      await focusSlider(t, 0);
      expect(steps(t).flagsCollection.isFocused, Tristate.isTrue);
      for (final (key, expected) in [
        (LogicalKeyboardKey.arrowRight, '7,000 steps'),
        (LogicalKeyboardKey.arrowRight, '7,500 steps'),
        (LogicalKeyboardKey.arrowUp, '8,000 steps'),
        (LogicalKeyboardKey.arrowLeft, '7,500 steps'),
        (LogicalKeyboardKey.arrowDown, '7,000 steps'),
      ]) {
        await t.sendKeyEvent(key);
        await t.pumpAndSettle();
        expect(steps(t).value, expected);
        expect(shown(expected), isTrue);
      }
      // From the default, one step down goes to 6,500.
      await pump(t, const ActivityScreen(), height: 2600);
      await focusSlider(t, 0);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(steps(t).value, '6,500 steps');
      expect(shown('6,500 steps'), isTrue);
      h.dispose();
    });

    testWidgets('Screen-reader increase / decrease actions match the previews', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      t.semantics.performAction(find.semantics.byLabel('Steps'), SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(steps(t).value, '7,000 steps');
      expect(shown('7,000 steps'), isTrue);
      t.semantics.performAction(find.semantics.byLabel('Steps'), SemanticsAction.decrease);
      await t.pumpAndSettle();
      expect(steps(t).value, '6,500 steps');
      h.dispose();
    });

    testWidgets('5. Range and step unchanged: stops at 1,000 and 20,000, always on the grid', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      final s = t.widget<Slider>(find.byType(Slider).first);
      expect((s.min, s.max), (1000.0, 20000.0));
      await focusSlider(t, 0);
      for (var i = 0; i < 45; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump();
        expect(onGrid(sliderValue(t, 0)), isTrue);
      }
      await t.pumpAndSettle();
      expect(steps(t).value, '20,000 steps');
      expect(steps(t).hasAction(SemanticsAction.increase), isFalse);
      for (var i = 0; i < 45; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(steps(t).value, '1,000 steps');
      expect(steps(t).hasAction(SemanticsAction.decrease), isFalse);
      h.dispose();
    });

    testWidgets('6. Active minutes unchanged: 0 to 120 in steps of 5, default 35', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const ActivityScreen(), height: 2600);
      expect(minutes(t).value, '35 minutes');
      expect((minutes(t).increasedValue, minutes(t).decreasedValue), ('40 minutes', '30 minutes'));
      await focusSlider(t, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(minutes(t).value, '30 minutes');
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'30 active minutes$')), findsOneWidget);
      expect(steps(t).value, '6,800 steps', reason: 'steps untouched');
      h.dispose();
    });
  });

  // ---- Shared -------------------------------------------------------------------------
  final screens = <String, Widget Function()>{
    'Voice': () => const VoiceScreen(),
    'Activity': () => const ActivityScreen(),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key}: nothing animates, with or without reduced motion', (t) async {
      for (final reduce in [false, true]) {
        await pump(t, e.value(), reduce: reduce); // pumpAndSettle would time out otherwise
        expect(t.binding.hasScheduledFrame, isFalse);
      }
    });
  }

  testWidgets('Desktop: each page floats as a centred sheet over its own landscape', (t) async {
    for (final screen in screens.values) {
      await pump(t, screen(), width: 1280, height: 900);
      final sheet = t.getRect(find.byType(NatureJournalSheet));
      expect(sheet.width, lessThanOrEqualTo(680));
      expect((sheet.center.dx - 640).abs(), lessThan(1));
    }
  });

  // ---- Responsive + accessibility matrix (real Poppins) --------------------------------
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
        final adjustable = d.hasAction(SemanticsAction.increase) || d.hasAction(SemanticsAction.decrease);
        if (adjustable && d.label.trim().isEmpty) problems.add('unnamed slider ${n.rect}');
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

  Future<void> audit(WidgetTester t, Set<String> found) async {
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
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: Voice and Activity fit, no broken '
          'words, labelled 48 px targets', (t) async {
        await t.runAsync(loadPoppins);
        final h = t.ensureSemantics();
        final height = width >= 1024 ? 900.0 : 780.0;
        final found = <String>{};
        for (final e in screens.entries) {
          await pump(t, e.value(), width: width, height: height, scale: scale);
          await audit(t, found);
        }
        expect(found, isEmpty, reason: found.join('\n'));
        expect(t.takeException(), isNull);
        h.dispose();
      });
    }
  }

  testWidgets('Text contrast guideline passes on both screens (real Poppins)', (t) async {
    await t.runAsync(loadPoppins);
    final h = t.ensureSemantics();
    for (final e in screens.entries) {
      await pump(t, e.value(), height: 3400);
      await expectLater(t, meetsGuideline(textContrastGuideline), reason: e.key);
    }
    h.dispose();
  });
}

String _fmt(double v) {
  final str = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) b.write(',');
    b.write(str[i]);
  }
  return b.toString();
}
