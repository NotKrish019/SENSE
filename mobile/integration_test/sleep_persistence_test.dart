// Milestone K4 on a device or emulator: Sleep persistence through the REAL
// development namespace (Android Keystore + SQLCipher + the native lifecycle
// registry and build policy), the storage owner, the Sleep screen,
// SleepController and the existing repository with its in-transaction M3
// consent check, across an application process restart. The screen is
// driven through its UI (time pickers, duration slider, stars, Save).
//
// Two runs, with the app process force-stopped in between and the app (so its
// development key and files) kept installed:
//
//   flutter test integration_test/sleep_persistence_test.dart -d emulator-5554 \
//       --no-uninstall --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_K4_PHASE=1
//   # phase 1 prints: SENSE-K4-RECORD <id>|<created>|<updated>|<changed>|<default>|<submitted>|<values>|<date>
//   adb -s emulator-5554 shell am force-stop org.sense.mindpulse.dev
//   flutter test integration_test/sleep_persistence_test.dart -d emulator-5554 \
//       --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_K4_PHASE=2 \
//       --dart-define=SENSE_K4_EXPECT='<the phase 1 record line>'
//
// Synthetic development data only. Phase 2 destroys the development namespace
// at the end. An emulator Keystore is software-backed: this is not
// hardware-backed validation and not participant-grade storage.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/sleep_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_storage_scope.dart';

const int _phase = int.fromEnvironment('SENSE_K4_PHASE');
const String _expect = String.fromEnvironment('SENSE_K4_EXPECT');

String utc(DateTime t) => t.toUtc().toIso8601String();

String _line(StoredRecord<SleepEntry> r) => [
      r.id,
      utc(r.createdAtUtc),
      utc(r.updatedAtUtc),
      (r.entry.provenance.changedFields.toList()..sort()).join(','),
      (r.entry.provenance.defaultFields.toList()..sort()).join(','),
      utc(r.entry.provenance.submittedAtUtc),
      '${r.entry.durationMinutes},${r.entry.bedtimeLocal},${r.entry.wakeTimeLocal},${r.entry.restQuality}',
      r.entry.day.date,
    ].join('|');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = createDefaultSecureKeyPlatform();
  final policy = SenseStoragePolicy.fromEnvironment();

  Future<StorageReady> openDev(SenseStorage s) async {
    final r = await s.start();
    expect(r, isA<StorageReady>(), reason: '$r');
    final ready = r as StorageReady;
    expect(ready.target, StorageTarget.development);
    expect(ready.productionEligible, isFalse);
    expect(ready.database.path, contains('/test_namespaces/dev_storage/sense_encrypted_v1.db'));
    expect(ready.cipherVersion, startsWith(kExpectedSqlCipherVersion));
    return ready;
  }

  Future<List<Map<String, Object?>>> rows(StorageReady r) => r.database.query('sleep_records');

  Future<void> expectNoParticipantStorage() async {
    final p = await platform.inspect();
    for (final k in ['databasePresent', 'envelopePresent', 'keyAliasPresent']) {
      expect(p[k], isFalse, reason: 'participant $k');
    }
  }

  Future<void> until(WidgetTester t, bool Function() done, String what) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: what);
    await t.pumpAndSettle();
  }

  String status(WidgetTester t) => t.widget<Text>(find.byKey(const Key('sleep-status'))).data!;

  Future<void> openScreen(WidgetTester t, SenseStorage storage) async {
    await t.pumpWidget(SenseStorageScope(
      storage: storage,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        // 24-hour display, so the picker's text input is locale independent.
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
        home: SleepScreen(key: UniqueKey()),
      ),
    ));
    await until(
        t, () => find.byKey(const Key('sleep-status')).evaluate().isNotEmpty && !status(t).startsWith('Loading'), 'read');
  }

  Future<void> tapVisible(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> pickTime(WidgetTester t, String label, int hour, int minute) async {
    await tapVisible(t, find.bySemanticsLabel(RegExp('^$label: .*Tap to change')));
    await t.tap(find.byIcon(Icons.keyboard_outlined));
    await t.pumpAndSettle();
    final inputs = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    await t.enterText(inputs.at(0), '$hour'.padLeft(2, '0'));
    await t.enterText(inputs.at(1), '$minute'.padLeft(2, '0'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
  }

  Future<void> durationStep(WidgetTester t, SemanticsAction a) async {
    await t.ensureVisible(find.byType(Slider));
    await t.pumpAndSettle();
    t.semantics.performAction(find.semantics.byPredicate((n) {
      final d = n.getSemanticsData();
      return d.label == 'Sleep duration' && (d.hasAction(SemanticsAction.increase) || d.hasAction(SemanticsAction.decrease));
    }), a);
    await t.pumpAndSettle();
  }

  Future<void> save(WidgetTester t) async {
    // Feedback is inline (no floating message), so Save is reachable at once.
    await t.ensureVisible(find.text('Save Sleep Record'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save Sleep Record'));
    await t.pump();
  }

  setUpAll(() {
    expect(currentBuildMode, BuildMode.debug);
    expect(kSenseDevStorageDefine, isTrue, reason: 'run with --dart-define=SENSE_DEV_STORAGE=1');
    expect(_phase, anyOf(1, 2), reason: 'pass --dart-define=SENSE_K4_PHASE=1 or 2');
  });

  testWidgets('K4 sleep persistence, phase $_phase', (t) async {
    final semantics = t.ensureSemantics();
    if (_phase == 1) {
      // 1. The development namespace, from empty.
      final before = await platform.inspect(testNamespace: kDevelopmentStorageNamespace);
      if (before['databasePresent'] == true || before['envelopePresent'] == true || before['keyAliasPresent'] == true) {
        final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
        expect(d.cryptographicallyErased, isTrue);
      }
      final storage = SenseStorage(policy: policy);
      final ready = await openDev(storage);
      final person = ready.profile.localPersonId;
      final wakeDay = LocalDay.fromLocal(DateTime.now()).date;

      // Before M3 is on, Save is refused and nothing is written.
      await openScreen(t, storage);
      await save(t);
      await until(t, () => find.textContaining('Sleep is turned off').evaluate().isNotEmpty, 'denied');
      expect(await rows(ready), isEmpty);

      // 2. M3 is explicitly enabled (an appended consent event).
      await ready.store.consent.recordChange(person, 'M3', true);

      // 3-4. A night crossing midnight, entered through the screen: bedtime
      // 23:45, wake 06:50, duration 7.0 hours, quality 3. Then Save.
      await openScreen(t, storage);
      expect(status(t), startsWith('No sleep entry saved today yet.'));
      await pickTime(t, 'Bedtime', 23, 45);
      await pickTime(t, 'Wake time', 6, 50);
      await durationStep(t, SemanticsAction.decrease);
      await tapVisible(t, find.bySemanticsLabel('Rest quality 3 of 5'));
      await save(t);
      await until(t, () => find.textContaining("Last night's sleep was saved").evaluate().isNotEmpty, 'saved');

      // 5-6. The encrypted database holds it under the WAKE-UP date, exactly.
      final row = (await rows(ready)).single;
      expect(row['local_date'], wakeDay, reason: 'the date of wake-up, not the bedtime date');
      expect(row['duration_minutes'], 420);
      expect(row['bedtime_local'], '23:45');
      expect(row['wake_time_local'], '06:50');
      expect(row['rest_quality'], 3);
      expect(row['source'], 'MANUAL_LOG');
      expect(row['changed_fields'], '["bedtime_local","duration_minutes","rest_quality","wake_time_local"]');
      final saved = (await ready.store.sleep.byDate(person, wakeDay))!;

      // 7. Close the database (lease released).
      await t.pumpWidget(const SizedBox());
      await storage.close();
      expect(storage.state, isA<StorageClosed>());
      storage.dispose();
      await expectNoParticipantStorage();
      semantics.dispose();
      // ignore: avoid_print
      print('SENSE-K4-RECORD ${_line(saved)}');
      return;
    }

    // ---- Phase 2: a fresh process opens the same development database ------------------------
    expect(_expect, isNotEmpty, reason: 'pass --dart-define=SENSE_K4_EXPECT=<phase 1 record line>');
    final storage = SenseStorage(policy: policy);
    final ready = await openDev(storage);
    final person = ready.profile.localPersonId;

    // 10. The same record and provenance; the screen is prefilled from it.
    final row = (await rows(ready)).single;
    final restored = (await ready.store.sleep.byDate(person, row['local_date'] as String))!;
    expect(_line(restored), _expect);
    await openScreen(t, storage);
    expect(status(t), startsWith("You already saved last night's sleep today."));
    expect(find.bySemanticsLabel('Bedtime: 23:45. Tap to change.'), findsOneWidget);
    expect(find.bySemanticsLabel('Wake time: 06:50. Tap to change.'), findsOneWidget);
    expect(t.getSemantics(find.byType(Slider)).getSemanticsData().value, '7.0 hours');
    expect(t.getSemantics(find.bySemanticsLabel('Rest quality 3 of 5')).getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue);
    expect(find.byKey(const Key('sleep-history')), findsOneWidget, reason: 'history from the stored record');

    // 11-12. Edit (quality 5, duration 7.5) and save: same id and created_at.
    await tapVisible(t, find.bySemanticsLabel('Rest quality 5 of 5'));
    await durationStep(t, SemanticsAction.increase);
    await save(t);
    await until(t, () => find.text("Today's sleep entry was updated.").evaluate().isNotEmpty, 'updated');
    expect(await rows(ready), hasLength(1));
    final edited = (await ready.store.sleep.byDate(person, restored.entry.day.date))!;
    expect(edited.id, restored.id);
    expect(edited.createdAtUtc, restored.createdAtUtc);
    expect(edited.updatedAtUtc.isAfter(restored.updatedAtUtc), isTrue);
    expect([edited.entry.durationMinutes, edited.entry.restQuality], [450, 5]);
    expect(edited.entry.provenance.changedFields, restored.entry.provenance.changedFields,
        reason: 'all four were already changed; 7.5 h is back at the default but stays changed');

    // 13-15. Revoke M3; the next Save is denied; the record remains.
    await ready.store.consent.recordChange(person, 'M3', false);
    await tapVisible(t, find.bySemanticsLabel('Rest quality 1 of 5'));
    await save(t);
    await until(t, () => find.textContaining('Sleep is turned off').evaluate().isNotEmpty, 'denied');
    final kept = (await ready.store.sleep.byDate(person, restored.entry.day.date))!;
    expect(_line(kept), _line(edited));
    expect(await rows(ready), hasLength(1));
    expect((await ready.store.consent.history(person, modality: 'M3')).map((e) => e.enabled), [true, false]);

    await t.pumpWidget(const SizedBox());
    await storage.close();
    storage.dispose();
    await expectNoParticipantStorage();
    final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
    expect(d.cryptographicallyErased, isTrue);
    semantics.dispose();
    // ignore: avoid_print
    print('SENSE-K4-EVIDENCE phase 2: identical record under the wake-up date after process restart, prefilled, '
        'updated in place through the screen, revocation denied the next Save, record kept; namespace destroyed');
  });
}
