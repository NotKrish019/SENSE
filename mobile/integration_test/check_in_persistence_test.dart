// Milestone K3 on a device or emulator: Check-in persistence through the REAL
// development namespace (Android Keystore + SQLCipher + the native lifecycle
// registry and build policy), the storage owner, the two-step Check-in screen,
// CheckInController and the existing repository with its in-transaction M1
// consent check, across an application process restart. The screen is driven
// through its UI (mood symbol, slider, Continue, Finish).
//
// Two runs, with the app process force-stopped in between and the app (so its
// development key and files) kept installed:
//
//   flutter test integration_test/check_in_persistence_test.dart -d emulator-5554 \
//       --no-uninstall --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_K3_PHASE=1
//   # phase 1 prints: SENSE-K3-RECORD <id>|<created>|<updated>|<changed>|<default>|<submitted>|<values>|<date>
//   adb -s emulator-5554 shell am force-stop org.sense.mindpulse.dev
//   flutter test integration_test/check_in_persistence_test.dart -d emulator-5554 \
//       --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_K3_PHASE=2 \
//       --dart-define=SENSE_K3_EXPECT='<the phase 1 record line>'
//
// Development test data only. Phase 2 destroys the development namespace at
// the end. An emulator Keystore is software-backed: this is not hardware-backed
// validation and not participant-grade storage.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/check_in_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_storage_scope.dart';

const int _phase = int.fromEnvironment('SENSE_K3_PHASE');
const String _expect = String.fromEnvironment('SENSE_K3_EXPECT');

String utc(DateTime t) => t.toUtc().toIso8601String();

String _line(StoredRecord<CheckInEntry> r) => [
      r.id,
      utc(r.createdAtUtc),
      utc(r.updatedAtUtc),
      (r.entry.provenance.changedFields.toList()..sort()).join(','),
      (r.entry.provenance.defaultFields.toList()..sort()).join(','),
      utc(r.entry.provenance.submittedAtUtc),
      '${r.entry.moodRating},${r.entry.motivationEnergyRating},${r.entry.perceivedStressRating}',
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

  /// The check-in rows, read straight from the encrypted database.
  Future<List<Map<String, Object?>>> rows(StorageReady r) => r.database.query('check_ins');

  Future<void> expectNoParticipantStorage() async {
    final p = await platform.inspect();
    for (final k in ['databasePresent', 'envelopePresent', 'keyAliasPresent']) {
      expect(p[k], isFalse, reason: 'participant $k');
    }
  }

  /// Pumps frames on real time until [done] (database I/O is real here).
  Future<void> until(WidgetTester t, bool Function() done, String what) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: what);
    await t.pumpAndSettle();
  }

  String status(WidgetTester t) => t.widget<Text>(find.byKey(const Key('check-in-status'))).data!;

  Future<void> openScreen(WidgetTester t, SenseStorage storage) async {
    await t.pumpWidget(SenseStorageScope(
      storage: storage,
      child: MaterialApp(theme: AppTheme.lightTheme, home: CheckInScreen(key: UniqueKey())),
    ));
    await until(t, () => find.byKey(const Key('check-in-status')).evaluate().isNotEmpty && !status(t).startsWith('Loading'),
        'today read');
  }

  Future<void> tapText(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    // Let the step transition finish, so only one step is on screen.
    await t.pumpAndSettle();
  }

  /// A slider's own semantics node (its label can also be a heading).
  FinderBase<SemanticsNode> slider(String label) =>
      find.semantics.byPredicate((n) {
        final d = n.getSemanticsData();
        return d.label == label && (d.hasAction(SemanticsAction.increase) || d.hasAction(SemanticsAction.decrease));
      });

  Future<void> stress(WidgetTester t, SemanticsAction a) async {
    // On a phone-sized screen the slider may be scrolled out of view, where
    // it offers no semantics actions.
    await t.ensureVisible(find.byType(Slider));
    await t.pumpAndSettle();
    t.semantics.performAction(slider('Perceived stress'), a);
    await t.pumpAndSettle();
  }

  setUpAll(() {
    expect(currentBuildMode, BuildMode.debug);
    expect(kSenseDevStorageDefine, isTrue, reason: 'run with --dart-define=SENSE_DEV_STORAGE=1');
    expect(_phase, anyOf(1, 2), reason: 'pass --dart-define=SENSE_K3_PHASE=1 or 2');
  });

  testWidgets('K3 check-in persistence, phase $_phase', (t) async {
    final semantics = t.ensureSemantics();
    if (_phase == 1) {
      // 1. Open SENSE storage: the development namespace, from empty.
      final before = await platform.inspect(testNamespace: kDevelopmentStorageNamespace);
      if (before['databasePresent'] == true || before['envelopePresent'] == true || before['keyAliasPresent'] == true) {
        final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
        expect(d.cryptographicallyErased, isTrue);
      }
      final storage = SenseStorage(policy: policy);
      final ready = await openDev(storage);
      final person = ready.profile.localPersonId;

      // 0. Before M1 is on, finishing is refused and nothing is written.
      await openScreen(t, storage);
      await tapText(t, 'Continue to stress rating');
      await tapText(t, 'Finish check-in');
      await until(t, () => find.textContaining('Structured check-ins are turned off').evaluate().isNotEmpty, 'denied');
      expect(find.text('Return to Home'), findsNothing);
      expect(await rows(ready), isEmpty);

      // 2. M1 is explicitly enabled (an appended consent event).
      await ready.store.consent.recordChange(person, 'M1', true);

      // 3. Complete the check-in through the screen: mood Good, stress 4.
      await openScreen(t, storage);
      expect(status(t), startsWith('No check-in saved today yet.'));
      await t.tap(find.bySemanticsLabel('Mood: Good'));
      await t.pumpAndSettle();
      await tapText(t, 'Continue to stress rating');
      await stress(t, SemanticsAction.increase);
      await stress(t, SemanticsAction.increase);
      await tapText(t, 'Finish check-in');
      await until(t, () => find.text('Check-in saved').evaluate().isNotEmpty, 'saved page');

      // 4. The encrypted database holds exactly the expected record.
      final row = (await rows(ready)).single;
      expect(row['local_person_id'], person);
      expect([row['mood_rating'], row['motivation_energy_rating'], row['perceived_stress_rating']], [4, 3, 4]);
      expect(row['changed_fields'], '["mood_rating","perceived_stress_rating"]');
      expect(row['default_fields'], '["motivation_energy_rating"]');
      final saved = (await ready.store.checkIns.byDate(person, row['local_date'] as String))!;
      expect(saved.id, row['id']);

      // 5. Close the database (lease released).
      await t.pumpWidget(const SizedBox());
      await storage.close();
      expect(storage.state, isA<StorageClosed>());
      storage.dispose();
      await expectNoParticipantStorage();
      semantics.dispose();
      // ignore: avoid_print
      print('SENSE-K3-RECORD ${_line(saved)}');
      return;
    }

    // ---- Phase 2: a fresh process opens the same development database ------------------------
    expect(_expect, isNotEmpty, reason: 'pass --dart-define=SENSE_K3_EXPECT=<phase 1 record line>');
    final storage = SenseStorage(policy: policy);
    final ready = await openDev(storage);
    final person = ready.profile.localPersonId;

    // 8. The exact record is reloaded, and the screen is prefilled from it.
    final row = (await rows(ready)).single;
    final restored = (await ready.store.checkIns.byDate(person, row['local_date'] as String))!;
    expect(_line(restored), _expect);
    await openScreen(t, storage);
    expect(status(t), startsWith('You already completed a check-in today.'));
    expect(t.getSemantics(find.bySemanticsLabel('Mood: Good')).getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue);

    // 9-10. Change the answers (motivation 4, stress 3) and finish again.
    await t.ensureVisible(find.byType(Slider));
    await t.pumpAndSettle();
    t.semantics.performAction(slider('Motivation or energy level'), SemanticsAction.increase);
    await t.pumpAndSettle();
    await tapText(t, 'Continue to stress rating');
    expect(t.getSemantics(find.byType(Slider)).getSemanticsData().value, '4 of 5');
    await stress(t, SemanticsAction.decrease);
    await tapText(t, 'Finish check-in');
    await until(t, () => find.text('Check-in updated').evaluate().isNotEmpty, 'updated page');

    // 11. Same id and created_at; new values, provenance and update time; one row.
    final rows2 = await rows(ready);
    expect(rows2, hasLength(1));
    final edited = (await ready.store.checkIns.byDate(person, restored.entry.day.date))!;
    expect(edited.id, restored.id);
    expect(edited.createdAtUtc, restored.createdAtUtc);
    expect(edited.updatedAtUtc.isAfter(restored.updatedAtUtc), isTrue);
    expect([edited.entry.moodRating, edited.entry.motivationEnergyRating, edited.entry.perceivedStressRating], [4, 4, 3]);
    expect(edited.entry.provenance.changedFields, {'mood_rating', 'motivation_energy_rating', 'perceived_stress_rating'});

    // 12-14. Revoke M1; another Finish is denied; the previous record remains.
    await ready.store.consent.recordChange(person, 'M1', false);
    await openScreen(t, storage);
    await tapText(t, 'Continue to stress rating');
    await stress(t, SemanticsAction.increase);
    await tapText(t, 'Finish check-in');
    await until(t, () => find.textContaining('Structured check-ins are turned off').evaluate().isNotEmpty, 'denied');
    expect(find.text('Return to Home'), findsNothing);
    final kept = (await ready.store.checkIns.byDate(person, restored.entry.day.date))!;
    expect(_line(kept), _line(edited));
    expect(await rows(ready), hasLength(1));
    expect((await ready.store.consent.history(person, modality: 'M1')).map((e) => e.enabled), [true, false]);

    await t.pumpWidget(const SizedBox());
    await storage.close();
    storage.dispose();
    await expectNoParticipantStorage();
    final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
    expect(d.cryptographicallyErased, isTrue);
    semantics.dispose();
    // ignore: avoid_print
    print('SENSE-K3-EVIDENCE phase 2: identical record reloaded after process restart, prefilled, updated in place '
        'through the screen, revocation denied the next Finish, record kept; development namespace destroyed');
  });
}
