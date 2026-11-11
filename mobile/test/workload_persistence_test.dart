// Milestone K2: workload persistence through the real storage owner, the
// narrow WorkloadAccess, the existing WorkloadRepository and its in-transaction
// M4 consent check. Storage is the test-only FakeSecureKeyPlatform (disposable
// plain SQLite through sqflite_common_ffi), so the real provider, owner,
// repositories and controller run on the host. On-device encrypted behaviour
// is covered by integration_test/workload_persistence_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/state/workload_controller.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_secure_key_platform.dart';

const _debugDev = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true);
const _debugDefault = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: false);
const _profileDev = SenseStoragePolicy(buildMode: BuildMode.profile, developmentDefine: true);

void main() {
  late Directory dir;
  final owners = <SenseStorage>[];

  setUpAll(sqfliteFfiInit);
  setUp(() => dir = Directory.systemTemp.createTempSync('sense_k2_'));
  tearDown(() async {
    for (final s in owners) {
      await s.close();
    }
    owners.clear();
    ConsentPreferences.instance.reset();
    dir.deleteSync(recursive: true);
  });

  // A strictly increasing UTC clock so created/updated times are distinguishable.
  var tick = DateTime.utc(2026, 11, 11, 3);
  DateTime clock() => tick = tick.add(const Duration(seconds: 1));

  Future<(SenseStorage, StorageReady)> openDev({FakeSecureKeyPlatform? platform}) async {
    final s = SenseStorage(policy: _debugDev, platform: platform ?? FakeSecureKeyPlatform(dir), clock: clock);
    owners.add(s);
    final r = await s.start();
    expect(r, isA<StorageReady>(), reason: '$r');
    return (s, r as StorageReady);
  }

  final day = LocalDay.fromLocal(DateTime(2026, 11, 11, 9));

  WorkloadEntry entry({int demand = 3, int effort = 3, int deadlines = 1, Set<String> changed = const {}}) =>
      WorkloadEntry(
        mentalDemand: demand,
        effort: effort,
        deadlines48h: deadlines,
        day: day,
        provenance: Provenance.fromChanged(
            allFields: WorkloadEntry.allFields, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11, 3, 30)),
      );

  Future<void> setM4(StorageReady r, bool on) => r.store.consent.recordChange(r.profile.localPersonId, 'M4', on);

  Future<int> rows(StorageReady r) async =>
      (await r.database.rawQuery('SELECT COUNT(*) AS n FROM workload_records')).first['n'] as int;

  group('Repository through WorkloadAccess', () {
    test('M4 never turned on: the write is denied in the transaction and nothing is written', () async {
      final (s, r) = await openDev();
      final out = await s.workload.save(entry(demand: 4, changed: {'mental_demand'}));
      expect(out, isA<WorkloadConsentDenied>());
      expect((out as WorkloadConsentDenied).reason, ConsentDenialReason.notRecorded);
      expect(await rows(r), 0);
    });

    test('M4 on: inserted with the exact columns, provenance and identity; byDate returns it', () async {
      final (s, r) = await openDev();
      await setM4(r, true);
      final out = await s.workload.save(entry(demand: 4, effort: 2, deadlines: 0, changed: {'mental_demand', 'effort', 'deadlines_48h'}));
      expect(out, isA<WorkloadSaved>());
      final saved = out as WorkloadSaved;
      expect(saved.updated, isFalse);

      final row = (await r.database.query('workload_records')).single;
      expect(row['id'], saved.record.id);
      expect(row['local_person_id'], r.profile.localPersonId);
      expect(row['local_date'], '2026-11-11');
      expect(row['tz_offset_minutes'], day.tzOffsetMinutes);
      expect([row['mental_demand'], row['effort'], row['deadlines_48h']], [4, 2, 0]);
      expect(row['changed_fields'], '["deadlines_48h","effort","mental_demand"]');
      expect(row['default_fields'], '[]');
      expect(row['explicitly_submitted'], 1);
      expect(row['schema_version'], kSchemaVersion);
      expect(row['created_at_utc'], row['updated_at_utc']);

      final loaded = await s.workload.loadDay('2026-11-11') as WorkloadLoaded;
      expect(loaded.record!.id, saved.record.id);
      expect(loaded.record!.entry.deadlines48h, 0, reason: 'zero deadlines is a stored value, not missing');
      expect(loaded.record!.entry.provenance, saved.record.entry.provenance);
      expect((await s.workload.loadDay('2026-11-10') as WorkloadLoaded).record, isNull);
    });

    test('a second save for the same day updates the same record (one row; id and created_at kept)', () async {
      final (s, r) = await openDev();
      await setM4(r, true);
      final first = await s.workload.save(entry(demand: 2, changed: {'mental_demand'})) as WorkloadSaved;
      final second = await s.workload.save(entry(demand: 5, deadlines: 3, changed: {'mental_demand', 'deadlines_48h'}))
          as WorkloadSaved;
      expect(second.updated, isTrue);
      expect(second.record.id, first.record.id);
      expect(second.record.createdAtUtc, first.record.createdAtUtc);
      expect(second.record.updatedAtUtc.isAfter(first.record.updatedAtUtc), isTrue);
      expect(await rows(r), 1);
      final stored = (await s.workload.loadDay(day.date) as WorkloadLoaded).record!;
      expect([stored.entry.mentalDemand, stored.entry.deadlines48h], [5, 3]);
      expect(stored.entry.provenance.changedFields, {'mental_demand', 'deadlines_48h'});
      expect(stored.entry.provenance.defaultFields, {'effort'});
      expect(stored.createdAtUtc, first.record.createdAtUtc);
    });

    test('revocation blocks later writes and keeps the earlier record unchanged', () async {
      final (s, r) = await openDev();
      await setM4(r, true);
      final kept = await s.workload.save(entry(demand: 4, changed: {'mental_demand'})) as WorkloadSaved;
      await setM4(r, false);
      final out = await s.workload.save(entry(demand: 1, changed: {'mental_demand'}));
      expect((out as WorkloadConsentDenied).reason, ConsentDenialReason.disabled);
      expect(await rows(r), 1);
      final still = (await s.workload.loadDay(day.date) as WorkloadLoaded).record!;
      expect(still.entry.mentalDemand, 4);
      expect(still.updatedAtUtc, kept.record.updatedAtUtc);
      // History is append-only: ON then OFF.
      final history = await r.store.consent.history(r.profile.localPersonId, modality: 'M4');
      expect(history.map((e) => e.enabled), [true, false]);
    });

    test('a revocation racing a save: the transaction order decides; the database stays consistent', () async {
      final (s, r) = await openDev();
      await setM4(r, true);
      final save = s.workload.save(entry(demand: 5, changed: {'mental_demand'}));
      final revoke = setM4(r, false);
      final out = await save;
      await revoke;
      if (out is WorkloadSaved) {
        expect(await rows(r), 1, reason: 'committed before the revocation');
      } else {
        expect(out, isA<WorkloadConsentDenied>());
        expect(await rows(r), 0, reason: 'denied after the revocation: nothing written');
      }
      expect(await s.workload.save(entry(demand: 2, changed: {'mental_demand'})), isA<WorkloadConsentDenied>());
    });

    test('an in-memory preference never authorizes a write', () async {
      final (s, r) = await openDev();
      final prefs = ConsentPreferences(); // not attached: memory only
      await prefs.setEnabled(InputModality.workload, true);
      expect(prefs.isEnabled(InputModality.workload), isTrue);
      expect(await s.workload.save(entry()), isA<WorkloadConsentDenied>());
      expect(await rows(r), 0);
    });

    test('invalid values are refused before any write', () async {
      final (s, r) = await openDev();
      await setM4(r, true);
      final out = await s.workload.save(entry(deadlines: 21, changed: {'deadlines_48h'}));
      expect((out as WorkloadSaveInvalid).field, 'deadlines_48h');
      // A value off its default marked as an untouched default is invalid too.
      expect(await s.workload.save(entry(demand: 5)), isA<WorkloadSaveInvalid>());
      expect(await rows(r), 0);
    });

    test('a closed connection is a typed failure, never success', () async {
      final (s, r) = await openDev();
      await setM4(r, true);
      await r.database.close(); // simulate the connection going away under the owner
      expect(await s.workload.save(entry()), isA<WorkloadSaveFailed>());
      expect(await s.workload.loadDay(day.date), isA<WorkloadLoadFailed>());
    });
  });

  group('Availability follows the storage owner', () {
    test('default debug build (no define): not connected, nothing opened, nothing written', () async {
      final platform = FakeSecureKeyPlatform(dir);
      final s = SenseStorage(policy: _debugDefault, platform: platform);
      owners.add(s);
      expect(s.workload.status, WorkloadStorageStatus.notConnected);
      await s.start();
      expect(s.workload.status, WorkloadStorageStatus.notConnected);
      expect(await s.workload.save(entry()), isA<WorkloadSaveUnavailable>());
      expect(await s.workload.loadDay(day.date), isA<WorkloadLoadUnavailable>());
      expect(platform.calls, isNot(contains('openKey')));
    });

    test('profile build with the define: not connected; development storage is never opened', () async {
      final platform = FakeSecureKeyPlatform(dir);
      final s = SenseStorage(policy: _profileDev, platform: platform);
      owners.add(s);
      await s.start();
      expect(s.workload.status, WorkloadStorageStatus.notConnected);
      expect(platform.openKeyNamespaces, isEmpty);
      expect(await s.workload.save(entry()), isA<WorkloadSaveUnavailable>());
    });

    test('an open failure is unavailable; closing makes it unavailable; development is flagged', () async {
      final failing = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir, failWith: 'keyInvalidated'));
      owners.add(failing);
      await failing.start();
      expect(failing.workload.status, WorkloadStorageStatus.unavailable);

      final (s, _) = await openDev(platform: FakeSecureKeyPlatform(Directory('${dir.path}/b')..createSync()));
      expect(s.workload.status, WorkloadStorageStatus.open);
      expect(s.workload.isDevelopment, isTrue);
      await s.close();
      expect(s.workload.status, WorkloadStorageStatus.unavailable);
      expect(await s.workload.save(entry()), isA<WorkloadSaveUnavailable>());
    });
  });

  group('Controller end to end (host)', () {
    test('save, close, reopen: the entry is reloaded and edited in place', () async {
      final now = DateTime(2026, 11, 11, 9);
      var (s, r) = await openDev();
      await setM4(r, true);
      final c1 = WorkloadController(access: s.workload, now: () => now);
      await c1.start();
      c1.setMentalDemand(4);
      c1.decrementDeadlines();
      expect(await c1.save(), WorkloadSaveResult.saved);
      final first = c1.existingEntry!;
      c1.dispose();
      await s.close();

      (s, r) = await openDev(); // same directory: same database
      final c2 = WorkloadController(access: s.workload, now: () => now);
      addTearDown(c2.dispose);
      await c2.start();
      expect(c2.hasExistingEntry, isTrue);
      expect([c2.mentalDemand, c2.effort, c2.deadlines], [4, 3, 0]);
      expect(c2.existingEntry!.id, first.id);
      expect(c2.existingEntry!.createdAtUtc, first.createdAtUtc);
      expect(c2.existingEntry!.entry.provenance.changedFields, {'mental_demand', 'deadlines_48h'});

      c2.setEffort(5);
      expect(await c2.save(), WorkloadSaveResult.updated);
      expect(c2.existingEntry!.id, first.id);
      expect(c2.existingEntry!.entry.provenance.changedFields, {'mental_demand', 'deadlines_48h', 'effort'});
      expect(await rows(r), 1);

      await setM4(r, false);
      c2.setEffort(1);
      expect(await c2.save(), WorkloadSaveResult.consentDenied);
      final kept = (await s.workload.loadDay(day.date) as WorkloadLoaded).record!;
      expect(kept.entry.effort, 5, reason: 'the earlier record remains after revocation');
    });
  });
}
