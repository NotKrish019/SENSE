import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/core/theme/nature_tokens.dart';
import 'package:mindpulse/presentation/nature/input_bands.dart';
import 'package:mindpulse/presentation/nature/nature_widgets.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Phase 3: production Journal, Sleep and Workload in the Living Landscapes
/// design. Behaviour, defaults, ranges and honest messages are unchanged.
void main() {
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

  /// Pushes [screen] over a launcher so Back can be tested.
  Future<void> pumpPushed(WidgetTester t, Widget screen) async {
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
      'saved to',
      'synced',
      'diagnos',
      'risk score',
      'from your device',
      'tracker connected',
    ]) {
      expect(all.toLowerCase(), isNot(contains(bad)), reason: bad);
    }
  }

  SemanticsNode node(WidgetTester t, Pattern label) => t.getSemantics(find.bySemanticsLabel(label));
  bool enabled(SemanticsNode n) => n.getSemanticsData().flagsCollection.isEnabled != Tristate.isFalse;
  String? focusedLabel() => FocusManager.instance.primaryFocus?.context
      ?.findAncestorWidgetOfExactType<SenseTappable>()
      ?.semanticLabel;

  // ---- Journal -----------------------------------------------------------------------
  group('Production Journal', () {
    testWidgets('Writing page: prompt, named field, counters and honest notes', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const JournalScreen(), height: 2000);
      expect(find.byType(OrchardBand), findsOneWidget);
      expect(find.text('Daily journal'), findsOneWidget);
      expect(find.text('What moments, challenges, or thoughts stood out for you today?'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Journal reflection')), findsOneWidget);
      expect(find.textContaining('your text stays on this screen only and is not saved'), findsOneWidget);
      expect(find.text('0 words · 0 chars'), findsOneWidget);
      expect(find.text('Not saved (prototype)'), findsOneWidget);
      expect(find.textContaining('No sentiment or AI analysis runs yet'), findsOneWidget);
      expect(find.text('Support is Available 24/7'), findsNothing);
      expectHonest(allText(t));

      await t.enterText(find.byType(TextField), 'A calm  day outside');
      await t.pumpAndSettle();
      expect(find.text('4 words · 19 chars'), findsOneWidget);
      h.dispose();
    });

    testWidgets('Save and Clear are disabled while empty; Save is honest and keeps the text', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const JournalScreen(), height: 2000);
      expect(enabled(node(t, 'Save Reflection')), isFalse);
      expect(enabled(node(t, 'Clear')), isFalse);
      await t.tap(find.text('Save Reflection'));
      await t.pumpAndSettle();
      expect(find.text(PrototypeCopy.notSaved('journal entry')), findsNothing);

      await t.enterText(find.byType(TextField), 'An example sentence.');
      await t.pumpAndSettle();
      expect(enabled(node(t, 'Save Reflection')), isTrue);
      expect(enabled(node(t, 'Clear')), isTrue);
      await tapVisible(t, find.text('Save Reflection'));
      expect(find.text(PrototypeCopy.notSaved('journal entry')), findsOneWidget);
      expect(find.text('Not saved (prototype only)'), findsOneWidget);
      expect(find.text('An example sentence.'), findsOneWidget, reason: 'text is kept on screen');
      expectHonest(allText(t));
      h.dispose();
    });

    testWidgets('Clear asks first: Cancel keeps the text, Clear removes it', (t) async {
      await pump(t, const JournalScreen(), height: 2000);
      await t.enterText(find.byType(TextField), 'Keep me');
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Clear'));
      expect(find.text('Clear reflection?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);

      await tapVisible(t, find.text('Clear'));
      await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Clear')));
      await t.pumpAndSettle();
      expect(find.text('Keep me'), findsNothing);
      expect(find.text('0 words · 0 chars'), findsOneWidget);
    });

    testWidgets('Crisis phrases show 24/7 support (live region); removing them hides it', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const JournalScreen(), height: 2000);
      await t.enterText(find.byType(TextField), 'Some days I want to die.');
      await t.pumpAndSettle();
      expect(find.text('Support is Available 24/7'), findsOneWidget);
      final all = allText(t);
      for (final n in ['14416 or 1800-891-4416', '1800-599-0019', '+91 9999 666 555']) {
        expect(all, contains(n));
      }
      final banner = t.getSemantics(find.ancestor(
          of: find.text('Support is Available 24/7'),
          matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false))));
      expect(banner.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      await t.enterText(find.byType(TextField), 'A better afternoon.');
      await t.pumpAndSettle();
      expect(find.text('Support is Available 24/7'), findsNothing);
      h.dispose();
    });

    testWidgets('Keyboard: Back, then the writing field, then Save by Enter', (t) async {
      await pumpPushed(t, const JournalScreen());
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Back');
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.widget, isA<Focus>());
      expect(find.byType(EditableText), findsOneWidget);
      final editable = t.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
      await t.enterText(find.byType(TextField), 'Typed text');
      await t.pumpAndSettle();
      // Save is the next control after the field.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focusedLabel(), 'Save Reflection');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text(PrototypeCopy.notSaved('journal entry')), findsOneWidget);
    });

    testWidgets('Back returns to the previous screen', (t) async {
      await pumpPushed(t, const JournalScreen());
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byType(JournalScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  // ---- Sleep -------------------------------------------------------------------------
  group('Production Sleep', () {
    testWidgets('Defaults, order and honest labelling are unchanged', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const SleepScreen(), height: 3000);
      expect(find.byType(DuskBand), findsOneWidget);
      expect(
          find.bySemanticsLabel('Your entry (manual): 7.5 hours, bedtime 11:30 PM, wake time 7:00 AM'),
          findsOneWidget);
      expect(find.textContaining('nothing is read from a device or sleep tracker'), findsOneWidget);
      expect(find.textContaining('it is not calculated from these times'), findsOneWidget);
      // Order: duration, times, rest quality (as before).
      final y = [
        'Total sleep duration',
        'Bedtime and wake time',
        'Subjective rest quality',
        'Example 7-day sleep history',
      ].map((s) => t.getTopLeft(find.text(s)).dy).toList();
      for (var i = 1; i < y.length; i++) {
        expect(y[i], greaterThan(y[i - 1]));
      }
      final slider = t.widget<Slider>(find.byType(Slider));
      expect((slider.min, slider.max, slider.divisions, slider.value), (4.0, 12.0, 16, 7.5));
      expect(node(t, 'Rest quality 4 of 5').getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(find.text(PrototypeCopy.sampleDataLabel), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Example 7-day sleep history, sample data: 7\.2, 6\.8')),
          findsOneWidget);
      expect(find.text(PrototypeCopy.notStoredYet), findsOneWidget);
      expectHonest(allText(t));
      h.dispose();
    });

    testWidgets('Duration slider: named, spoken in hours, half-hour steps', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const SleepScreen(), height: 3000);
      final s = find.bySemanticsLabel('Sleep duration');
      expect(t.getSemantics(s).getSemanticsData().value, '7.5 hours');
      t.semantics.performAction(find.semantics.byLabel('Sleep duration'), SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(t.getSemantics(s).getSemanticsData().value, '8.0 hours');
      expect(find.bySemanticsLabel(RegExp(r'^Your entry \(manual\): 8\.0 hours')), findsOneWidget);
      h.dispose();
    });

    testWidgets('Time fields open the picker; Cancel keeps the value', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const SleepScreen(), height: 3000);
      expect(find.bySemanticsLabel('Bedtime: 11:30 PM. Tap to change.'), findsOneWidget);
      expect(find.bySemanticsLabel('Wake time: 7:00 AM. Tap to change.'), findsOneWidget);
      await tapVisible(t, find.bySemanticsLabel('Bedtime: 11:30 PM. Tap to change.'));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Bedtime: 11:30 PM. Tap to change.'), findsOneWidget);
      h.dispose();
    });

    testWidgets('Rest quality: semantics tap and Space select; states differ by shape', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const SleepScreen(), height: 3000);
      Icon star(int r) => t.widget<Icon>(
          find.descendant(of: find.bySemanticsLabel('Rest quality $r of 5'), matching: find.byType(Icon)));
      expect(star(4).icon, Icons.star_rounded);
      expect(star(2).icon, Icons.star_outline_rounded);
      t.semantics.tap(find.semantics.byLabel('Rest quality 2 of 5'));
      await t.pumpAndSettle();
      expect(star(2).icon, Icons.star_rounded);
      expect(node(t, 'Rest quality 4 of 5').getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
      Focus.of(t.element(find.descendant(
              of: find.bySemanticsLabel('Rest quality 5 of 5'),
              matching: find.byKey(const ValueKey('sense-tappable-focus-ring')))))
          .requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(node(t, 'Rest quality 5 of 5').getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      h.dispose();
    });

    testWidgets('Save is honest', (t) async {
      await pump(t, const SleepScreen());
      await tapVisible(t, find.text('Save Sleep Record'));
      expect(find.text(PrototypeCopy.notSaved('sleep entry')), findsOneWidget);
      expectHonest(allText(t));
    });
  });

  // ---- Workload ----------------------------------------------------------------------
  group('Production Workload', () {
    testWidgets('Defaults, wording and the restating summary', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const WorkloadScreen(), height: 3000);
      expect(find.byType(TerraceBand), findsOneWidget);
      expect(find.text('Workload & demands'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'Your ratings (self-reported): mental demand 3 of 5, effort 3 of 5, 1 deadline'),
          findsOneWidget);
      expect(find.textContaining('nothing is calculated from them'), findsOneWidget);
      expect(find.text('How much mental and perceptual activity was required (thinking, deciding, calculating)?'),
          findsOneWidget);
      expect(find.text('How hard did you have to work to accomplish your level of performance?'), findsOneWidget);
      expect(find.textContaining('next 48 hours'), findsOneWidget);
      // The source note is part of the heading, so the heading never shares
      // the slider's name.
      expect(node(t, 'Mental demand, adapted from NASA-TLX').getSemanticsData().flagsCollection.isHeader,
          isTrue);
      expect(node(t, 'Mental demand').getSemanticsData().value, '3 of 5');
      expect(node(t, 'Effort').getSemanticsData().value, '3 of 5');
      expect(find.text(PrototypeCopy.notStoredYet), findsOneWidget);
      expectHonest(allText(t));
      h.dispose();
    });

    testWidgets('Sliders change the answers; the summary follows', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const WorkloadScreen(), height: 3000);
      t.semantics.performAction(find.semantics.byLabel('Mental demand'), SemanticsAction.increase);
      await t.pumpAndSettle();
      t.semantics.performAction(find.semantics.byLabel('Effort'), SemanticsAction.decrease);
      await t.pumpAndSettle();
      expect(node(t, 'Mental demand').getSemanticsData().value, '4 of 5');
      expect(node(t, 'Effort').getSemanticsData().value, '2 of 5');
      expect(find.bySemanticsLabel(RegExp(r'mental demand 4 of 5, effort 2 of 5, 1 deadline$')), findsOneWidget);
      h.dispose();
    });

    testWidgets('Deadline stepper: labelled, live value, disabled at zero, keyboard', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const WorkloadScreen(), height: 3000);
      expect(find.byTooltip('One fewer deadline'), findsOneWidget);
      expect(find.byTooltip('One more deadline'), findsOneWidget);
      expect(node(t, '1 deadline').getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      t.semantics.tap(find.semantics.byLabel('One fewer deadline'));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('0 deadlines'), findsOneWidget);
      expect(enabled(node(t, 'One fewer deadline')), isFalse);
      Focus.of(t.element(find.descendant(
              of: find.bySemanticsLabel('One more deadline'),
              matching: find.byKey(const ValueKey('sense-tappable-focus-ring')))))
          .requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('2 deadlines'), findsOneWidget);
      expect(enabled(node(t, 'One fewer deadline')), isTrue);
      h.dispose();
    });

    testWidgets('Save is honest; no score or task tracking appears', (t) async {
      await pump(t, const WorkloadScreen());
      await tapVisible(t, find.text('Save Workload Rating'));
      expect(find.text(PrototypeCopy.notSaved('workload rating')), findsOneWidget);
      final all = allText(t).toLowerCase();
      for (final bad in ['score', 'tasks completed', 'productivity', 'index']) {
        expect(all, isNot(contains(bad)), reason: bad);
      }
      expectHonest(allText(t));
    });
  });

  // ---- Shared -------------------------------------------------------------------------
  final screens = <String, Widget Function()>{
    'Journal': () => const JournalScreen(),
    'Sleep': () => const SleepScreen(),
    'Workload': () => const WorkloadScreen(),
  };

  group('Motion', () {
    for (final e in screens.entries) {
      testWidgets('${e.key}: nothing animates continuously, with or without reduced motion', (t) async {
        for (final reduce in [false, true]) {
          await pump(t, e.value(), reduce: reduce); // pumpAndSettle would time out otherwise
          expect(t.binding.hasScheduledFrame, isFalse);
        }
      });
    }

    // Hover and press feedback on the shared buttons, stepper and time
    // fields is covered by test/nature_reduced_motion_test.dart.
  });

  testWidgets('Desktop: each page floats as a centred sheet over its own landscape', (t) async {
    for (final (screen, maxW) in [
      (const JournalScreen() as Widget, 760.0),
      (const SleepScreen() as Widget, 680.0),
      (const WorkloadScreen() as Widget, 680.0),
    ]) {
      await pump(t, screen, width: 1280, height: 900);
      final sheet = t.getRect(find.byType(NatureJournalSheet));
      expect(sheet.width, lessThanOrEqualTo(maxW));
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
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: Journal (with the support '
          'notice), Sleep and Workload fit, no broken words, labelled 48 px targets', (t) async {
        await t.runAsync(loadPoppins);
        final h = t.ensureSemantics();
        final height = width >= 1024 ? 900.0 : 780.0;
        final found = <String>{};
        for (final e in screens.entries) {
          await pump(t, e.value(), width: width, height: height, scale: scale);
          if (e.key == 'Journal') {
            await t.enterText(find.byType(TextField),
                'A long week with several deadlines and late nights. ' * 4 + 'Sometimes I want to die.');
            await t.pumpAndSettle();
            expect(find.text('Support is Available 24/7'), findsOneWidget);
            await t.drag(find.byType(Scrollable).first, const Offset(0, 4000), warnIfMissed: false);
            await t.pumpAndSettle();
          }
          await audit(t, found);
        }
        expect(found, isEmpty, reason: found.join('\n'));
        expect(t.takeException(), isNull);
        h.dispose();
      });
    }
  }

  testWidgets('Text contrast guideline passes on all three screens (real Poppins)', (t) async {
    await t.runAsync(loadPoppins);
    final h = t.ensureSemantics();
    for (final e in screens.entries) {
      await pump(t, e.value(), height: 3400);
      if (e.key == 'Journal') {
        await t.enterText(find.byType(TextField), 'I want to die.');
        await t.pumpAndSettle();
      }
      await expectLater(t, meetsGuideline(textContrastGuideline), reason: e.key);
    }
    h.dispose();
  });

  test('Text colours used by the three screens meet 4.5:1 on their surfaces', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }

    const writingPage = Color(0xFFFFFCF5);
    const supportGround = Color(0xFFF7E9E4);
    for (final (fg, bg) in [
      (NatureColors.ink, writingPage),
      (NatureColors.inkMuted, writingPage),
      (NatureColors.coralInk, supportGround),
      (NatureColors.ink, supportGround),
      (NatureColors.skyInk, NatureColors.sageWash),
      (NatureColors.inkMuted, NatureColors.sageWash),
      (NatureColors.ink, NatureColors.sageWash),
      (NatureColors.skyInk, NatureColors.paper),
      (NatureColors.ochreInk, NatureColors.paper),
      (NatureColors.inkMuted, NatureColors.divider), // disabled button text (exempt, still readable)
    ]) {
      expect(ratio(fg, bg), greaterThanOrEqualTo(fg == NatureColors.inkMuted && bg == NatureColors.divider ? 4.0 : 4.5),
          reason: '$fg on $bg');
    }
  });
}
