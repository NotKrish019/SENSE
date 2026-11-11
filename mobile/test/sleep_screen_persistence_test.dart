// Milestone K4: the Sleep screen connected to SleepController. Saves are held
// open with Completers (no timing). Most cases inject a controller over a
// programmable SleepAccess; the last group runs the real storage owner
// (FakeSecureKeyPlatform, disposable plain SQLite through sqflite_common_ffi)
// under SenseStorageScope. The unconnected prototype behaviour stays covered
// by the existing Phase 3 and honesty tests (no storage owner).

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/state/sleep_controller.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_storage_scope.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_secure_key_platform.dart';
import 'support/fake_sleep_access.dart';

void main() {
  final morning = DateTime(2026, 11, 11, 7, 20);
  final tz = morning.timeZoneOffset.inMinutes;
  const today = '2026-11-11';
  const save = 'Save Sleep Record';

  late FakeSleepAccess access;
  late DateTime now;
  setUp(() {
    access = FakeSleepAccess();
    now = morning;
  });
  tearDown(() => ConsentPreferences.instance.reset());

  void view(WidgetTester t) {
    t.view.physicalSize = const Size(412 * 3, 3400 * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// 24-hour display so times read as stored ("23:30"); pushed over a
  /// launcher so leaving can be observed.
  Future<SleepController> pumpScreen(WidgetTester t, {FakeSleepAccess? a, bool settle = true}) async {
    view(t);
    final c = SleepController(access: a ?? access, now: () => now);
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SleepScreen(controller: c))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
      await t.pump(const Duration(milliseconds: 400)); // route transition (no I/O involved)
    }
    return c;
  }

  SemanticsData sem(WidgetTester t, Finder f) => t.getSemantics(f).getSemanticsData();
  bool enabled(SemanticsData d) => d.flagsCollection.isEnabled == Tristate.isTrue;
  String status(WidgetTester t) => t.widget<Text>(find.byKey(const Key('sleep-status'))).data!;
  SemanticsData duration(WidgetTester t) => sem(t, find.byType(Slider));

  Future<void> tapText(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  /// Opens a time field and types [hour]:[minute] in the picker's input mode.
  Future<void> pickTime(WidgetTester t, String fieldLabelPrefix, int hour, int minute) async {
    final field = find.bySemanticsLabel(RegExp('^$fieldLabelPrefix: .*Tap to change'));
    await t.ensureVisible(field);
    await t.pumpAndSettle();
    await t.tap(field);
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.keyboard_outlined));
    await t.pumpAndSettle();
    final inputs = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    await t.enterText(inputs.at(0), '$hour'.padLeft(2, '0'));
    await t.enterText(inputs.at(1), '$minute'.padLeft(2, '0'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
  }

  /// Sets 6.5 h, 00:05 to 06:35, quality 2 through the controller, then
  /// holds the save open.
  Future<SleepController> startHeldSave(WidgetTester t) async {
    final c = await pumpScreen(t);
    c.setDurationHours(6.5);
    c.setBedtime(0, 5);
    c.setWakeTime(6, 35);
    c.setQuality(2);
    await t.pump();
    access.saveGate = Completer<void>();
    await t.ensureVisible(find.text(save));
    await t.pumpAndSettle();
    await t.tap(find.text(save));
    await t.pump();
    expect(c.isSaving, isTrue);
    return c;
  }

  void expectInputsEnabled(WidgetTester t, bool on) {
    expect(enabled(duration(t)), on, reason: 'duration slider');
    expect(enabled(sem(t, find.bySemanticsLabel(RegExp('^Bedtime: ')))), on, reason: 'bedtime');
    expect(enabled(sem(t, find.bySemanticsLabel(RegExp('^Wake time: ')))), on, reason: 'wake time');
    for (var i = 1; i <= 5; i++) {
      expect(enabled(sem(t, find.bySemanticsLabel('Rest quality $i of 5'))), on, reason: 'star $i');
    }
    expect(enabled(sem(t, find.bySemanticsLabel(save))), on, reason: 'Save');
    expect(enabled(sem(t, find.byTooltip('Back'))), on, reason: 'back control');
  }

  group('Initial state and inputs', () {
    testWidgets('defaults, wake-up date context, honest status; history from stored records only', (t) async {
      final h = t.ensureSemantics();
      await pumpScreen(t);
      expect(find.text("Last night's sleep (woke today, Wednesday 11 November)"), findsOneWidget);
      expect(duration(t).value, '7.5 hours');
      expect(find.bySemanticsLabel('Bedtime: 23:30. Tap to change.'), findsOneWidget);
      expect(find.bySemanticsLabel('Wake time: 07:00. Tap to change.'), findsOneWidget);
      expect(sem(t, find.bySemanticsLabel('Rest quality 4 of 5')).flagsCollection.isSelected, Tristate.isTrue);
      expect(status(t), startsWith('No sleep entry saved today yet.'));
      // No sample data is shown as the person's history when storage is connected.
      expect(find.text('Example 7-day sleep history'), findsNothing);
      expect(find.text('Illustrative values, not your recorded sleep.'), findsNothing);
      expect(find.text('No sleep entries saved in the last 7 days yet.'), findsOneWidget);
      expect(find.text(PrototypeCopy.notStoredYet), findsNothing);
      h.dispose();
    });

    testWidgets('duration slider, both time pickers (stored as HH:MM) and the stars change the answers', (t) async {
      final h = t.ensureSemantics();
      final c = await pumpScreen(t);
      t.semantics.performAction(find.semantics.byPredicate((n) {
        final d = n.getSemanticsData();
        return d.label == 'Sleep duration' && d.hasAction(SemanticsAction.increase);
      }), SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(c.durationMinutes, 480);
      expect(duration(t).value, '8.0 hours');
      await pickTime(t, 'Bedtime', 0, 5);
      await pickTime(t, 'Wake time', 9, 7);
      expect([c.bedtime, c.wakeTime], ['00:05', '09:07']);
      expect(find.bySemanticsLabel('Bedtime: 00:05. Tap to change.'), findsOneWidget);
      t.semantics.tap(find.semantics.byLabel('Rest quality 2 of 5'));
      await t.pumpAndSettle();
      expect(c.quality, 2);
      expect(c.changedFields, SleepEntry.allFields);
      h.dispose();
    });
  });

  group('Saving', () {
    testWidgets('loading: status and Save disabled until the wake-up day is read', (t) async {
      final h = t.ensureSemantics();
      access.loadGate = Completer<void>();
      await pumpScreen(t, settle: false);
      expect(status(t), "Loading today's sleep entry.");
      expect(find.byKey(const Key('sleep-busy')), findsOneWidget);
      expect(enabled(sem(t, find.bySemanticsLabel(save))), isFalse);
      access.loadGate!.complete();
      await t.pumpAndSettle();
      expect(enabled(sem(t, find.bySemanticsLabel(save))), isTrue);
      h.dispose();
    });

    testWidgets('while saving every input, Save and Back are disabled; a busy indicator shows', (t) async {
      final h = t.ensureSemantics();
      await startHeldSave(t);
      expectInputsEnabled(t, false);
      expect(find.byKey(const Key('sleep-busy')), findsOneWidget);
      expect(status(t), 'Saving your sleep entry.');
      expect(find.textContaining("sleep was saved"), findsNothing, reason: 'no success before the commit');
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expectInputsEnabled(t, true);
      h.dispose();
    });

    testWidgets('system back cannot leave during the save; repeated taps write once; values match the record',
        (t) async {
      final c = await startHeldSave(t);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(SleepScreen), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text(save), warnIfMissed: false);
      }
      c.setQuality(5); // refused while saving
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(access.saveCalls, hasLength(1));
      final e = access.records[today]!.entry;
      expect([e.durationMinutes, e.bedtimeLocal, e.wakeTimeLocal, e.restQuality], [390, '00:05', '06:35', 2]);
      expect([c.durationMinutes, c.bedtime, c.wakeTime, c.quality], [390, '00:05', '06:35', 2]);
      expect(find.text("Last night's sleep was saved in development storage. Development data, not for participants."),
          findsOneWidget);
      // The history now shows the saved night, by wake-up day.
      expect(find.bySemanticsLabel(RegExp(r'Your last 7 days, saved entries: .*Wed 6\.5 hours$')), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(SleepScreen), findsNothing, reason: 'leaving works again after the save');
    });

    testWidgets('existing entry is prefilled and updated in place', (t) async {
      final h = t.ensureSemantics();
      access.seed(today, tz, minutes: 360, bedtime: '01:15', wake: '07:15', quality: 3,
          changed: {'duration_minutes', 'bedtime_local', 'wake_time_local', 'rest_quality'});
      await pumpScreen(t);
      expect(duration(t).value, '6.0 hours');
      expect(find.bySemanticsLabel('Bedtime: 01:15. Tap to change.'), findsOneWidget);
      expect(status(t), startsWith("You already saved last night's sleep today."));
      t.semantics.tap(find.semantics.byLabel('Rest quality 5 of 5'));
      await t.pumpAndSettle();
      await tapText(t, save);
      expect(find.text("Today's sleep entry was updated."), findsOneWidget);
      expect(access.records[today]!.id, 'existing-sleep');
      expect(access.records, hasLength(1));
      h.dispose();
    });

    testWidgets('a failed save keeps every value and re-enables every control; nothing is claimed', (t) async {
      final h = t.ensureSemantics();
      access.saveOutcome = const SleepSaveFailed();
      final c = await startHeldSave(t);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect([c.durationMinutes, c.bedtime, c.wakeTime, c.quality], [390, '00:05', '06:35', 2]);
      expect(duration(t).value, '6.5 hours');
      expect(find.text('Your sleep entry could not be saved. Your answers are still here, so you can try again.'),
          findsOneWidget);
      expect(find.textContaining("sleep was saved"), findsNothing);
      expectInputsEnabled(t, true);
      h.dispose();
    });

    testWidgets('consent denied: clear message, values kept, link to consent; M3 never turned on', (t) async {
      access.saveOutcome = const SleepConsentDenied(ConsentDenialReason.notRecorded);
      final c = await pumpScreen(t);
      c.setDurationHours(9);
      await t.pump();
      await tapText(t, save);
      const msg = 'Sleep is turned off in your data and consent preferences, so nothing was saved.';
      expect(find.text(msg), findsOneWidget);
      expect(c.durationMinutes, 540);
      await tapText(t, 'Review data and consent preferences');
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(ConsentPreferences.instance.isEnabled(InputModality.sleep), isFalse);
    });

    testWidgets('storage unavailable: message; nothing written; no history invented', (t) async {
      final a = FakeSleepAccess(status: SleepStorageStatus.unavailable);
      await pumpScreen(t, a: a);
      expect(status(t), startsWith('Secure storage is unavailable'));
      expect(find.text('Your saved sleep entries will appear here.'), findsOneWidget);
      expect(find.text('Example 7-day sleep history'), findsNothing);
      await tapText(t, save);
      expect(a.saveCalls, isEmpty);
      expect(find.textContaining("sleep was saved"), findsNothing);
    });

    testWidgets('not connected by this build: the labelled sample history and the prototype not-saved message',
        (t) async {
      await pumpScreen(t, a: FakeSleepAccess(status: SleepStorageStatus.notConnected));
      expect(find.text('Example 7-day sleep history'), findsOneWidget);
      expect(find.text('Illustrative values, not your recorded sleep.'), findsOneWidget);
      expect(find.text(PrototypeCopy.notStoredYet), findsOneWidget);
      expect(find.byKey(const Key('sleep-history')), findsNothing);
      await tapText(t, save);
      expect(find.text(PrototypeCopy.notSaved('sleep entry')), findsOneWidget);
    });
  });

  group('Inline success feedback (K4 UX correction)', () {
    testWidgets('saved and updated feedback appear inline above Save; nothing overlays it; Save works at once',
        (t) async {
      final previous = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true; // a covered Save button fails the test
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
      final c = await pumpScreen(t);
      await t.ensureVisible(find.text(save));
      await t.pumpAndSettle();
      await t.tap(find.text(save));
      await t.pump(); // the save completes (fake access) with no extra time passing
      await t.pump();
      expect(c.phase, SleepPhase.saved);
      const saved = "Last night's sleep was saved in development storage. Development data, not for participants.";
      expect(find.text(saved), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing, reason: 'no floating message');
      // The feedback sits above the Save button, without overlapping it.
      final status = t.getRect(find.byKey(const Key('sleep-status')));
      final button = t.getRect(find.text(save));
      expect(status.bottom, lessThanOrEqualTo(button.top));
      expect(status.overlaps(button), isFalse);
      // Save is immediately hit-testable and works: an update, distinguishable from the first save.
      c.setQuality(5);
      await t.pump();
      await t.tap(find.text(save));
      await t.pump();
      await t.pump();
      expect(access.saveCalls, hasLength(2));
      expect(c.phase, SleepPhase.updated);
      expect(find.text("Today's sleep entry was updated."), findsOneWidget);
      expect(find.text(saved), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Midnight before Save', () {
    const changed = 'The date changed before you saved, so nothing was saved for the earlier date. This entry is '
        "now for today's wake-up date (shown above): answers you changed are kept, the others show today's saved "
        'entry or the starting values. Review them and save again.';

    testWidgets('no stale write; new date shown; accurate message; a second Save writes the new day', (t) async {
      final c = await pumpScreen(t);
      c.setQuality(1);
      await t.pump();
      now = DateTime(2026, 11, 12, 0, 10);
      await tapText(t, save);
      expect(access.saveCalls, isEmpty);
      expect(find.text(changed), findsOneWidget); // inline in the status line (no overlay)
      expect(find.text("Last night's sleep (woke today, Thursday 12 November)"), findsOneWidget);
      expect(c.quality, 1);
      await tapText(t, save);
      expect(access.saveCalls.single.day.date, '2026-11-12');
    });

    testWidgets('the new day cannot be read: no write; accurate message; the retry refreshes and asks for review',
        (t) async {
      final c = await pumpScreen(t);
      c.setDurationHours(5);
      await t.pump();
      now = DateTime(2026, 11, 12, 0, 10);
      access.loadOutcome = const SleepLoadFailed();
      await tapText(t, save);
      expect(access.saveCalls, isEmpty);
      expect(
          find.text('The date changed before you saved, so nothing was saved, and today\'s sleep entry could not be '
              'read. Your answers are still on screen; saving again reads today first.'),
          findsOneWidget);
      expect(c.durationMinutes, 300);
      access.loadOutcome = null;
      await tapText(t, save);
      expect(access.saveCalls, isEmpty, reason: 'refreshed, then review: no unreviewed new-day write');
      expect(find.text(changed), findsOneWidget);
      await tapText(t, save);
      expect(access.saveCalls.single.day.date, '2026-11-12');
    });
  });

  group('Real storage owner under SenseStorageScope (host fake platform)', () {
    late Directory dir;
    setUpAll(sqfliteFfiInit);
    setUp(() => dir = Directory.systemTemp.createTempSync('sense_k4_ui_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> settle(WidgetTester t, bool Function() done) async {
      for (var i = 0; i < 300 && !done(); i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(done(), isTrue, reason: 'condition not reached');
    }

    testWidgets('M3 on: Save writes through the repository; the history shows it; M3 off: denied', (t) async {
      view(t);
      final storage = SenseStorage(
          policy: const SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true),
          platform: FakeSecureKeyPlatform(dir));
      final ready = (await t.runAsync(storage.start))! as StorageReady;
      addTearDown(() => t.runAsync(storage.close));
      final person = ready.profile.localPersonId;
      await t.runAsync(() => ready.store.consent.recordChange(person, 'M3', true));

      await t.pumpWidget(SenseStorageScope(
        storage: storage,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const SleepScreen()),
      ));
      await settle(t, () => find.text('No sleep entries saved in the last 7 days yet.').evaluate().isNotEmpty);
      await t.ensureVisible(find.bySemanticsLabel('Rest quality 2 of 5'));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Rest quality 2 of 5'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(save));
      await t.pumpAndSettle();
      await t.tap(find.text(save));
      await settle(t, () => find.byKey(const Key('sleep-history')).evaluate().isNotEmpty);
      final day = LocalDay.fromLocal(DateTime.now()).date;
      final stored = (await t.runAsync(() => ready.store.sleep.byDate(person, day)))!;
      expect([stored.entry.durationMinutes, stored.entry.bedtimeLocal, stored.entry.wakeTimeLocal, stored.entry.restQuality],
          [450, '23:30', '07:00', 2]);
      expect(stored.entry.provenance.changedFields, {'rest_quality'});

      await t.runAsync(() => ready.store.consent.recordChange(person, 'M3', false));
      await t.tap(find.bySemanticsLabel('Rest quality 5 of 5'));
      await t.pumpAndSettle();
      await t.tap(find.text(save));
      await settle(t, () => find.textContaining('Sleep is turned off').evaluate().isNotEmpty);
      final kept = (await t.runAsync(() => ready.store.sleep.byDate(person, day)))!;
      expect(kept.entry.restQuality, 2);
      expect(kept.id, stored.id);
    });
  });
}
