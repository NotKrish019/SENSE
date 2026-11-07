import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/dashboard_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/onboarding_screen.dart';
import 'package:mindpulse/presentation/screens/splash_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_logo.dart';

/// Task 7: SENSE visual identity (logo mark) and bundled Poppins typography.
void main() {
  setUp(ConsentPreferences.instance.reset);

  Future<void> pump(WidgetTester tester, Widget home,
      {double width = 412, double scale = 1.0}) async {
    tester.view.physicalSize = Size(width * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
  }

  group('Logo', () {
    testWidgets('Splash shows the SENSE mark, not the old wave icon', (tester) async {
      await pump(tester, const SplashScreen());
      expect(find.byType(SenseLogoMark), findsOneWidget);
      expect(find.byIcon(Icons.waves_rounded), findsNothing);
      expect(find.text('SENSE'), findsOneWidget);
      // Let the splash timer finish (it navigates to onboarding).
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('Onboarding and Home headers use the SENSE mark', (tester) async {
      await pump(tester, const OnboardingScreen());
      await tester.pumpAndSettle();
      expect(find.byType(SenseLogoMark), findsOneWidget);
      expect(find.byIcon(Icons.waves_rounded), findsNothing);

      await pump(tester, const MainShell());
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(DashboardScreen), matching: find.byType(SenseLogoMark)),
          findsOneWidget);
      expect(find.byIcon(Icons.waves_rounded), findsNothing);
    });

    testWidgets('The old wave icon is not referenced anywhere in lib/', (tester) async {
      final hits = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && f.readAsStringSync().contains('waves_rounded'))
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty);
    });

    testWidgets('Mark is decorative (excluded from semantics) unless labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: Column(children: [
          SenseLogoMark(size: 40),
          SenseLogoMark(size: 40, semanticLabel: 'SENSE logo'),
        ]),
      ));
      expect(find.bySemanticsLabel('SENSE logo'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('All variants paint without errors from 16 to 160 px', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Wrap(children: [
          for (final v in SenseLogoVariant.values)
            for (final s in [16.0, 24.0, 32.0, 48.0, 80.0, 160.0])
              SenseLogoMark(size: s, variant: v),
          const SenseLogo(),
        ]),
      ));
      expect(find.byType(SenseLogoMark), findsNWidgets(SenseLogoVariant.values.length * 6 + 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Poppins typography', () {
    test('Poppins 400/500/600/700/800 are bundled and registered, with the OFL', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Poppins'));
      for (final (file, weight) in [
        ('Poppins-Regular.ttf', 400),
        ('Poppins-Medium.ttf', 500),
        ('Poppins-SemiBold.ttf', 600),
        ('Poppins-Bold.ttf', 700),
        ('Poppins-ExtraBold.ttf', 800),
      ]) {
        final path = 'assets/fonts/poppins/$file';
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(pubspec, contains('asset: $path\n          weight: $weight'));
      }
      final ofl = File('assets/fonts/poppins/OFL.txt').readAsStringSync();
      expect(ofl, contains('SIL Open Font License'));
    });

    test('Theme and type scale use Poppins (no runtime font package)', () {
      expect(AppTheme.lightTheme.textTheme.bodyMedium!.fontFamily, 'Poppins');
      expect(SenseTypography.h1.fontFamily, 'Poppins');
      expect(SenseTypography.buttonLabel.fontFamily, 'Poppins');
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('google_fonts')));
    });

    // Widget tests normally draw text with a square test font. Here the real
    // bundled Poppins is loaded, so these check real glyph widths.
    Future<void> loadPoppins() async {
      final loader = FontLoader('Poppins');
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
        final bytes = File('assets/fonts/poppins/Poppins-$w.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
      }
      await loader.load();
    }

    Future<void> scrollToEnd(WidgetTester tester) async {
      final v = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      if (v.evaluate().isEmpty) return;
      for (var i = 0; i < 60; i++) {
        final p = tester.state<ScrollableState>(v.first).position;
        if (p.pixels >= p.maxScrollExtent - 0.5) break;
        await tester.drag(v.first, const Offset(0, -500), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }

    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('Real Poppins at ${width.toInt()} px, text 2.0x: Home, Consent, Journal fit',
          (tester) async {
        await tester.runAsync(loadPoppins);
        // Proof that Poppins (not the square test font) is in use: in the test
        // font every glyph is exactly 1 em wide, so 'iiii' at 10 px = 40 px.
        final probe = TextPainter(
          text: TextSpan(text: 'iiii', style: SenseTypography.body.copyWith(fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(probe.width, lessThan(20));
        probe.dispose();
        for (final screen in <Widget>[const MainShell(), const ConsentScreen(), const JournalScreen()]) {
          await pump(tester, screen, width: width, scale: 2.0);
          await tester.pumpAndSettle();
          await scrollToEnd(tester);
          expect(tester.takeException(), isNull);
        }
      });
    }

    // Insights weekday labels, measured with real Poppins (Task 7B).
    // Expected: three letters whenever every label fits its 1/7 slot
    // (412 px side by side; 360 and 320 px, where the charts stack
    // full-width), single letters when they do not (2x text).
    const threeLetter = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final (width, scale, expectFull) in [
      (412.0, 1.0, true),
      (360.0, 1.0, true),
      (360.0, 1.3, true),
      (412.0, 1.15, false),
      (320.0, 1.0, true),
      (412.0, 2.0, false),
      (360.0, 2.0, false),
      (320.0, 2.0, false),
    ]) {
      testWidgets(
          'Real Poppins weekday labels at ${width.toInt()} px, text ${scale}x: '
          '${expectFull ? 'Mon…Sun' : 'M T W…'}, never clipped', (tester) async {
        await tester.runAsync(loadPoppins);
        final handle = tester.ensureSemantics();
        await pump(tester, const MainShell(initialIndex: MainTab.insights),
            width: width, scale: scale);
        await tester.pumpAndSettle();
        final wed = find.bySemanticsLabel('Wednesday, sample bar');
        await tester.ensureVisible(wed);
        await tester.pumpAndSettle();

        if (expectFull) {
          for (final d in threeLetter) {
            expect(find.text(d), findsOneWidget, reason: d);
          }
        } else {
          expect(find.text('Wed'), findsNothing);
          expect(find.text('W'), findsOneWidget);
        }
        // Full day names stay available to screen readers.
        expect(wed, findsOneWidget);
        expect(find.bySemanticsLabel('Monday, sample bar'), findsOneWidget);

        // No label is wider than its slot (would be clipped) and none is
        // shrunk: the text is drawn at its normal size.
        final labels = expectFull ? threeLetter : const ['M', 'T', 'W', 'F', 'S'];
        for (final d in labels) {
          for (final e in find.text(d).evaluate()) {
            final p = e.renderObject as RenderParagraph;
            final tp = TextPainter(
              text: p.text,
              textDirection: TextDirection.ltr,
              textScaler: p.textScaler,
              maxLines: 1,
            )..layout();
            expect(tp.width, lessThanOrEqualTo(p.size.width + 0.5), reason: '$d clipped');
            expect(p.textScaler.scale(11), closeTo(11 * scale, 0.01), reason: '$d shrunk');
            tp.dispose();
          }
        }
        handle.dispose();
      });
    }
  });

  group('Web branding', () {
    (int, int) pngSize(String path) {
      final b = File(path).readAsBytesSync();
      int be(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
      return (be(16), be(20));
    }

    test('Favicon and manifest icons exist at their declared sizes', () {
      expect(pngSize('web/favicon.png'), (32, 32));
      for (final (f, s) in [
        ('Icon-192.png', 192),
        ('Icon-512.png', 512),
        ('Icon-maskable-192.png', 192),
        ('Icon-maskable-512.png', 512),
      ]) {
        expect(pngSize('web/icons/$f'), (s, s), reason: f);
      }
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest, contains('"name": "SENSE"'));
      expect(File('web/index.html').readAsStringSync(), contains('<title>SENSE</title>'));
    });

    test('Logo SVG sources exist for every variant', () {
      for (final f in [
        'sense_mark.svg',
        'sense_mark_mono.svg',
        'sense_mark_white.svg',
        'sense_app_icon.svg',
        'sense_app_icon_maskable.svg',
        'sense_logo_horizontal.svg',
      ]) {
        expect(File('assets/branding/$f').existsSync(), isTrue, reason: f);
      }
    });

    test('Horizontal lockup wordmark is outlined (no font needed to render it)', () {
      final svg = File('assets/branding/sense_logo_horizontal.svg').readAsStringSync();
      expect(svg, isNot(contains('<text')));
      expect(svg, isNot(contains('font-family')));
      expect(svg, contains('aria-label="SENSE"'));
      expect(svg, contains('<title>SENSE</title>'));
    });
  });
}
