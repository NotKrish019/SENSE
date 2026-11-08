import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/core/theme/nature_tokens.dart';
import 'package:mindpulse/presentation/nature/meadow_band.dart';
import 'package:mindpulse/presentation/nature/nature_navigation.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/insight_detail_screen.dart';
import 'package:mindpulse/presentation/screens/insights_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_logo.dart';
import 'package:mindpulse/presentation/widgets/sense_tappable.dart';

/// Phase 2: production Insights, Insight detail and Profile & settings in
/// the Living Landscapes design, plus the Phase 1 follow-ups (pale-sage
/// contrast, forest logo).
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
      {double width = 412, double height = 915, double scale = 1.0}) async {
    t.view.physicalSize = Size(width * 3, height * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    // Home's landscape animates; reduced motion lets pumpAndSettle settle.
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
    for (final bad in ['risk score', 'diagnosed', 'your stress level is', 'detected', 'successfully']) {
      expect(all.toLowerCase(), isNot(contains(bad)), reason: bad);
    }
  }

  // ---- Insights ----------------------------------------------------------------------
  group('Production Insights', () {
    testWidgets('Editorial page with the honest sample notice and sample charts', (t) async {
      await pump(t, const InsightsScreen(isTabRoot: true), height: 3000);
      expect(find.byType(MeadowBand), findsOneWidget);
      expect(find.text('Longitudinal insights'), findsOneWidget);
      expect(find.text(PrototypeCopy.sampleDataTitle), findsOneWidget);
      expect(find.text(InsightsScreen.sampleNotice), findsOneWidget);
      expect(find.textContaining('do not change them yet'), findsOneWidget);
      expect(find.text(PrototypeCopy.sampleDataLabel), findsNWidgets(3)); // one tag per chart
      expect(find.text('Factor comparison: not available yet'), findsOneWidget);
      expect(find.text(PrototypeCopy.noCausalClaim), findsOneWidget);
      expectHonest(allText(t));
    });

    testWidgets('Charts have spoken descriptions; bars keep full day names', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const InsightsScreen(isTabRoot: true), height: 3000);
      expect(find.bySemanticsLabel(RegExp(r'^Sample line chart: an invented week')), findsOneWidget);
      for (final d in ['Monday', 'Wednesday', 'Sunday']) {
        expect(find.bySemanticsLabel('$d, sample bar'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Self-reported rest quality: 4 of 5, sample data'), findsOneWidget);
      h.dispose();
    });

    testWidgets('Day / Week / Month: selected state, hint, Enter and Space', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const InsightsScreen(isTabRoot: true));
      expect(
          t.getSemantics(find.bySemanticsLabel('Week view')),
          isSemantics(
              isSelected: true,
              isButton: true,
              hasTapAction: true,
              isFocusable: true,
              hint: 'Sample charts do not change yet'));
      expect(t.getSemantics(find.bySemanticsLabel('Day view')), isSemantics(isSelected: false));
      // Keyboard: Tab reaches Day first (tab root: no back control).
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      String? focused() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<SenseTappable>()
          ?.semanticLabel;
      expect(focused(), 'Day view');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Day view')), isSemantics(isSelected: true));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(focused(), 'Month view');
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pumpAndSettle();
      expect(t.getSemantics(find.bySemanticsLabel('Month view')), isSemantics(isSelected: true));
      // The sample notice still says the charts do not change.
      expect(find.text(InsightsScreen.sampleNotice), findsOneWidget);
      h.dispose();
    });

    testWidgets('Tab root has no back control; pushed Insights has "Back" that pops', (t) async {
      await pump(t, const InsightsScreen(isTabRoot: true));
      expect(find.byTooltip('Back'), findsNothing);
      await pump(
          t,
          Builder(
              builder: (c) => TextButton(
                  onPressed: () => Navigator.of(c)
                      .push(MaterialPageRoute(builder: (_) => const InsightsScreen())),
                  child: const Text('open'))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byType(InsightsScreen), findsNothing);
    });
  });

  // ---- Insight detail ------------------------------------------------------------------
  group('Production Insight detail', () {
    testWidgets('Keeps sample, correlation, causation, baseline and not-built apart', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const InsightDetailScreen(), height: 3200);
      for (final m in ['Sample observation', 'Correlation', 'Causation', 'Personal baseline', 'Not built yet']) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      for (final heading in [
        'What this example shows',
        'Changing together',
        'Not the same as one causing the other',
        'What a real observation would need',
        'Features that do not exist in this prototype',
        'General well-being ideas',
      ]) {
        expect(t.getSemantics(find.text(heading)), isSemantics(isHeader: true), reason: heading);
      }
      expect(find.text(PrototypeCopy.noBaselineDescription), findsOneWidget);
      expect(find.textContaining('not a treatment'), findsWidgets);
      expect(find.text(PrototypeCopy.sampleDataLabel), findsOneWidget);
      expectHonest(allText(t));
      h.dispose();
    });

    testWidgets('A non-sample observation is labelled as observed, with no sample tag', (t) async {
      await pump(t, const InsightDetailScreen(isSampleData: false), height: 3200);
      expect(find.text('Observed pattern'), findsOneWidget);
      expect(find.text('What changed in your recorded data'), findsOneWidget);
      expect(find.text(PrototypeCopy.sampleDataLabel), findsNothing);
    });

    testWidgets('Back control and Back button both return', (t) async {
      for (final back in ['tooltip', 'button']) {
        await pump(
            t,
            Builder(
                builder: (c) => TextButton(
                    onPressed: () => Navigator.of(c)
                        .push(MaterialPageRoute(builder: (_) => const InsightDetailScreen())),
                    child: const Text('open'))),
            height: 3200);
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        if (back == 'tooltip') {
          await t.tap(find.byTooltip('Back'));
          await t.pumpAndSettle();
        } else {
          await tapVisible(t, find.text('Back'));
        }
        expect(find.byType(InsightDetailScreen), findsNothing, reason: back);
      }
    });
  });

  // ---- Profile & settings --------------------------------------------------------------
  group('Production Profile & settings', () {
    testWidgets('Honest placeholder, support contacts, privacy text and forest logo', (t) async {
      await pump(t, const SettingsScreen(isTabRoot: true), height: 3200);
      expect(find.text('Profile & settings'), findsOneWidget);
      expect(find.text('Profile setup is not available yet'), findsOneWidget);
      expect(find.text('Personal baseline: not started'), findsOneWidget);
      expect(find.textContaining('usr_'), findsNothing);
      final all = allText(t);
      for (final n in ['14416', '1800-599-0019', '+91 9999 666 555']) {
        expect(all, contains(n), reason: n);
      }
      expect(find.text('Your data rights under the DPDP Act 2023.'), findsOneWidget);
      expect(find.textContaining('do not start any data collection'), findsOneWidget);
      final logo = t.widget<SenseLogo>(find.byType(SenseLogo));
      expect(logo.variant, SenseLogoVariant.forestBadge);
      expectHonest(all);
    });

    testWidgets('Consent review opens the consent screen and reflects changes', (t) async {
      await pump(t, const SettingsScreen(), height: 3200);
      expect(find.text('Currently on: none (not saved)'), findsOneWidget);
      await tapVisible(t, find.text('Review data and consent preferences'));
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(t.widget<ConsentScreen>(find.byType(ConsentScreen)).isSettingsMode, isTrue);
      ConsentPreferences.instance.setEnabled(InputModality.sleep, true);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Currently on: M3 Sleep (not saved)'), findsOneWidget);
    });

    testWidgets('Export and Erase explain honestly that they are unavailable', (t) async {
      final h = t.ensureSemantics();
      await pump(t, const SettingsScreen(), height: 3200);
      expect(
          t.getSemantics(find.bySemanticsLabel(RegExp(r'^Export my data\. Not available yet'))),
          isSemantics(isButton: true, hasTapAction: true, isFocusable: true));
      await tapVisible(t, find.text('Export my data'));
      expect(find.text('Export not available yet'), findsOneWidget);
      expect(find.text(PrototypeCopy.exportUnavailable), findsOneWidget);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Erase my data'));
      expect(find.text('Erase not available yet'), findsOneWidget);
      expect(find.text(PrototypeCopy.eraseUnavailable), findsOneWidget);
      expect(t.getSize(find.widgetWithText(TextButton, 'OK')).height, greaterThanOrEqualTo(48));
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.text('Erase not available yet'), findsNothing);
      h.dispose();
    });

    testWidgets('Tab root has no back control; pushed Profile has "Back"', (t) async {
      await pump(t, const SettingsScreen(isTabRoot: true));
      expect(find.byTooltip('Back'), findsNothing);
      await pump(t, const SettingsScreen());
      expect(find.byTooltip('Back'), findsOneWidget);
    });
  });

  // ---- Shell ------------------------------------------------------------------------------
  testWidgets('Shell: tabs switch to the redesigned Insights and Profile; Back returns Home',
      (t) async {
    final h = t.ensureSemantics();
    await pump(t, const MainShell());
    t.semantics.tap(find.semantics.byLabel('Insights tab'));
    await t.pumpAndSettle();
    expect(find.text('Longitudinal insights'), findsOneWidget);
    t.semantics.tap(find.semantics.byLabel('Profile tab'));
    await t.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(t.getSemantics(find.bySemanticsLabel('Home tab')), isSemantics(isSelected: true));
    expect(find.byType(NatureBottomBar), findsOneWidget);
    h.dispose();
  });

  // ---- Follow-ups: tokens and logo -----------------------------------------------------
  group('Phase 1 follow-ups', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    const textColours = {
      'ink': NatureColors.ink,
      'inkMuted': NatureColors.inkMuted,
      'forest': NatureColors.forest,
      'skyInk': NatureColors.skyInk,
      'ochreInk': NatureColors.ochreInk,
      'coralInk': NatureColors.coralInk,
    };

    test('Every text colour is at least 5:1 on the sage wash (surfaces and hover tints)', () {
      expect(NatureColors.surfaceQuiet, NatureColors.sageWash);
      expect(NatureColors.hover, NatureColors.sageWash);
      for (final e in textColours.entries) {
        expect(ratio(e.value, NatureColors.sageWash), greaterThanOrEqualTo(5.0), reason: e.key);
      }
    });

    test('Pale sage stays the approved value and is never used behind text', () {
      expect(NatureColors.paleSage, const Color(0xFFD9E4D4));
      // Muted text would fail on it, which is why it is decoration only.
      expect(ratio(NatureColors.inkMuted, NatureColors.paleSage), lessThan(4.5));
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          if (!line.contains('NatureColors.paleSage')) continue;
          expect(line.contains('hoverColor') || line.contains('surfaceQuiet'), isFalse,
              reason: '${f.path}: $line');
        }
      }
    });

    testWidgets('Forest badge paints with the logo geometry; forest lockup SVG matches', (t) async {
      await t.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SenseLogoMark(size: 64, variant: SenseLogoVariant.forestBadge))));
      expect(t.takeException(), isNull);
      final forest = File('assets/branding/sense_logo_horizontal_forest.svg').readAsStringSync();
      final blue = File('assets/branding/sense_logo_horizontal.svg').readAsStringSync();
      final markPath = RegExp(r'<path d="(M [^"]+)"').firstMatch(blue)!.group(1)!;
      expect(forest, contains(markPath), reason: 'identical mark geometry');
      for (final c in ['#3F6556', '#F3EBDD', '#E5AE56']) {
        expect(forest, contains(c));
      }
      expect(forest, isNot(contains('#059BE0')));
      expect(forest, contains('<title>SENSE</title>'));
    });
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
      testWidgets('Real Poppins ${width.toInt()} px, text ${scale}x: Insights, Insight detail and '
          'Profile fit, no broken words, labelled 48 px targets', (t) async {
        await t.runAsync(loadPoppins);
        final h = t.ensureSemantics();
        final height = width >= 1024 ? 900.0 : 780.0;
        final found = <String>{};
        for (final screen in <Widget>[
          const MainShell(initialIndex: MainTab.insights),
          const InsightDetailScreen(),
          const MainShell(initialIndex: MainTab.profile),
        ]) {
          await pump(t, screen, width: width, height: height, scale: scale);
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
    for (final s in <Widget>[
      const InsightsScreen(isTabRoot: true),
      const InsightDetailScreen(),
      const SettingsScreen(isTabRoot: true),
    ]) {
      await pump(t, s, height: 3400);
      await expectLater(t, meetsGuideline(textContrastGuideline));
    }
    h.dispose();
  });
}
