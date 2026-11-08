import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/presentation/screens/activity_screen.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/insight_detail_screen.dart';
import 'package:mindpulse/presentation/screens/journal_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/onboarding_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/screens/voice_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';

/// Task 7: with the real bundled Poppins (wider than the square test font in
/// some words, narrower in others), no word may be broken across lines.
///
/// A word is broken mid-word exactly when it is wider than the text box that
/// holds it, so every visible single-style paragraph is checked word by word.
/// Single-line texts (maxLines 1 / no soft wrap) are skipped: they cannot
/// break, and FittedBox-scaled labels are covered by the overflow tests.
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

  List<String> brokenWords(WidgetTester tester) {
    final problems = <String>[];
    for (final element in find.byType(RichText).evaluate()) {
      final p = element.renderObject as RenderParagraph;
      if (!p.hasSize || p.maxLines == 1 || !p.softWrap) continue;
      final span = p.text;
      if (span is! TextSpan || (span.children?.isNotEmpty ?? false)) continue;
      final text = span.text ?? '';
      // Line breaks after a hyphen are normal, so split there too.
      for (final word in text.split(RegExp(r'\s+|(?<=-)'))) {
        if (word.length < 2) continue;
        final tp = TextPainter(
          text: TextSpan(text: word, style: span.style),
          textDirection: TextDirection.ltr,
          textScaler: p.textScaler,
          maxLines: 1,
        )..layout();
        final w = tp.width;
        tp.dispose();
        if (w > p.size.width + 0.5) {
          problems.add('"$word" (${w.toStringAsFixed(1)} > ${p.size.width.toStringAsFixed(1)}) in "$text"');
        }
      }
    }
    return problems;
  }

  Future<List<String>> checkWhileScrolling(WidgetTester tester) async {
    final found = <String>{...brokenWords(tester)};
    final v = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    if (v.evaluate().isEmpty) return found.toList();
    for (var i = 0; i < 60; i++) {
      final pos = tester.state<ScrollableState>(v.first).position;
      if (pos.pixels >= pos.maxScrollExtent - 0.5) break;
      await tester.drag(v.first, const Offset(0, -400), warnIfMissed: false);
      await tester.pumpAndSettle();
      found.addAll(brokenWords(tester));
    }
    return found.toList();
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

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('No mid-word breaks with Poppins at ${width.toInt()} px, text ${scale}x',
          (tester) async {
        await tester.runAsync(loadPoppins);
        tester.view.physicalSize = Size(width * 3, 780 * 3);
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
        final failures = <String>[];
        for (final entry in screens.entries) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: entry.value()));
          await tester.pumpAndSettle();
          for (final p in await checkWhileScrolling(tester)) {
            failures.add('${entry.key}: $p');
          }
          expect(tester.takeException(), isNull, reason: entry.key);
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  }
}
