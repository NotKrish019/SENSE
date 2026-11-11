// Milestone K3: the two-step Check-in screen connected to CheckInController.
// Most cases inject a controller over a programmable CheckInAccess; the last
// group runs the real storage owner (FakeSecureKeyPlatform, disposable plain
// SQLite through sqflite_common_ffi) under SenseStorageScope, as the app does.
// The unconnected prototype behaviour ("complete, not saved") stays covered by
// the existing honesty, preview and Living Landscapes tests, which pump the
// screen without storage.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/check_in_controller.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_storage_scope.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_check_in_access.dart';
import 'support/fake_secure_key_platform.dart';

void main() {
  final evening = DateTime(2026, 11, 11, 20, 15);
  final tz = evening.timeZoneOffset.inMinutes;
  const today = '2026-11-11';
  const cont = 'Continue to stress rating';
  const finish = 'Finish check-in';

  late FakeCheckInAccess access;
  setUp(() => access = FakeCheckInAccess());
  tearDown(() => ConsentPreferences.instance.reset());

  void view(WidgetTester t) {
    t.view.physicalSize = const Size(412 * 3, 3000 * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<CheckInController> pumpScreen(WidgetTester t, {FakeCheckInAccess? a, bool settle = true}) async {
    view(t);
    final c = CheckInController(access: a ?? access, now: () => evening);
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: CheckInScreen(controller: c)));
    if (settle) await t.pumpAndSettle();
    return c;
  }

  SemanticsNode node(WidgetTester t, String label) => t.getSemantics(find.bySemanticsLabel(label).first);
  bool enabled(SemanticsNode n) => n.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue;
  // "Perceived stress" is also the step 2 heading: use the slider's own node.
  SemanticsNode stressNode(WidgetTester t) => t.getSemantics(find.byType(Slider));
  String stressValue(WidgetTester t) => stressNode(t).getSemanticsData().value;
  Future<void> stressAction(WidgetTester t, SemanticsAction a) async {
    t.semantics
        .performAction(find.semantics.byPredicate((n) {
          final d = n.getSemanticsData();
          return d.label == 'Perceived stress' &&
              (d.hasAction(SemanticsAction.increase) || d.hasAction(SemanticsAction.decrease));
        }), a);
    await t.pumpAndSettle();
  }

  String status(WidgetTester t) => t.widget<Text>(find.byKey(const Key('check-in-status'))).data!;

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  /// Any completion page (persisted or not).
  Finder donePage() => find.text('Return to Home');
  Finder successClaim() => find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^Check-in (saved|updated)$|check-in was (saved|updated)').hasMatch(w.data ?? ''));

  group('Two steps', () {
    testWidgets('initial state: step 1 with defaults and an honest status; no prototype note', (t) async {
      final h = t.ensureSemantics();
      await pumpScreen(t);
      expect(node(t, 'Motivation or energy level').getSemanticsData().value, '3 of 5');
      expect(node(t, 'Mood: Neutral').getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(status(t), startsWith('No check-in saved today yet.'));
      expect(status(t), contains('development storage'));
      expect(find.textContaining('Not saved: this prototype'), findsNothing);
      h.dispose();
    });

    testWidgets('answers and adjusted fields survive moving forward and back', (t) async {
      final h = t.ensureSemantics();
      final c = await pumpScreen(t);
      await t.tap(find.bySemanticsLabel('Mood: Great'));
      await t.pumpAndSettle();
      t.semantics.performAction(find.semantics.byLabel('Motivation or energy level'), SemanticsAction.decrease);
      await t.pumpAndSettle();
      await tap(t, cont);
      expect(stressValue(t), '2 of 5');
      await stressAction(t, SemanticsAction.increase);
      await tap(t, 'Back');
      expect(node(t, 'Mood: Great').getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(node(t, 'Motivation or energy level').getSemanticsData().value, '2 of 5');
      await tap(t, cont);
      expect(stressValue(t), '3 of 5');
      expect([c.mood, c.motivation, c.stress], [5, 2, 3]);
      expect(c.changedFields, CheckInEntry.allFields);
      h.dispose();
    });
  });

  group('Finishing', () {
    testWidgets('success page only after the write; one record with the answers', (t) async {
      await pumpScreen(t);
      await t.tap(find.bySemanticsLabel('Mood: Good'));
      await t.pumpAndSettle();
      await tap(t, cont);
      await tap(t, finish);
      expect(find.text('Check-in saved'), findsOneWidget);
      expect(find.textContaining('encrypted development storage'), findsOneWidget);
      expect(find.textContaining('not for participants'), findsOneWidget);
      expect(find.text('Check-in complete, not saved'), findsNothing);
      final e = access.records[today]!.entry;
      expect([e.moodRating, e.motivationEnergyRating, e.perceivedStressRating], [4, 3, 2]);
      expect(e.day, LocalDay(today, tz));
      expect(e.provenance.changedFields, {'mood_rating'});
    });

    testWidgets('existing check-in is prefilled; finishing updates it (same record)', (t) async {
      final h = t.ensureSemantics();
      access.seed(today, tz, mood: 2, motivation: 4, stress: 5, changed: CheckInEntry.allFields);
      final c = await pumpScreen(t);
      expect(node(t, 'Mood: Low').getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(node(t, 'Motivation or energy level').getSemanticsData().value, '4 of 5');
      expect(status(t), startsWith('You already completed a check-in today.'));
      await tap(t, cont);
      expect(stressValue(t), '5 of 5');
      await stressAction(t, SemanticsAction.decrease);
      await tap(t, finish);
      expect(find.text('Check-in updated'), findsOneWidget);
      expect(find.textContaining("Today's check-in was updated"), findsOneWidget);
      expect(access.records, hasLength(1));
      expect(access.records[today]!.id, 'existing-check-in');
      expect(c.existingEntry!.entry.perceivedStressRating, 4);
      h.dispose();
    });

    testWidgets('loading: Finish is disabled until today is read', (t) async {
      final h = t.ensureSemantics();
      access.loadGate = Completer<void>();
      await pumpScreen(t, settle: false);
      await t.pump();
      expect(status(t), "Loading today's check-in.");
      expect(find.byKey(const Key('check-in-busy')), findsOneWidget);
      await tap(t, cont); // moving between steps is always possible
      expect(enabled(node(t, finish)), isFalse);
      access.loadGate!.complete();
      await t.pumpAndSettle();
      expect(enabled(node(t, finish)), isTrue);
      h.dispose();
    });

    testWidgets('saving: no success page before the write commits; a double tap writes once', (t) async {
      final h = t.ensureSemantics();
      await pumpScreen(t);
      await tap(t, cont);
      access.saveGate = Completer<void>();
      await t.tap(find.text(finish));
      await t.pump();
      await t.tap(find.text(finish), warnIfMissed: false);
      await t.pump();
      expect(status(t), 'Saving your check-in.');
      expect(find.byKey(const Key('check-in-busy')), findsOneWidget);
      expect(enabled(node(t, finish)), isFalse);
      expect(donePage(), findsNothing);
      expect(successClaim(), findsNothing);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(access.saveCalls, hasLength(1));
      expect(find.text('Check-in saved'), findsOneWidget);
      h.dispose();
    });

    testWidgets('consent denied: stays on step 2, answers kept, link to consent; M1 never turned on', (t) async {
      final h = t.ensureSemantics();
      access.saveOutcome = const CheckInConsentDenied(ConsentDenialReason.notRecorded);
      final c = await pumpScreen(t);
      await tap(t, cont);
      await stressAction(t, SemanticsAction.increase);
      await tap(t, finish);
      const msg = 'Structured check-ins are turned off in your data and consent preferences, so nothing was saved.';
      expect(find.text(msg), findsNWidgets(2)); // status and message
      expect(donePage(), findsNothing);
      expect(successClaim(), findsNothing);
      expect(c.stress, 3);
      expect(stressValue(t), '3 of 5');
      await tap(t, 'Review data and consent preferences');
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(ConsentPreferences.instance.isEnabled(InputModality.checkIn), isFalse);
      h.dispose();
    });

    testWidgets('storage unavailable: clear state; Finish does not reach a completion page', (t) async {
      await pumpScreen(t, a: FakeCheckInAccess(status: CheckInStorageStatus.unavailable));
      expect(status(t), startsWith('Secure storage is unavailable'));
      await tap(t, cont);
      await tap(t, finish);
      expect(donePage(), findsNothing);
      expect(successClaim(), findsNothing);
      expect(find.textContaining('Secure storage is unavailable'), findsNWidgets(2));
    });

    testWidgets('a failed save keeps the answers and claims nothing; retry succeeds', (t) async {
      access.saveOutcome = const CheckInSaveFailed();
      final c = await pumpScreen(t);
      await t.tap(find.bySemanticsLabel('Mood: Very Low'));
      await t.pumpAndSettle();
      await tap(t, cont);
      await tap(t, finish);
      expect(find.text('Your check-in could not be saved. Your answers are still here, so you can try again.'),
          findsNWidgets(2));
      expect(donePage(), findsNothing);
      expect(c.mood, 1);
      access.saveOutcome = null;
      await tap(t, finish);
      expect(find.text('Check-in saved'), findsOneWidget);
      expect(access.records[today]!.entry.moodRating, 1);
    });

    testWidgets('not connected by this build: the prototype note and the honest "not saved" page', (t) async {
      await pumpScreen(t, a: FakeCheckInAccess(status: CheckInStorageStatus.notConnected));
      expect(find.textContaining('Not saved: this prototype'), findsOneWidget);
      expect(find.byKey(const Key('check-in-status')), findsNothing);
      await tap(t, cont);
      expect(find.textContaining('Ratings are not saved in this prototype'), findsOneWidget);
      await tap(t, finish);
      expect(find.text('Check-in complete, not saved'), findsOneWidget);
      expect(successClaim(), findsNothing);
    });
  });

  group('Real storage owner under SenseStorageScope (host fake platform)', () {
    late Directory dir;
    setUpAll(sqfliteFfiInit);
    setUp(() => dir = Directory.systemTemp.createTempSync('sense_k3_ui_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> settle(WidgetTester t, bool Function() done) async {
      for (var i = 0; i < 300 && !done(); i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(done(), isTrue, reason: 'condition not reached');
    }

    testWidgets('M1 on: Finish writes through the repository; M1 off: denied, earlier record kept', (t) async {
      view(t);
      final storage = SenseStorage(
          policy: const SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true),
          platform: FakeSecureKeyPlatform(dir));
      final ready = (await t.runAsync(storage.start))! as StorageReady;
      addTearDown(() => t.runAsync(storage.close));
      final person = ready.profile.localPersonId;
      await t.runAsync(() => ready.store.consent.recordChange(person, 'M1', true));

      Future<void> open() async {
        await t.pumpWidget(SenseStorageScope(
          storage: storage,
          child: MaterialApp(theme: AppTheme.lightTheme, home: CheckInScreen(key: UniqueKey())),
        ));
        await settle(t, () => find.byKey(const Key('check-in-status')).evaluate().isNotEmpty &&
            !status(t).startsWith('Loading'));
      }

      await open();
      await t.tap(find.bySemanticsLabel('Mood: Great'));
      await t.pumpAndSettle();
      await tap(t, cont);
      await t.tap(find.text(finish));
      await settle(t, () => find.text('Check-in saved').evaluate().isNotEmpty);
      final day = LocalDay.fromLocal(DateTime.now()).date;
      final stored = (await t.runAsync(() => ready.store.checkIns.byDate(person, day)))!;
      expect([stored.entry.moodRating, stored.entry.motivationEnergyRating, stored.entry.perceivedStressRating],
          [5, 3, 2]);
      expect(stored.entry.provenance.changedFields, {'mood_rating'});

      // A fresh screen loads it; M1 is revoked; finishing is denied and the record kept.
      await open();
      expect(status(t), startsWith('You already completed a check-in today.'));
      await t.runAsync(() => ready.store.consent.recordChange(person, 'M1', false));
      await tap(t, cont);
      await t.tap(find.text(finish));
      await settle(t, () => find.textContaining('Structured check-ins are turned off').evaluate().isNotEmpty);
      expect(donePage(), findsNothing);
      final kept = (await t.runAsync(() => ready.store.checkIns.byDate(person, day)))!;
      expect(kept.id, stored.id);
      expect(kept.updatedAtUtc, stored.updatedAtUtc);
    });
  });
}
