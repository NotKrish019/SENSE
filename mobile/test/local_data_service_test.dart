import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/data/local/local_data_service.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Milestone C: complete local export and transactional erasure, tested on
/// disposable SQLite files with synthetic data only. Not connected to the
/// app; the database is NOT encrypted and erase is logical, not physical.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sense_service_');
    path = '${dir.path}/$kLocalDatabaseFileName';
  });
  tearDown(() async {
    await factory.deleteDatabase(path);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final fixed = DateTime.utc(2026, 11, 9, 12);
  Future<Database> open() => SenseDatabase.open(factory: factory, path: path, clock: () => fixed);

  const plaintext = 'synthetic legacy journal text, stored in plain form';
  const day = LocalDay('2026-11-08', 330);
  final submitted = DateTime.utc(2026, 11, 8, 8, 30);
  Provenance untouched(Set<String> all) =>
      Provenance.fromChanged(allFields: all, changed: const {}, submittedAtUtc: submitted);

  /// A v1 database exactly as the legacy helper defined it, with rows, then
  /// migrated to v2 (legacy tables preserved as legacy_v1_*).
  Future<Database> openMigratedLegacy() async {
    final v1 = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE check_ins (check_in_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
                'timestamp_utc TEXT NOT NULL, session_type TEXT NOT NULL, perceived_stress INTEGER NOT NULL, '
                'mood_valence INTEGER NOT NULL, mood_arousal INTEGER NOT NULL, motivation_level INTEGER, '
                'completion_latency_sec REAL NOT NULL)');
            await db.execute('CREATE TABLE sleep_records (sleep_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
                'date_epoch TEXT NOT NULL, bedtime_utc TEXT NOT NULL, wake_time_utc TEXT NOT NULL, '
                'total_sleep_minutes INTEGER NOT NULL, sleep_quality_rating INTEGER, source_type TEXT NOT NULL)');
            await db.execute('CREATE TABLE workload_records (workload_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
                'date_epoch TEXT NOT NULL, mental_demand_rating INTEGER NOT NULL, effort_rating INTEGER NOT NULL, '
                'tasks_completed_count INTEGER, impending_deadlines_count INTEGER)');
            await db.execute('CREATE TABLE journal_entries (journal_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
                'timestamp_utc TEXT NOT NULL, raw_text_encrypted TEXT NOT NULL, word_count INTEGER NOT NULL, '
                'sentiment_polarity REAL NOT NULL, sentiment_subjectivity REAL NOT NULL)');
            await db.execute('CREATE TABLE user_baselines (baseline_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
                'date_epoch TEXT NOT NULL, calibration_day_count INTEGER NOT NULL, is_calibrated INTEGER NOT NULL, '
                'sleep_mean_hours REAL, sleep_std_hours REAL, stress_mean_rating REAL, stress_std_rating REAL, '
                'workload_mean_rating REAL, workload_std_rating REAL)');
            await db.execute('CREATE TABLE consent_settings (modality_key TEXT PRIMARY KEY, '
                'is_consented INTEGER NOT NULL, updated_timestamp_utc TEXT NOT NULL)');
            for (final m in ['check_in', 'sleep', 'workload', 'journal', 'voice', 'activity']) {
              await db.insert('consent_settings', {
                'modality_key': m,
                'is_consented': (m == 'voice' || m == 'activity') ? 0 : 1,
                'updated_timestamp_utc': '2026-11-01T00:00:00Z',
              });
            }
          },
        ));
    await v1.insert('check_ins', {
      'check_in_id': 'c1', 'user_id': 'u1', 'timestamp_utc': '2026-11-01T08:00:00Z', 'session_type': 'MORNING',
      'perceived_stress': 4, 'mood_valence': 2, 'mood_arousal': 5, 'motivation_level': 3, 'completion_latency_sec': 12.5,
    });
    await v1.insert('sleep_records', {
      'sleep_id': 's1', 'user_id': 'u1', 'date_epoch': '2026-11-01', 'bedtime_utc': '2026-10-31T23:00:00Z',
      'wake_time_utc': '2026-11-01T07:00:00Z', 'total_sleep_minutes': 480, 'sleep_quality_rating': 4,
      'source_type': 'MANUAL',
    });
    await v1.insert('workload_records', {
      'workload_id': 'w1', 'user_id': 'u1', 'date_epoch': '2026-11-01', 'mental_demand_rating': 4,
      'effort_rating': 3, 'tasks_completed_count': 2, 'impending_deadlines_count': 1,
    });
    await v1.insert('journal_entries', {
      'journal_id': 'j1', 'user_id': 'u1', 'timestamp_utc': '2026-11-01T21:00:00Z', 'raw_text_encrypted': plaintext,
      'word_count': 8, 'sentiment_polarity': 0.0, 'sentiment_subjectivity': 0.0,
    });
    await v1.insert('user_baselines', {
      'baseline_id': 'b1', 'user_id': 'u1', 'date_epoch': '2026-11-01', 'calibration_day_count': 3,
      'is_calibrated': 0, 'sleep_mean_hours': 7.5,
    });
    await v1.close();
    return open();
  }

  const otherPerson = '11111111-1111-4111-8111-111111111111';

  /// Current-schema data for the active person plus a second (inactive)
  /// identity: every daily table, consent history, a baseline, observations.
  Future<String> seedCurrent(Database db) async {
    var t = DateTime.utc(2026, 11, 8, 9);
    final store = LocalDataStore(db, clock: () => t = t.add(const Duration(seconds: 1)));
    final person = (await store.profiles.ensureActive()).localPersonId;
    for (final m in ['M1', 'M3', 'M4', 'M6']) {
      await store.consent.recordChange(person, m, true);
    }
    await store.consent.recordChange(person, 'M2', true);
    await store.consent.recordChange(person, 'M2', false);
    await store.checkIns.upsert(person,
        CheckInEntry(moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: day, provenance: untouched(CheckInEntry.allFields)));
    await store.checkIns.upsert(
        person,
        CheckInEntry(
            moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: const LocalDay('2026-11-07', 330), provenance: untouched(CheckInEntry.allFields)));
    await store.sleep.upsert(
        person,
        SleepEntry(
            durationMinutes: 450, bedtimeLocal: '23:30', wakeTimeLocal: '07:00', restQuality: 4, day: day, provenance: untouched(SleepEntry.allFields)));
    await store.workload.upsert(person,
        WorkloadEntry(mentalDemand: 3, effort: 3, deadlines48h: 1, day: day, provenance: untouched(WorkloadEntry.allFields)));
    await store.activity.upsert(person, ActivityEntry(steps: 6800, activeMinutes: 35, day: day, provenance: untouched(ActivityEntry.allFields)));
    await db.insert('baselines', {
      'id': '22222222-2222-4222-8222-222222222222', 'local_person_id': person, 'variable': 'mood_rating',
      'local_date': '2026-11-08', 'window_days': 14, 'n_points': 7, 'location': 3.0, 'scale': 0.5, 'calibrated': 1,
      'created_at_utc': '2026-11-08T10:00:00.000Z',
    });
    for (final (i, v) in [(1, 'mood_rating'), (2, 'sleep_duration')]) {
      await db.insert('observations', {
        'id': '33333333-3333-4333-8333-33333333333$i', 'local_person_id': person, 'variable': v,
        'local_date': '2026-11-08', 'z_score': 0.25 * i, 'n_points': 7, 'created_at_utc': '2026-11-08T10:00:00.000Z',
      });
    }
    // A second, inactive identity with its own data.
    await db.insert('local_profile', {'local_person_id': otherPerson, 'created_at_utc': '2026-11-01T00:00:00.000Z', 'is_active': 0});
    await store.consent.recordChange(otherPerson, 'M1', true);
    await store.checkIns.upsert(otherPerson,
        CheckInEntry(moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: day, provenance: untouched(CheckInEntry.allFields)));
    return person;
  }

  /// Every table's rows (including SQLite's own) plus the schema version.
  Future<Map<String, Object?>> dumpAll(Database db) async {
    final names = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"))
        .map((r) => r['name'] as String);
    return {
      'user_version': (await db.rawQuery('PRAGMA user_version')).first.values.first,
      for (final n in names) n: await db.rawQuery('SELECT * FROM "$n" ORDER BY rowid'),
    };
  }

  Future<int> count(Database db, String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM "$table"')).first['n'] as int;

  Map<String, Object?> table(Map<String, Object?> export, String section, String name) =>
      (export[section] as Map<String, Object?>)[name] as Map<String, Object?>;
  List<Map<String, Object?>> rows(Map<String, Object?> export, String section, String name) =>
      (table(export, section, name)['rows'] as List).cast<Map<String, Object?>>();

  /// Runs [body] and returns everything it printed.
  Future<List<String>> capturePrints(Future<void> Function() body) async {
    final printed = <String>[];
    await runZoned(body, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => printed.add(line)));
    return printed;
  }

  const legacyNames = [
    'legacy_v1_check_ins',
    'legacy_v1_consent_settings',
    'legacy_v1_journal_entries',
    'legacy_v1_sleep_records',
    'legacy_v1_user_baselines',
    'legacy_v1_workload_records',
  ];
  const userTables = [
    'local_profile', 'check_ins', 'sleep_records', 'workload_records', 'activity_records', 'consent_events',
    'baselines', 'observations',
  ];

  // ---- Export --------------------------------------------------------------------------------
  group('Export', () {
    test('metadata, format version and the local pseudonymous identity', () async {
      final db = await openMigratedLegacy();
      final person = await seedCurrent(db);
      final export = await LocalDataService(db, clock: () => fixed, appVersion: '0.1.0+1').exportAllUserData();
      expect(export['format'], 'sense-local-export');
      expect(export['format_version'], 1);
      expect(export['exported_at_utc'], '2026-11-09T12:00:00.000Z');
      expect(export['schema_version'], kSchemaVersion);
      expect(export['app_version'], '0.1.0+1');
      expect((export['local_profile'] as Map)['local_person_id'], person);
      expect(LocalDataService(db).appVersion, isNull, reason: 'no app version unless supplied');
      expect(rows(export, 'tables', 'local_profile').map((r) => r['local_person_id']), containsAll([person, otherPerson]));
      await db.close();
    });

    test('every current table is included with every row, for every identity', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      final export = await LocalDataService(db).exportAllUserData();
      expect((export['tables'] as Map).keys.toSet(), userTables.toSet());
      for (final t in userTables) {
        expect(table(export, 'tables', t)['row_count'], await count(db, t), reason: t);
        expect(rows(export, 'tables', t), hasLength(await count(db, t)), reason: t);
      }
      expect(rows(export, 'tables', 'check_ins'), hasLength(3), reason: 'two days for one person, one for the other');
      expect(rows(export, 'tables', 'baselines').single['location'], 3.0);
      expect(rows(export, 'tables', 'observations').map((r) => r['variable']), ['mood_rating', 'sleep_duration']);
      // Types, UTC timestamps and local dates are preserved.
      final activity = rows(export, 'tables', 'activity_records').single;
      expect(activity['steps'], 6800);
      expect(activity['steps_is_initial_default'], 1);
      expect(activity['local_date'], '2026-11-08');
      expect(activity['tz_offset_minutes'], 330);
      expect(activity['submitted_at_utc'], '2026-11-08T08:30:00.000Z');
      expect(jsonDecode(activity['default_fields'] as String), ['active_minutes', 'steps']);
      await db.close();
    });

    test('consent history is complete and in event-id order', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      final events = rows(await LocalDataService(db).exportAllUserData(), 'tables', 'consent_events');
      expect(events, hasLength(7));
      final ids = events.map((e) => e['id'] as int).toList();
      expect(ids, [...ids]..sort());
      final m2 = events.where((e) => e['modality'] == 'M2').map((e) => e['enabled']).toList();
      expect(m2, [1, 0], reason: 'earlier events are kept, not only the latest');
      await db.close();
    });

    test('every legacy table is exported as legacy data, unconverted, with the plaintext warning', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      final export = await LocalDataService(db).exportAllUserData();
      expect((export['legacy_v1_tables'] as Map).keys.toList(), legacyNames);
      final journal = table(export, 'legacy_v1_tables', 'legacy_v1_journal_entries');
      expect(journal['columns'], contains('raw_text_encrypted'));
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_journal_entries').single['raw_text_encrypted'], plaintext);
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_check_ins').single,
          containsPair('mood_valence', 2), reason: 'original legacy column names and values');
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_consent_settings'), hasLength(6));
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_sleep_records').single['total_sleep_minutes'], 480);
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_user_baselines').single['calibration_day_count'], 3);
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_workload_records').single['mental_demand_rating'], 4);
      final warnings = (export['warnings'] as List).cast<String>();
      expect(warnings.any((w) => w.contains('raw_text_encrypted') && w.contains('PLAINTEXT') && w.contains('not been verified as ciphertext')),
          isTrue);
      expect(warnings.any((w) => w.contains('not encrypted')), isTrue);
      // Nothing legacy was converted into current tables.
      expect(rows(export, 'tables', 'check_ins').any((r) => r.containsKey('mood_valence')), isFalse);
      expect(rows(export, 'system_metadata', 'migration_log'), isNotEmpty);
      await db.close();
    });

    test('unexpected legacy columns, binary and non-finite values are kept with explicit encodings', () async {
      final db = await openMigratedLegacy();
      await db.execute('CREATE TABLE legacy_v1_extra (unexpected_col TEXT, payload BLOB, measure REAL)');
      await db.insert('legacy_v1_extra', {'unexpected_col': 'a', 'payload': Uint8List.fromList([0, 1, 254, 255]), 'measure': double.infinity});
      await db.insert('legacy_v1_extra', {'unexpected_col': null, 'payload': null, 'measure': 1.5});
      final json = await LocalDataService(db).exportAllUserDataJson();
      final export = jsonDecode(json) as Map<String, Object?>;
      final extra = table(export, 'legacy_v1_tables', 'legacy_v1_extra');
      expect(extra['columns'], ['unexpected_col', 'payload', 'measure']);
      final r = (extra['rows'] as List).cast<Map<String, Object?>>();
      expect(r, hasLength(2));
      expect(r[0]['payload'], {r'$type': 'blob', 'encoding': 'base64', 'data': base64Encode([0, 1, 254, 255])});
      expect(r[0]['measure'], {r'$type': 'double', 'value': 'Infinity'});
      expect(r[1], {'unexpected_col': null, 'payload': null, 'measure': 1.5});
      await db.close();
    });

    test('VIRTUAL and STORED generated columns are exported in declared order with their computed values', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      await db.execute('CREATE TABLE legacy_v1_generated ('
          'id INTEGER, '
          'label TEXT, '
          'doubled INTEGER GENERATED ALWAYS AS (id * 2) VIRTUAL, '
          "tag TEXT GENERATED ALWAYS AS ('t-' || label) STORED, "
          'trailing REAL)');
      await db.insert('legacy_v1_generated', {'id': 21, 'label': 'a', 'trailing': 0.5});
      await db.insert('legacy_v1_generated', {'id': 4, 'label': 'b', 'trailing': null});
      final service = LocalDataService(db, clock: () => fixed);
      final json = await service.exportAllUserDataJson();
      final export = jsonDecode(json) as Map<String, Object?>;
      final generated = table(export, 'legacy_v1_tables', 'legacy_v1_generated');
      expect(generated['columns'], ['id', 'label', 'doubled', 'tag', 'trailing'], reason: 'declared order kept');
      expect(generated['generated_columns'], {'doubled': 'virtual', 'tag': 'stored'});
      expect(generated['row_count'], 2);
      expect(generated['rows'], [
        {'id': 21, 'label': 'a', 'doubled': 42, 'tag': 't-a', 'trailing': 0.5},
        {'id': 4, 'label': 'b', 'doubled': 8, 'tag': 't-b', 'trailing': null},
      ]);
      expect(await service.exportAllUserDataJson(), json, reason: 'deterministic');
      // The rest of the export is unchanged: metadata, warnings, other tables.
      expect(export['format_version'], 1);
      expect(export['schema_version'], kSchemaVersion);
      expect((export['warnings'] as List).any((w) => (w as String).contains('PLAINTEXT')), isTrue);
      expect(rows(export, 'legacy_v1_tables', 'legacy_v1_journal_entries').single['raw_text_encrypted'], plaintext);
      expect(table(export, 'legacy_v1_tables', 'legacy_v1_journal_entries').containsKey('generated_columns'), isFalse,
          reason: 'tables without generated columns keep their previous shape');
      expect((export['legacy_v1_tables'] as Map).keys.toList(), [...legacyNames, 'legacy_v1_generated']..sort());
      await db.close();
    });

    test('a hidden column the export cannot represent is refused, not silently omitted', () async {
      final db = await open();
      // An FTS5 virtual table has hidden columns (table_xinfo hidden = 1).
      await db.execute('CREATE VIRTUAL TABLE legacy_v1_notes USING fts5(body)');
      await db.insert('legacy_v1_notes', {'body': 'synthetic'});
      final hidden = (await db.rawQuery('PRAGMA table_xinfo(legacy_v1_notes)')).map((c) => c['hidden']).toSet();
      expect(hidden, contains(1), reason: 'the fixture really has a hidden column');
      Object? result;
      await expectLater(
          () async => result = await LocalDataService(db).exportAllUserDataJson(),
          throwsA(isA<UnsupportedColumnException>()
              .having((e) => e.table, 'table', 'legacy_v1_notes')
              .having((e) => e.hidden, 'hidden', 1)));
      expect(result, isNull, reason: 'no incomplete export');
      await db.close();
    });

    test('an empty database exports validly; output is deterministic', () async {
      final db = await open();
      final service = LocalDataService(db, clock: () => fixed);
      final json = await service.exportAllUserDataJson();
      final export = jsonDecode(json) as Map<String, Object?>;
      expect(export['local_profile'], isNull);
      for (final t in userTables) {
        expect(table(export, 'tables', t)['row_count'], 0, reason: t);
        expect(table(export, 'tables', t)['columns'], isNotEmpty, reason: t);
      }
      expect(export['legacy_v1_tables'], isEmpty);
      expect((export['warnings'] as List).any((w) => (w as String).contains('PLAINTEXT')), isFalse,
          reason: 'no legacy journal table, no journal warning');
      expect(await service.exportAllUserDataJson(), json, reason: 'same data, same clock, same output');
      await db.close();
    });

    test('export reads one snapshot: atomic writes on the same connection are never split', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      final service = LocalDataService(db);
      // Each write adds one consent event and one check-in, atomically.
      final writes = <Future<void>>[];
      final exports = <Future<Map<String, Object?>>>[];
      for (var i = 0; i < 12; i++) {
        writes.add(LocalDataStore.transaction(db, (s) async {
          await s.consent.recordChange(person, 'M1', true);
          await s.checkIns.upsert(
              person,
              CheckInEntry(
                  moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2,
                  day: LocalDay('2026-10-${(i + 10).toString()}', 330), provenance: untouched(CheckInEntry.allFields)));
        }));
        exports.add(service.exportAllUserData());
      }
      await Future.wait(writes);
      final seen = <int>{};
      for (final r in await Future.wait(exports)) {
        final n = rows(r, 'tables', 'check_ins').length;
        expect(rows(r, 'tables', 'consent_events').length, n, reason: 'never one half of a write');
        seen.add(n);
      }
      expect(seen.length, greaterThan(1), reason: 'exports interleaved with the writes');
      await db.close();
    });

    test('export waits for an open write on another connection and includes all of it', () async {
      final setup = await open();
      final person = (await LocalDataStore(setup).profiles.ensureActive()).localPersonId;
      await setup.close();

      final fromWriter = ReceivePort();
      final messages = StreamIterator<Object?>(fromWriter);
      Future<Object?> next() async =>
          await messages.moveNext().timeout(const Duration(seconds: 20)) ? messages.current : null;
      const holdMs = 800;
      await Isolate.spawn(_holdUncommittedWrite, [fromWriter.sendPort, path, person, holdMs],
          onError: fromWriter.sendPort, errorsAreFatal: true);
      expect(await next(), 'uncommitted');

      final db = await open();
      await db.rawQuery('PRAGMA busy_timeout = 20000');
      final clock = Stopwatch()..start();
      final export = await LocalDataService(db).exportAllUserData();
      clock.stop();
      expect(await next(), 'committed');
      expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(holdMs ~/ 2), reason: 'the export waited for the writer');
      expect(rows(export, 'tables', 'consent_events'), hasLength(1));
      expect(rows(export, 'tables', 'check_ins'), hasLength(1), reason: 'the whole committed write, not a part of it');
      await db.close();
      fromWriter.close();
    });

    test('a failing query fails the export; nothing partial is returned', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      // A virtual generated column added after the row exists overflows only
      // when read: a real runtime query error during the export.
      await db.execute('CREATE TABLE legacy_v1_broken (a INTEGER)');
      await db.insert('legacy_v1_broken', {'a': -9223372036854775808});
      await db.execute('ALTER TABLE legacy_v1_broken ADD COLUMN b INTEGER GENERATED ALWAYS AS (abs(a)) VIRTUAL');
      Object? result;
      await expectLater(() async => result = await LocalDataService(db).exportAllUserDataJson(),
          throwsA(isA<DatabaseException>()));
      expect(result, isNull);
      await db.execute('DROP TABLE legacy_v1_broken');
      // A missing expected table also fails clearly.
      await db.execute('ALTER TABLE observations RENAME TO observations_gone');
      await expectLater(LocalDataService(db).exportAllUserData(), throwsA(anything));
      await db.close();
    });

    test('an unrecognised table makes export refuse rather than skip it', () async {
      final db = await open();
      await db.execute('CREATE TABLE notes_from_somewhere (x TEXT)');
      await expectLater(LocalDataService(db).exportAllUserData(), throwsA(isA<UnrecognizedTableException>()));
      await db.close();
    });

    test('export does not modify the database and prints nothing', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      final before = await dumpAll(db);
      final printed = await capturePrints(() => LocalDataService(db).exportAllUserDataJson());
      expect(await dumpAll(db), before);
      expect(printed, isEmpty);
      await db.close();
    });
  });

  // ---- Erase ---------------------------------------------------------------------------------
  group('Erase', () {
    test('removes every user-data row, legacy rows included, and keeps schema and migration metadata', () async {
      final db = await openMigratedLegacy();
      final person = await seedCurrent(db);
      final tablesBefore = (await dumpAll(db)).keys.toList();
      final migrationLog = await db.query('migration_log', orderBy: 'id');
      final result = await LocalDataService(db).eraseAllUserData();

      for (final t in userTables.where((t) => t != 'local_profile')) {
        expect(await count(db, t), 0, reason: t);
      }
      for (final t in legacyNames) {
        expect(await count(db, t), 0, reason: t);
      }
      expect((await dumpAll(db)).keys.toList(), tablesBefore, reason: 'every table structure is kept');
      expect(await db.query('migration_log', orderBy: 'id'), migrationLog, reason: 'system metadata kept');
      expect(await db.getVersion(), kSchemaVersion);
      expect(jsonEncode(await dumpAll(db)), isNot(contains(plaintext)), reason: 'legacy journal text is gone');
      expect(result.previousLocalPersonIds, containsAll([person, otherPerson]));
      expect(result.deletedRows['legacy_v1_journal_entries'], 1);
      expect(result.deletedRows['legacy_v1_consent_settings'], 6);
      expect(result.deletedRows['consent_events'], 7);
      await db.close();
    });

    test('rotates to a new random identity with every preference OFF and no consent events', () async {
      final db = await openMigratedLegacy();
      final person = await seedCurrent(db);
      final result = await LocalDataService(db).eraseAllUserData();
      final profiles = await db.query('local_profile');
      expect(profiles, hasLength(1));
      expect(profiles.single['local_person_id'], result.newLocalPersonId);
      expect(profiles.single['is_active'], 1);
      expect(result.newLocalPersonId, isNot(person));
      expect(result.newLocalPersonId, isNot(otherPerson));
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(result.newLocalPersonId),
          isTrue);
      final store = LocalDataStore(db);
      expect((await store.profiles.active())!.localPersonId, result.newLocalPersonId);
      expect(await store.consent.currentPreferences(result.newLocalPersonId),
          {'M1': false, 'M2': false, 'M3': false, 'M4': false, 'M5': false, 'M6': false});
      expect(await count(db, 'consent_events'), 0);
      // The old identity cannot write any more, and the new one starts gated.
      await expectLater(
          store.checkIns.upsert(person,
              CheckInEntry(moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: day, provenance: untouched(CheckInEntry.allFields))),
          throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.noProfile)));
      await expectLater(
          store.checkIns.upsert(result.newLocalPersonId,
              CheckInEntry(moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: day, provenance: untouched(CheckInEntry.allFields))),
          throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.notRecorded)));
      await db.close();
    });

    test('an empty database erases safely, and repeated erases each start a new identity', () async {
      final db = await open();
      final service = LocalDataService(db);
      final first = await service.eraseAllUserData();
      expect(first.previousLocalPersonIds, isEmpty);
      final second = await service.eraseAllUserData();
      final third = await service.eraseAllUserData();
      expect(second.previousLocalPersonIds, [first.newLocalPersonId]);
      expect(third.previousLocalPersonIds, [second.newLocalPersonId]);
      expect({first.newLocalPersonId, second.newLocalPersonId, third.newLocalPersonId}, hasLength(3));
      expect(await count(db, 'local_profile'), 1);
      expect(await count(db, 'consent_events'), 0);
      await db.close();
    });

    test('several local identities leave no residual data', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      const third = '44444444-4444-4444-8444-444444444444';
      await db.insert('local_profile', {'local_person_id': third, 'created_at_utc': '2026-11-02T00:00:00.000Z', 'is_active': 0});
      await LocalDataStore(db).consent.recordChange(third, 'M4', true);
      final result = await LocalDataService(db).eraseAllUserData();
      expect(result.previousLocalPersonIds, hasLength(3));
      final dump = jsonEncode(await dumpAll(db));
      for (final old in result.previousLocalPersonIds) {
        expect(dump, isNot(contains(old)), reason: 'no trace of $old in any table');
      }
      await db.close();
    });

    for (final (label, trigger) in [
      ('a legacy table', 'CREATE TRIGGER fail_mid BEFORE DELETE ON legacy_v1_journal_entries BEGIN SELECT RAISE(ABORT, \'injected\'); END'),
      ('a current table', 'CREATE TRIGGER fail_mid BEFORE DELETE ON check_ins BEGIN SELECT RAISE(ABORT, \'injected\'); END'),
      ('the new identity, after every delete', 'CREATE TRIGGER fail_mid BEFORE INSERT ON local_profile BEGIN SELECT RAISE(ABORT, \'injected\'); END'),
    ]) {
      test('an injected failure at $label rolls back everything and is reported as an error', () async {
        final db = await openMigratedLegacy();
        await seedCurrent(db);
        await db.execute(trigger); // test-only failure injection in the disposable database
        final before = await dumpAll(db);
        EraseResult? result;
        await expectLater(() async => result = await LocalDataService(db).eraseAllUserData(),
            throwsA(isA<DatabaseException>()));
        expect(result, isNull, reason: 'no partial success');
        expect(await dumpAll(db), before, reason: 'identity, records, consent history and legacy rows all intact');
        expect(jsonEncode(await dumpAll(db)), contains(plaintext));
        await db.close();
      });
    }

    test('erase refuses to reuse a previous identity and rolls back', () async {
      final db = await openMigratedLegacy();
      final person = await seedCurrent(db);
      final before = await dumpAll(db);
      // A generator that would hand back the old identity must not succeed.
      await expectLater(LocalDataService(db, ids: () => person).eraseAllUserData(), throwsA(isA<StateError>()));
      expect(await dumpAll(db), before);
      await db.close();
    });

    test('an unrecognised table makes erase refuse and change nothing', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      await db.execute('CREATE TABLE notes_from_somewhere (x TEXT)');
      await db.insert('notes_from_somewhere', {'x': 'kept'});
      final before = await dumpAll(db);
      await expectLater(LocalDataService(db).eraseAllUserData(), throwsA(isA<UnrecognizedTableException>()));
      expect(await dumpAll(db), before);
      await db.close();
    });

    test('erase prints nothing', () async {
      final db = await openMigratedLegacy();
      await seedCurrent(db);
      expect(await capturePrints(() => LocalDataService(db).eraseAllUserData()), isEmpty);
      await db.close();
    });
  });

  // ---- Boundaries ----------------------------------------------------------------------------
  group('Boundaries', () {
    String read(String p) => File(p).readAsStringSync();

    test('no production code uses the export/erase service or opens the database', () {
      final appFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('lib/data/'));
      for (final f in appFiles) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('LocalDataService')), reason: f.path);
        expect(src, isNot(contains('data/local/')), reason: f.path);
      }
    });

    test('Settings still shows Export and Erase as unavailable', () {
      final settings = read('lib/presentation/screens/settings_screen.dart');
      expect(settings, contains('PrototypeCopy.exportUnavailable'));
      expect(settings, contains('PrototypeCopy.eraseUnavailable'));
      expect(PrototypeCopy.exportUnavailable, startsWith('Export is not available yet.'));
      expect(PrototypeCopy.eraseUnavailable, startsWith('Erase is not available yet.'));
    });

    test('no network, file output, logging, journal write or encryption claim in the service', () {
      final src = read('lib/data/local/local_data_service.dart');
      for (final banned in ['dart:io', 'package:http', 'HttpClient', 'Socket', 'File(', 'print(', 'debugPrint', 'log(']) {
        expect(src, isNot(contains(banned)), reason: banned);
      }
      expect(RegExp(r"insert\(\s*'(journal|legacy)").hasMatch(src), isFalse);
      for (final claim in [
        'export is encrypted',
        'database is encrypted',
        'data is encrypted',
        'securely erased',
        'securely deleted',
        'cryptographically erased',
        'unrecoverable',
      ]) {
        expect(src.toLowerCase(), isNot(contains(claim)), reason: claim);
      }
      expect(src, contains('NOT ENCRYPTED'));
      expect(src, contains('That is logical database erasure'));
      expect(src, contains('cryptographic erasure.'));
      final pubspec = read('pubspec.yaml');
      for (final pkg in ['http:', 'dio:', 'share_plus:', 'path_provider:', 'sqlcipher']) {
        expect(pubspec, isNot(contains(pkg)), reason: pkg);
      }
    });
  });
}

/// A writer on its own connection in its own isolate: turns M1 on and writes
/// a check-in in one transaction, reports 'uncommitted', holds the write lock
/// for the given time, then commits and reports 'committed'.
Future<void> _holdUncommittedWrite(List<Object> args) async {
  final send = args[0] as SendPort;
  final path = args[1] as String;
  final person = args[2] as String;
  final holdMs = args[3] as int;
  sqfliteFfiInit();
  final db = await createDatabaseFactoryFfi(noIsolate: true)
      .openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));
  await db.rawQuery('PRAGMA busy_timeout = 20000');
  await db.execute('PRAGMA foreign_keys = ON');
  await LocalDataStore.transaction(db, (store) async {
    await store.consent.recordChange(person, 'M1', true);
    await store.checkIns.upsert(
        person,
        CheckInEntry(
          moodRating: 3,
          motivationEnergyRating: 3,
          perceivedStressRating: 2,
          day: const LocalDay('2026-11-08', 330),
          provenance: Provenance.fromChanged(
              allFields: CheckInEntry.allFields, changed: const {}, submittedAtUtc: DateTime.utc(2026, 11, 8, 8, 30)),
        ));
    send.send('uncommitted');
    await Future<void>.delayed(Duration(milliseconds: holdMs));
  });
  send.send('committed');
  await db.close();
}
