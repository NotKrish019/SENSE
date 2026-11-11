// Milestone K3: check-in persistence through the real storage owner, the
// narrow CheckInAccess, the existing CheckInRepository and its in-transaction
// M1 consent check. Storage is the test-only FakeSecureKeyPlatform (disposable
// plain SQLite through sqflite_common_ffi). On-device encrypted behaviour is
// covered by integration_test/check_in_persistence_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/check_in_controller.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
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
  setUp(() => dir = Directory.systemTemp.createTempSync('sense_k3_'));
  tearDown(() async {
    for (final s in owners) {
      await s.close();
    }
    owners.clear();
    ConsentPreferences.instance.reset();
    dir.deleteSync(recursive: true);
  });

  var tick = DateTime.utc(2026, 11, 11, 14);
  DateTime clock() => tick = tick.add(const Duration(seconds: 1));

  Future<(SenseStorage, StorageReady)> openDev({FakeSecureKeyPlatform? platform}) async {
    final s = SenseStorage(policy: _debugDev, platform: platform ?? FakeSecureKeyPlatform(dir), clock: clock);
    owners.add(s);
    final r = await s.start();
    expect(r, isA<StorageReady>(), reason: '$r');
    return (s, r as StorageReady);
  }

  final day = LocalDay.fromLocal(DateTime(2026, 11, 11, 20));

  CheckInEntry entry({int mood = 3, int motivation = 3, int stress = 2, Set<String> changed = const {}}) =>
      CheckInEntry(
        moodRating: mood,
        motivationEnergyRating: motivation,
        perceivedStressRating: stress,
        day: day,
        provenance: Provenance.fromChanged(
            allFields: CheckInEntry.allFields, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11, 14, 30)),
      );

  Future<void> setM1(StorageReady r, bool on) => r.store.consent.recordChange(r.profile.localPersonId, 'M1', on);

  Future<int> rows(StorageReady r) async =>
      (await r.database.rawQuery('SELECT COUNT(*) AS n FROM check_ins')).first['n'] as int;

  group('Repository through CheckInAccess', () {
    test('M1 never turned on: denied in the transaction; nothing written', () async {
      final (s, r) = await openDev();
      final out = await s.checkIn.save(entry(mood: 5, changed: {'mood_rating'}));
      expect((out as CheckInConsentDenied).reason, ConsentDenialReason.notRecorded);
      expect(await rows(r), 0);
    });

    test('M1 on: inserted with the exact columns, provenance and identity; byDate returns it', () async {
      final (s, r) = await openDev();
      await setM1(r, true);
      final saved = await s.checkIn.save(entry(mood: 4, motivation: 2, stress: 5,
          changed: {'mood_rating', 'motivation_energy_rating', 'perceived_stress_rating'})) as CheckInSaved;
      expect(saved.updated, isFalse);
      final row = (await r.database.query('check_ins')).single;
      expect(row['id'], saved.record.id);
      expect(row['local_person_id'], r.profile.localPersonId);
      expect(row['local_date'], '2026-11-11');
      expect(row['tz_offset_minutes'], day.tzOffsetMinutes);
      expect([row['mood_rating'], row['motivation_energy_rating'], row['perceived_stress_rating']], [4, 2, 5]);
      expect(row['changed_fields'], '["mood_rating","motivation_energy_rating","perceived_stress_rating"]');
      expect(row['default_fields'], '[]');
      expect(row['explicitly_submitted'], 1);
      expect(row['schema_version'], kSchemaVersion);

      final loaded = (await s.checkIn.loadDay('2026-11-11') as CheckInLoaded).record!;
      expect(loaded.id, saved.record.id);
      expect(loaded.entry.provenance, saved.record.entry.provenance);
      expect((await s.checkIn.loadDay('2026-11-10') as CheckInLoaded).record, isNull);
      expect(await rows(r), 1);
      // Workload is a separate table and modality.
      expect((await r.database.query('workload_records')), isEmpty);
    });

    test('a second save the same day updates the same record (one row; id and created_at kept)', () async {
      final (s, r) = await openDev();
      await setM1(r, true);
      final first = await s.checkIn.save(entry(stress: 4, changed: {'perceived_stress_rating'})) as CheckInSaved;
      final second = await s.checkIn.save(entry(mood: 1, stress: 4, changed: {'mood_rating', 'perceived_stress_rating'}))
          as CheckInSaved;
      expect(second.updated, isTrue);
      expect(second.record.id, first.record.id);
      expect(second.record.createdAtUtc, first.record.createdAtUtc);
      expect(second.record.updatedAtUtc.isAfter(first.record.updatedAtUtc), isTrue);
      expect(await rows(r), 1);
      final stored = (await s.checkIn.loadDay(day.date) as CheckInLoaded).record!;
      expect(stored.entry.moodRating, 1);
      expect(stored.entry.provenance.changedFields, {'mood_rating', 'perceived_stress_rating'});
      expect(stored.entry.provenance.defaultFields, {'motivation_energy_rating'});
    });

    test('revocation blocks later writes and keeps the earlier record unchanged', () async {
      final (s, r) = await openDev();
      await setM1(r, true);
      final kept = await s.checkIn.save(entry(mood: 4, changed: {'mood_rating'})) as CheckInSaved;
      await setM1(r, false);
      final out = await s.checkIn.save(entry(mood: 1, changed: {'mood_rating'}));
      expect((out as CheckInConsentDenied).reason, ConsentDenialReason.disabled);
      final still = (await s.checkIn.loadDay(day.date) as CheckInLoaded).record!;
      expect(still.entry.moodRating, 4);
      expect(still.updatedAtUtc, kept.record.updatedAtUtc);
      expect(await rows(r), 1);
    });

    test('M4 (Workload) does not authorize a check-in; M1 does not authorize a workload record', () async {
      final (s, r) = await openDev();
      await r.store.consent.recordChange(r.profile.localPersonId, 'M4', true);
      expect(await s.checkIn.save(entry()), isA<CheckInConsentDenied>(), reason: 'M4 is not M1');
      await setM1(r, true);
      await r.store.consent.recordChange(r.profile.localPersonId, 'M4', false);
      expect(await s.checkIn.save(entry()), isA<CheckInSaved>());
      final w = WorkloadEntry(
          mentalDemand: 3,
          effort: 3,
          deadlines48h: 1,
          day: day,
          provenance: Provenance.fromChanged(
              allFields: WorkloadEntry.allFields, changed: const {}, submittedAtUtc: DateTime.utc(2026, 11, 11)));
      expect(await s.workload.save(w), isA<WorkloadConsentDenied>());
    });

    test('a revocation racing a save: the transaction order decides; the database stays consistent', () async {
      final (s, r) = await openDev();
      await setM1(r, true);
      final save = s.checkIn.save(entry(mood: 5, changed: {'mood_rating'}));
      final revoke = setM1(r, false);
      final out = await save;
      await revoke;
      expect(await rows(r), out is CheckInSaved ? 1 : 0);
      if (out is! CheckInSaved) expect(out, isA<CheckInConsentDenied>());
      expect(await s.checkIn.save(entry(mood: 2, changed: {'mood_rating'})), isA<CheckInConsentDenied>());
    });

    test('an in-memory preference never authorizes a write', () async {
      final (s, r) = await openDev();
      final prefs = ConsentPreferences(); // not attached: memory only
      await prefs.setEnabled(InputModality.checkIn, true);
      expect(prefs.isEnabled(InputModality.checkIn), isTrue);
      expect(await s.checkIn.save(entry()), isA<CheckInConsentDenied>());
      expect(await rows(r), 0);
    });

    test('invalid values are refused before any write', () async {
      final (s, r) = await openDev();
      await setM1(r, true);
      expect(await s.checkIn.save(entry(mood: 6, changed: {'mood_rating'})), isA<CheckInSaveInvalid>());
      // A non-default value marked as an untouched default is invalid too.
      expect(await s.checkIn.save(entry(stress: 5)), isA<CheckInSaveInvalid>());
      expect(await rows(r), 0);
    });

    test('a closed connection is a typed failure, never success', () async {
      final (s, r) = await openDev();
      await setM1(r, true);
      await r.database.close();
      expect(await s.checkIn.save(entry()), isA<CheckInSaveFailed>());
      expect(await s.checkIn.loadDay(day.date), isA<CheckInLoadFailed>());
    });
  });

  group('Availability follows the storage owner', () {
    test('default debug build: not connected; nothing opened', () async {
      final platform = FakeSecureKeyPlatform(dir);
      final s = SenseStorage(policy: _debugDefault, platform: platform);
      owners.add(s);
      await s.start();
      expect(s.checkIn.status, CheckInStorageStatus.notConnected);
      expect(await s.checkIn.save(entry()), isA<CheckInSaveUnavailable>());
      expect(platform.calls, isNot(contains('openKey')));
    });

    test('profile build with the define: not connected; development storage never opened', () async {
      final platform = FakeSecureKeyPlatform(dir);
      final s = SenseStorage(policy: _profileDev, platform: platform);
      owners.add(s);
      await s.start();
      expect(s.checkIn.status, CheckInStorageStatus.notConnected);
      expect(platform.openKeyNamespaces, isEmpty);
    });

    test('an open failure is unavailable; closing makes it unavailable; development is flagged', () async {
      final failing = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir, failWith: 'keyInvalidated'));
      owners.add(failing);
      await failing.start();
      expect(failing.checkIn.status, CheckInStorageStatus.unavailable);

      final (s, _) = await openDev(platform: FakeSecureKeyPlatform(Directory('${dir.path}/b')..createSync()));
      expect(s.checkIn.status, CheckInStorageStatus.open);
      expect(s.checkIn.isDevelopment, isTrue);
      await s.close();
      expect(s.checkIn.status, CheckInStorageStatus.unavailable);
      expect(await s.checkIn.save(entry()), isA<CheckInSaveUnavailable>());
    });
  });

  group('Controller end to end (host)', () {
    test('save, close, reopen: the check-in is reloaded and updated in place', () async {
      final now = DateTime(2026, 11, 11, 20);
      var (s, r) = await openDev();
      await setM1(r, true);
      final c1 = CheckInController(access: s.checkIn, now: () => now);
      await c1.start();
      c1.setMood(5);
      c1.setStress(4);
      expect(await c1.save(), CheckInSaveResult.saved);
      final first = c1.existingEntry!;
      c1.dispose();
      await s.close();

      (s, r) = await openDev();
      final c2 = CheckInController(access: s.checkIn, now: () => now);
      addTearDown(c2.dispose);
      await c2.start();
      expect(c2.hasExistingEntry, isTrue);
      expect([c2.mood, c2.motivation, c2.stress], [5, 3, 4]);
      expect(c2.existingEntry!.id, first.id);
      expect(c2.existingEntry!.createdAtUtc, first.createdAtUtc);
      c2.setMotivation(1);
      expect(await c2.save(), CheckInSaveResult.updated);
      expect(c2.existingEntry!.id, first.id);
      expect(c2.existingEntry!.entry.provenance.changedFields,
          {'mood_rating', 'perceived_stress_rating', 'motivation_energy_rating'});
      expect(await rows(r), 1);

      await setM1(r, false);
      c2.setMood(1);
      expect(await c2.save(), CheckInSaveResult.consentDenied);
      expect(c2.mood, 1, reason: 'answers kept after a denial');
      final kept = (await s.checkIn.loadDay(day.date) as CheckInLoaded).record!;
      expect(kept.entry.moodRating, 5, reason: 'the earlier record remains after revocation');
    });
  });
}
