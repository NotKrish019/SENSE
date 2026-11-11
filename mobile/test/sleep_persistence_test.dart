// Milestone K4: sleep persistence through the real storage owner, the narrow
// SleepAccess, the existing SleepRepository and its in-transaction M3 consent
// check. Storage is the test-only FakeSecureKeyPlatform (disposable plain
// SQLite through sqflite_common_ffi). On-device encrypted behaviour is covered
// by integration_test/sleep_persistence_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/state/sleep_controller.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_secure_key_platform.dart';

const _debugDev = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true);
const _debugDefault = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: false);

void main() {
  late Directory dir;
  final owners = <SenseStorage>[];

  setUpAll(sqfliteFfiInit);
  setUp(() => dir = Directory.systemTemp.createTempSync('sense_k4_'));
  tearDown(() async {
    for (final s in owners) {
      await s.close();
    }
    owners.clear();
    ConsentPreferences.instance.reset();
    dir.deleteSync(recursive: true);
  });

  var tick = DateTime.utc(2026, 11, 11, 1);
  DateTime clock() => tick = tick.add(const Duration(seconds: 1));

  Future<(SenseStorage, StorageReady)> openDev() async {
    final s = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir), clock: clock);
    owners.add(s);
    final r = await s.start();
    expect(r, isA<StorageReady>(), reason: '$r');
    return (s, r as StorageReady);
  }

  // Woke on 11 November.
  final day = LocalDay.fromLocal(DateTime(2026, 11, 11, 7, 20));

  SleepEntry entry(
          {int minutes = 450,
          String bedtime = '23:30',
          String wake = '07:00',
          int quality = 4,
          Set<String> changed = const {},
          LocalDay? on}) =>
      SleepEntry(
        durationMinutes: minutes,
        bedtimeLocal: bedtime,
        wakeTimeLocal: wake,
        restQuality: quality,
        day: on ?? day,
        provenance: Provenance.fromChanged(
            allFields: SleepEntry.allFields, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11, 1, 30)),
      );

  Future<void> setM3(StorageReady r, bool on) => r.store.consent.recordChange(r.profile.localPersonId, 'M3', on);
  Future<int> rows(StorageReady r) async =>
      (await r.database.rawQuery('SELECT COUNT(*) AS n FROM sleep_records')).first['n'] as int;

  group('Repository through SleepAccess', () {
    test('M3 never turned on: denied in the transaction; nothing written', () async {
      final (s, r) = await openDev();
      expect((await s.sleep.save(entry()) as SleepConsentDenied).reason, ConsentDenialReason.notRecorded);
      expect(await rows(r), 0);
    });

    test('M3 on: stored under the wake-up date with HH:MM times and minutes; byDate returns it', () async {
      final (s, r) = await openDev();
      await setM3(r, true);
      final saved = await s.sleep.save(entry(minutes: 390, bedtime: '00:05', wake: '06:35', quality: 2,
          changed: {'duration_minutes', 'bedtime_local', 'wake_time_local', 'rest_quality'})) as SleepSaved;
      expect(saved.updated, isFalse);
      final row = (await r.database.query('sleep_records')).single;
      expect(row['local_date'], '2026-11-11', reason: 'the date of wake-up');
      expect(row['tz_offset_minutes'], day.tzOffsetMinutes);
      expect(row['duration_minutes'], 390);
      expect(row['bedtime_local'], '00:05');
      expect(row['wake_time_local'], '06:35');
      expect(row['rest_quality'], 2);
      expect(row['source'], 'MANUAL_LOG');
      expect(row['changed_fields'], '["bedtime_local","duration_minutes","rest_quality","wake_time_local"]');
      expect(row['default_fields'], '[]');
      expect(row['schema_version'], kSchemaVersion);
      final loaded = (await s.sleep.loadDay('2026-11-11') as SleepLoaded).record!;
      expect(loaded.id, saved.record.id);
      expect(loaded.entry.provenance, saved.record.entry.provenance);
      expect((await s.sleep.loadDay('2026-11-10') as SleepLoaded).record, isNull,
          reason: 'not stored under the bedtime date');
    });

    test('the schema itself refuses off-grid minutes and non-HH:MM times (unchanged constraints)', () async {
      final (_, r) = await openDev();
      Future<void> insert(Map<String, Object> over) => r.database.insert('sleep_records', {
            'id': '00000000-0000-4000-8000-000000000001',
            'local_person_id': r.profile.localPersonId,
            'local_date': '2026-11-11',
            'tz_offset_minutes': 0,
            'created_at_utc': 'x',
            'updated_at_utc': 'x',
            'submitted_at_utc': 'x',
            'schema_version': 2,
            'explicitly_submitted': 1,
            'changed_fields': '[]',
            'default_fields': '[]',
            'duration_minutes': 450,
            'bedtime_local': '23:30',
            'wake_time_local': '07:00',
            'rest_quality': 4,
            'source': 'MANUAL_LOG',
            ...over,
          });
      for (final bad in [
        {'duration_minutes': 235},
        {'duration_minutes': 750},
        {'duration_minutes': 455},
        {'bedtime_local': '7:00'},
        {'wake_time_local': '11:30 PM'},
      ]) {
        await expectLater(insert(bad), throwsA(isA<DatabaseException>()), reason: '$bad');
      }
      expect(await rows(r), 0);
    });

    test('a second save the same wake-up day updates the same record (one row; id and created_at kept)', () async {
      final (s, r) = await openDev();
      await setM3(r, true);
      final first = await s.sleep.save(entry(quality: 3, changed: {'rest_quality'})) as SleepSaved;
      final second =
          await s.sleep.save(entry(minutes: 480, quality: 3, changed: {'rest_quality', 'duration_minutes'})) as SleepSaved;
      expect(second.updated, isTrue);
      expect(second.record.id, first.record.id);
      expect(second.record.createdAtUtc, first.record.createdAtUtc);
      expect(second.record.updatedAtUtc.isAfter(first.record.updatedAtUtc), isTrue);
      expect(await rows(r), 1);
      final stored = (await s.sleep.loadDay(day.date) as SleepLoaded).record!;
      expect(stored.entry.durationMinutes, 480);
      expect(stored.entry.provenance.changedFields, {'rest_quality', 'duration_minutes'});
    });

    test('revocation blocks later writes; earlier records remain; history reads them', () async {
      final (s, r) = await openDev();
      await setM3(r, true);
      await s.sleep.save(entry(on: LocalDay('2026-11-09', day.tzOffsetMinutes), minutes: 420, changed: {'duration_minutes'}));
      final kept = await s.sleep.save(entry(quality: 5, changed: {'rest_quality'})) as SleepSaved;
      await setM3(r, false);
      expect((await s.sleep.save(entry(quality: 1, changed: {'rest_quality'})) as SleepConsentDenied).reason,
          ConsentDenialReason.disabled);
      final still = (await s.sleep.loadDay(day.date) as SleepLoaded).record!;
      expect(still.entry.restQuality, 5);
      expect(still.updatedAtUtc, kept.record.updatedAtUtc);
      final history = await s.sleep.loadRange(fromDate: '2026-11-05', toDate: '2026-11-11') as SleepRangeLoaded;
      expect(history.records.map((e) => e.entry.day.date), ['2026-11-09', '2026-11-11'],
          reason: 'reading history needs no consent and shows only stored records, oldest first');
    });

    test('M1 or M4 never authorize a sleep record', () async {
      final (s, r) = await openDev();
      await r.store.consent.recordChange(r.profile.localPersonId, 'M1', true);
      await r.store.consent.recordChange(r.profile.localPersonId, 'M4', true);
      expect(await s.sleep.save(entry()), isA<SleepConsentDenied>());
      expect(await rows(r), 0);
    });

    test('an in-memory preference never authorizes a write', () async {
      final (s, r) = await openDev();
      final prefs = ConsentPreferences();
      await prefs.setEnabled(InputModality.sleep, true);
      expect(await s.sleep.save(entry()), isA<SleepConsentDenied>());
      expect(await rows(r), 0);
    });

    test('invalid entries are refused before any write', () async {
      final (s, r) = await openDev();
      await setM3(r, true);
      expect(await s.sleep.save(entry(minutes: 750, changed: {'duration_minutes'})), isA<SleepSaveInvalid>());
      expect(await s.sleep.save(entry(minutes: 455, changed: {'duration_minutes'})), isA<SleepSaveInvalid>());
      expect(await s.sleep.save(entry(bedtime: '7:00', changed: {'bedtime_local'})), isA<SleepSaveInvalid>());
      expect(await s.sleep.save(entry(quality: 2)), isA<SleepSaveInvalid>(), reason: 'non-default marked default');
      expect(await rows(r), 0);
    });

    test('default debug build: not connected; nothing opened; no history', () async {
      final platform = FakeSecureKeyPlatform(dir);
      final s = SenseStorage(policy: _debugDefault, platform: platform);
      owners.add(s);
      await s.start();
      expect(s.sleep.status, SleepStorageStatus.notConnected);
      expect(await s.sleep.save(entry()), isA<SleepSaveUnavailable>());
      expect(await s.sleep.loadRange(fromDate: '2026-11-05', toDate: '2026-11-11'), isA<SleepRangeUnavailable>());
      expect(platform.calls, isNot(contains('openKey')));
    });
  });

  group('Controller end to end (host)', () {
    test('save, close, reopen: reloaded by wake-up date and updated in place', () async {
      final now = DateTime(2026, 11, 11, 7, 20);
      var (s, r) = await openDev();
      await setM3(r, true);
      final c1 = SleepController(access: s.sleep, now: () => now);
      await c1.start();
      c1.setBedtime(23, 45);
      c1.setWakeTime(6, 50);
      c1.setDurationHours(6.5);
      expect(await c1.save(), SleepSaveResult.saved);
      final first = c1.existingEntry!;
      c1.dispose();
      await s.close();

      (s, r) = await openDev();
      final c2 = SleepController(access: s.sleep, now: () => now);
      addTearDown(c2.dispose);
      await c2.start();
      await pumpEventQueue();
      expect([c2.durationMinutes, c2.bedtime, c2.wakeTime, c2.quality], [390, '23:45', '06:50', 4]);
      expect(c2.existingEntry!.id, first.id);
      expect(c2.history!.single.id, first.id);
      c2.setQuality(5);
      expect(await c2.save(), SleepSaveResult.updated);
      expect(c2.existingEntry!.createdAtUtc, first.createdAtUtc);
      expect(c2.existingEntry!.entry.provenance.changedFields,
          {'bedtime_local', 'wake_time_local', 'duration_minutes', 'rest_quality'});
      expect(await rows(r), 1);
      await setM3(r, false);
      c2.setQuality(1);
      expect(await c2.save(), SleepSaveResult.consentDenied);
      expect((await s.sleep.loadDay('2026-11-11') as SleepLoaded).record!.entry.restQuality, 5);
    });
  });
}
