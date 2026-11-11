// K3 final corrections: save-state integrity and date-change messaging for
// the Check-in screen. A save is held open with a Completer (no timing), so
// the in-flight state is observed deterministically.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/check_in_controller.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';

import 'support/fake_check_in_access.dart';

void main() {
  final evening = DateTime(2026, 11, 11, 23, 55);
  const cont = 'Continue to stress rating';
  const finish = 'Finish check-in';

  late FakeCheckInAccess access;
  late DateTime now;
  setUp(() {
    access = FakeCheckInAccess();
    now = evening;
  });
  tearDown(() => ConsentPreferences.instance.reset());

  /// Pushes the screen over a launcher route, so leaving can be observed.
  Future<CheckInController> pumpPushed(WidgetTester t) async {
    t.view.physicalSize = const Size(412 * 3, 3000 * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = CheckInController(access: access, now: () => now);
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckInScreen(controller: c))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return c;
  }

  SemanticsData sem(WidgetTester t, Finder f) => t.getSemantics(f).getSemanticsData();
  bool enabled(SemanticsData d) => d.flagsCollection.isEnabled == Tristate.isTrue;
  SemanticsData stressSlider(WidgetTester t) => sem(t, find.byType(Slider));

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  /// Answers mood 4, motivation 2, stress 4, then holds the save open.
  Future<CheckInController> startHeldSave(WidgetTester t) async {
    final c = await pumpPushed(t);
    await t.tap(find.bySemanticsLabel('Mood: Good'));
    await t.pumpAndSettle();
    c.setMotivation(2);
    await t.pump();
    await tap(t, cont);
    c.setStress(4);
    await t.pump();
    access.saveGate = Completer<void>();
    await t.ensureVisible(find.text(finish));
    await t.pumpAndSettle();
    await t.tap(find.text(finish));
    await t.pump();
    expect(c.isSaving, isTrue);
    return c;
  }

  group('While a check-in is saving', () {
    testWidgets('stress, Back, the page back control and Finish are disabled; a busy indicator shows', (t) async {
      final h = t.ensureSemantics();
      await startHeldSave(t);
      expect(enabled(stressSlider(t)), isFalse);
      expect(enabled(sem(t, find.bySemanticsLabel('Back').last)), isFalse, reason: 'step 2 Back');
      expect(enabled(sem(t, find.byTooltip('Back to Home'))), isFalse, reason: 'page back control');
      expect(enabled(sem(t, find.bySemanticsLabel(finish))), isFalse);
      expect(find.byKey(const Key('check-in-busy')), findsOneWidget);
      expect(find.text('Saving your check-in.'), findsOneWidget);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      h.dispose();
    });

    testWidgets('mood and motivation cannot change: step 1 is unreachable and the controller refuses changes',
        (t) async {
      final c = await startHeldSave(t);
      await t.tap(find.text('Back').last, warnIfMissed: false);
      await t.pump();
      expect(find.text(cont), findsNothing, reason: 'still on step 2');
      c.setMood(1);
      c.setMotivation(5);
      c.setStress(1);
      expect([c.mood, c.motivation, c.stress], [4, 2, 4]);
      access.saveGate!.complete();
      await t.pumpAndSettle();
    });

    testWidgets('step 1 controls render disabled in the saving state', (t) async {
      // Step 1 is not reachable during a save; this checks its controls'
      // locked rendering directly, so a future route to it stays safe.
      final h = t.ensureSemantics();
      final c = await pumpPushed(t);
      access.saveGate = Completer<void>();
      unawaited(c.save()); // a save started from elsewhere while step 1 shows
      await t.pump();
      expect(c.isSaving, isTrue);
      for (final label in ['Mood: Very Low', 'Mood: Neutral', 'Mood: Great']) {
        expect(enabled(sem(t, find.bySemanticsLabel(label))), isFalse, reason: label);
      }
      expect(enabled(sem(t, find.byType(Slider))), isFalse, reason: 'motivation slider');
      expect(enabled(sem(t, find.bySemanticsLabel(cont))), isFalse, reason: 'Continue');
      await t.tap(find.bySemanticsLabel('Mood: Great'), warnIfMissed: false);
      await t.pump();
      expect(c.mood, 3);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(enabled(sem(t, find.bySemanticsLabel('Mood: Great'))), isTrue, reason: 're-enabled after the save');
      h.dispose();
    });

    testWidgets('system back cannot leave and discard the in-flight save', (t) async {
      await startHeldSave(t);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(CheckInScreen), findsOneWidget);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Check-in saved'), findsOneWidget);
      await tap(t, 'Return to Home');
      expect(find.byType(CheckInScreen), findsNothing, reason: 'leaving works again once saved');
    });

    testWidgets('repeated Finish taps during the save make one write', (t) async {
      await startHeldSave(t);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text(finish), warnIfMissed: false);
        await t.pump();
      }
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(access.saveCalls, hasLength(1));
      expect(access.records, hasLength(1));
    });

    testWidgets('the committed record is exactly the answers shown when Finish was pressed', (t) async {
      final c = await startHeldSave(t);
      c.setStress(1); // refused while saving
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Check-in saved'), findsOneWidget);
      final e = access.records.values.single.entry;
      expect([e.moodRating, e.motivationEnergyRating, e.perceivedStressRating], [4, 2, 4]);
      expect([c.mood, c.motivation, c.stress], [4, 2, 4]);
      expect(e.provenance.changedFields, CheckInEntry.allFields);
    });

    testWidgets('a failed save keeps every answer and re-enables the controls', (t) async {
      final h = t.ensureSemantics();
      access.saveOutcome = const CheckInSaveFailed();
      final c = await startHeldSave(t);
      expect(enabled(stressSlider(t)), isFalse);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Check-in saved'), findsNothing);
      expect(find.textContaining('could not be saved'), findsWidgets);
      expect([c.mood, c.motivation, c.stress], [4, 2, 4]);
      expect(stressSlider(t).value, '4 of 5');
      expect(enabled(stressSlider(t)), isTrue);
      expect(enabled(sem(t, find.bySemanticsLabel('Back').last)), isTrue);
      expect(enabled(sem(t, find.byTooltip('Back to Home'))), isTrue);
      expect(enabled(sem(t, find.bySemanticsLabel(finish))), isTrue);
      await tap(t, 'Back');
      expect(sem(t, find.bySemanticsLabel('Mood: Good')).flagsCollection.isSelected, Tristate.isTrue);
      h.dispose();
    });
  });

  group('Midnight before Finish', () {
    const changed = 'The date changed before you finished, so nothing was saved. This check-in is now for today: '
        "answers you changed are kept, the others show today's saved check-in or the starting values. Review them "
        'and finish again.';
    const notReloaded = 'The date changed before you finished, so nothing was saved, and '
        "today's check-in could not be read. Your answers are still on screen; finishing again reads today first.";

    testWidgets('no stale-date write; accurate message; adjusted answers kept; a second Finish saves the new day',
        (t) async {
      final c = await pumpPushed(t);
      await t.tap(find.bySemanticsLabel('Mood: Great'));
      await t.pumpAndSettle();
      await tap(t, cont);
      now = DateTime(2026, 11, 12, 0, 2);
      await tap(t, finish);
      expect(access.saveCalls, isEmpty, reason: 'nothing written for the stale date');
      expect(find.text(changed), findsOneWidget);
      expect(find.textContaining('kept for today'), findsNothing, reason: 'the old, inaccurate wording');
      expect(find.text('Check-in saved'), findsNothing);
      expect(c.day!.date, '2026-11-12');
      expect([c.mood, c.motivation, c.stress], [5, 3, 2]);
      await tap(t, finish);
      expect(find.text('Check-in saved'), findsOneWidget);
      expect(access.saveCalls.single.day.date, '2026-11-12');
    });

    testWidgets('the new day cannot be read: no write; the message says so and does not claim anything was kept',
        (t) async {
      final c = await pumpPushed(t);
      await t.tap(find.bySemanticsLabel('Mood: Low'));
      await t.pumpAndSettle();
      await tap(t, cont);
      now = DateTime(2026, 11, 12, 0, 2);
      access.loadOutcome = const CheckInLoadFailed();
      await tap(t, finish);
      expect(access.saveCalls, isEmpty);
      expect(find.text(notReloaded), findsOneWidget);
      expect(find.text(changed), findsNothing);
      expect(c.mood, 2, reason: 'the answers on screen are unchanged');
      // Once the new day can be read, the next Finish reads it first and then
      // reports the date change for review: still no write.
      access.loadOutcome = null;
      await tap(t, finish);
      expect(access.loadCalls.last, '2026-11-12');
      expect(access.saveCalls, isEmpty, reason: 'answers for the new day are reviewed before any write');
      expect(find.text(changed), findsOneWidget);
      expect(c.day!.date, '2026-11-12');
      // A further Finish, after review, saves to the new day.
      await tap(t, finish);
      expect(access.saveCalls.single.day.date, '2026-11-12');
      expect(find.text('Check-in saved'), findsOneWidget);
    });
  });
}
