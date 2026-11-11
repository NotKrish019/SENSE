// Milestone K2 on a device or emulator: Workload persistence through the REAL
// development namespace (Android Keystore + SQLCipher + the native lifecycle
// registry and build policy), the storage owner, WorkloadController and the
// existing repository with its in-transaction M4 consent check, across an
// application process restart.
//
// Two runs, with the app process force-stopped in between and the app (so its
// development key and files) kept installed:
//
//   flutter test integration_test/workload_persistence_test.dart -d emulator-5554 \
//       --no-uninstall --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_K2_PHASE=1
//   # phase 1 prints: SENSE-K2-RECORD <id>|<created>|<updated>|<changed>|<default>|<submitted>
//   adb -s emulator-5554 shell am force-stop org.sense.mindpulse.dev
//   flutter test integration_test/workload_persistence_test.dart -d emulator-5554 \
//       --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_K2_PHASE=2 \
//       --dart-define=SENSE_K2_EXPECT='<the phase 1 record line>'
//
// Development test data only. Phase 2 destroys the development namespace at
// the end. An emulator Keystore is software-backed: this is not hardware-backed
// validation and not participant-grade storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/core/state/workload_controller.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';

const int _phase = int.fromEnvironment('SENSE_K2_PHASE');
const String _expect = String.fromEnvironment('SENSE_K2_EXPECT');

String _line(StoredRecord<WorkloadEntry> r) => [
      r.id,
      utc(r.createdAtUtc),
      utc(r.updatedAtUtc),
      (r.entry.provenance.changedFields.toList()..sort()).join(','),
      (r.entry.provenance.defaultFields.toList()..sort()).join(','),
      utc(r.entry.provenance.submittedAtUtc),
      '${r.entry.mentalDemand},${r.entry.effort},${r.entry.deadlines48h}',
      r.entry.day.date,
    ].join('|');

String utc(DateTime t) => t.toUtc().toIso8601String();

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

  Future<int> rows(StorageReady r) async =>
      (await r.database.rawQuery('SELECT COUNT(*) AS n FROM workload_records')).first['n'] as int;

  Future<void> expectNoParticipantStorage() async {
    final p = await platform.inspect();
    for (final k in ['databasePresent', 'envelopePresent', 'keyAliasPresent']) {
      expect(p[k], isFalse, reason: 'participant $k');
    }
  }

  setUpAll(() {
    expect(currentBuildMode, BuildMode.debug);
    expect(kSenseDevStorageDefine, isTrue, reason: 'run with --dart-define=SENSE_DEV_STORAGE=1');
    expect(_phase, anyOf(1, 2), reason: 'pass --dart-define=SENSE_K2_PHASE=1 or 2');
  });

  testWidgets('K2 workload persistence, phase $_phase', (t) async {
    if (_phase == 1) {
      // Start from an empty development namespace.
      final before = await platform.inspect(testNamespace: kDevelopmentStorageNamespace);
      if (before['databasePresent'] == true || before['envelopePresent'] == true || before['keyAliasPresent'] == true) {
        final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
        expect(d.cryptographicallyErased, isTrue);
      }
      final storage = SenseStorage(policy: policy);
      final ready = await openDev(storage);
      final person = ready.profile.localPersonId;

      // 0. Without M4 a save is denied inside the transaction.
      final denied = WorkloadController(access: storage.workload);
      await denied.start();
      expect(await denied.save(), WorkloadSaveResult.consentDenied);
      expect(await rows(ready), 0);
      denied.dispose();

      // 1. M4 is explicitly enabled (an appended consent event).
      await ready.store.consent.recordChange(person, 'M4', true);

      // 2. A workload record is saved through the controller.
      final c = WorkloadController(access: storage.workload);
      await c.start();
      expect(c.hasExistingEntry, isFalse);
      c.setMentalDemand(4);
      c.setEffort(2);
      c.decrementDeadlines(); // zero deadlines: a real observation
      expect(await c.save(), WorkloadSaveResult.saved);
      final saved = c.existingEntry!;
      c.dispose();

      // 3. It loads again, identically.
      final again = WorkloadController(access: storage.workload);
      await again.start();
      expect(_line(again.existingEntry!), _line(saved));
      expect([again.mentalDemand, again.effort, again.deadlines], [4, 2, 0]);
      again.dispose();
      expect(await rows(ready), 1);

      // 4. The database is closed (lease released).
      await storage.close();
      expect(storage.state, isA<StorageClosed>());
      storage.dispose();
      await expectNoParticipantStorage();

      // ignore: avoid_print
      print('SENSE-K2-RECORD ${_line(saved)}');
      return;
    }

    // ---- Phase 2: a new process opens the same development database --------------------------
    expect(_expect, isNotEmpty, reason: 'pass --dart-define=SENSE_K2_EXPECT=<phase 1 record line>');
    final storage = SenseStorage(policy: policy);
    final ready = await openDev(storage);
    final person = ready.profile.localPersonId;

    // 6-7. The record is identical: id, created_at, updated_at, provenance, values, day.
    final c = WorkloadController(access: storage.workload);
    await c.start();
    expect(c.hasExistingEntry, isTrue);
    final restored = c.existingEntry!;
    expect(_line(restored), _expect);
    expect([c.mentalDemand, c.effort, c.deadlines], [4, 2, 0]);
    expect(await ready.store.consent.isEnabled(person, 'M4'), isTrue);

    // 8. Editing updates the same record (no duplicate).
    c.incrementDeadlines();
    expect(await c.save(), WorkloadSaveResult.updated);
    final edited = c.existingEntry!;
    expect(edited.id, restored.id);
    expect(edited.createdAtUtc, restored.createdAtUtc);
    expect(edited.updatedAtUtc.isAfter(restored.updatedAtUtc), isTrue);
    expect(edited.entry.provenance.changedFields, {'mental_demand', 'effort', 'deadlines_48h'});
    expect(await rows(ready), 1);

    // 9-10. M4 is revoked; the next save is denied.
    await ready.store.consent.recordChange(person, 'M4', false);
    c.setEffort(5);
    expect(await c.save(), WorkloadSaveResult.consentDenied);
    expect(c.phase, WorkloadPhase.consentDenied);

    // 11. The previously saved record remains, unchanged by the denied save.
    final kept = (await storage.workload.loadDay(edited.entry.day.date) as WorkloadLoaded).record!;
    expect(_line(kept), _line(edited));
    expect(await rows(ready), 1);
    final history = await ready.store.consent.history(person, modality: 'M4');
    expect(history.map((e) => e.enabled), [true, false]);
    c.dispose();

    await storage.close();
    storage.dispose();
    await expectNoParticipantStorage();
    final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
    expect(d.cryptographicallyErased, isTrue);
    // ignore: avoid_print
    print('SENSE-K2-EVIDENCE phase 2: restored identical record after process restart, updated in place, '
        'revocation denied the next save, record kept; development namespace destroyed');
  });
}
