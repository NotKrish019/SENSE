import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:mindpulse/data/local/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/dart_source_guard.dart';

/// Milestone A: the local data foundation (schema v2, migrations, typed
/// records, repositories). Disposable SQLite files only; nothing here is
/// connected to the app, and the database is NOT encrypted.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sense_local_');
    path = '${dir.path}/$kLocalDatabaseFileName';
  });
  tearDown(() async {
    await factory.deleteDatabase(path);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  // A deterministic clock: each call advances one second from a fixed instant.
  UtcClock steppingClock([DateTime? start]) {
    var t = start ?? DateTime.utc(2026, 11, 8, 9);
    return () {
      final now = t;
      t = t.add(const Duration(seconds: 1));
      return now;
    };
  }

  Future<Database> open([UtcClock? clock]) => SenseDatabase.open(factory: factory, path: path, clock: clock);

  // Milestone B: daily writes need the matching preference ON. Recorded
  // through a separate store so the tests' stepping clocks are not consumed.
  Future<void> allowAll(Database db, String person) async {
    final consent = LocalDataStore(db).consent;
    for (final m in kModalityCodes) {
      await consent.recordChange(person, m, true);
    }
  }

  Future<List<String>> tables(Database db) async => (await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"))
      .map((r) => r['name'] as String)
      .toList();

  const day = LocalDay('2026-11-08', 330);
  final submitted = DateTime.utc(2026, 11, 8, 8, 30);
  Provenance prov(Set<String> all, Set<String> changed) =>
      Provenance.fromChanged(allFields: all, changed: changed, submittedAtUtc: submitted);

  CheckInEntry checkIn({int mood = 3, int energy = 3, int stress = 2, Set<String> changed = const {}, LocalDay d = day}) =>
      CheckInEntry(
        moodRating: mood,
        motivationEnergyRating: energy,
        perceivedStressRating: stress,
        day: d,
        provenance: prov(CheckInEntry.allFields, changed),
      );

  // ---- Creation -------------------------------------------------------------------------
  group('Schema v2 creation', () {
    test('creates every v2 table, version 2, foreign keys on, no journal table', () async {
      final db = await open(steppingClock());
      expect(await db.getVersion(), 2);
      expect(await tables(db), [
        'activity_records',
        'baselines',
        'check_ins',
        'consent_events',
        'local_profile',
        'migration_log',
        'observations',
        'sleep_records',
        'workload_records',
      ]);
      expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);
      expect((await tables(db)).where((t) => t.contains('journal')), isEmpty,
          reason: 'no journal persistence (ADR-009 Decision F)');
      final log = await db.query('migration_log');
      expect(log.single['from_version'], 0);
      expect(log.single['to_version'], 2);
      await db.close();
    });

    test('observations and baselines have no composite score or alert column', () async {
      final db = await open();
      for (final t in ['observations', 'baselines']) {
        final cols = (await db.rawQuery('PRAGMA table_info($t)')).map((c) => c['name'] as String);
        expect(cols.where((c) => c.contains('alert') || c.contains('composite')), isEmpty, reason: t);
      }
      await db.close();
    });

    test('consent defaults are OFF: no events seeded, all six modalities read as off', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = await store.profiles.ensureActive();
      expect(await db.query('consent_events'), isEmpty);
      expect(await store.consent.currentPreferences(person.localPersonId),
          {'M1': false, 'M2': false, 'M3': false, 'M4': false, 'M5': false, 'M6': false});
      // The reader follows the latest event per modality.
      await db.insert('consent_events',
          {'local_person_id': person.localPersonId, 'modality': 'M3', 'enabled': 1, 'changed_at_utc': '2026-11-08T09:00:00.000Z'});
      await db.insert('consent_events',
          {'local_person_id': person.localPersonId, 'modality': 'M3', 'enabled': 0, 'changed_at_utc': '2026-11-08T09:00:01.000Z'});
      expect((await store.consent.currentPreferences(person.localPersonId))['M3'], isFalse);
      await db.close();
    });
  });

  // ---- Legacy migration ---------------------------------------------------------------------
  group('Migration from the legacy v1 schema', () {
    // The exact v1 definition from lib/data/database/database_helper.dart.
    Future<void> createLegacyV1() async {
      final db = await factory.openDatabase(path,
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
      await db.insert('check_ins', {
        'check_in_id': 'c1', 'user_id': 'u1', 'timestamp_utc': '2026-11-01T08:00:00Z', 'session_type': 'MORNING',
        'perceived_stress': 4, 'mood_valence': 2, 'mood_arousal': 5, 'motivation_level': 3,
        'completion_latency_sec': 12.5,
      });
      await db.insert('journal_entries', {
        'journal_id': 'j1', 'user_id': 'u1', 'timestamp_utc': '2026-11-01T21:00:00Z',
        'raw_text_encrypted': 'this is plaintext, not ciphertext', 'word_count': 5,
        'sentiment_polarity': 0.0, 'sentiment_subjectivity': 0.0,
      });
      await db.insert('workload_records', {
        'workload_id': 'w1', 'user_id': 'u1', 'date_epoch': '2026-11-01', 'mental_demand_rating': 4,
        'effort_rating': 3, 'tasks_completed_count': 2, 'impending_deadlines_count': 1,
      });
      await db.close();
    }

    test('preserves every legacy table and row unchanged under legacy_v1_*, creates v2 beside it', () async {
      await createLegacyV1();
      final db = await open(steppingClock());
      expect(await db.getVersion(), 2);
      final names = await tables(db);
      for (final t in kLegacyV1Tables.keys) {
        expect(names, contains('legacy_v1_$t'));
      }
      expect((await db.query('legacy_v1_check_ins')).single,
          containsPair('mood_valence', 2)); // preserved, not reinterpreted as a mood rating
      expect((await db.query('legacy_v1_journal_entries')).single['raw_text_encrypted'],
          'this is plaintext, not ciphertext');
      expect((await db.query('legacy_v1_workload_records')).single['mental_demand_rating'], 4);
      expect(await db.query('legacy_v1_consent_settings'), hasLength(6));
      // Nothing was converted into the v2 tables.
      for (final t in ['check_ins', 'workload_records', 'sleep_records', 'activity_records', 'consent_events']) {
        expect(await db.query(t), isEmpty, reason: t);
      }
      // The legacy pre-ticked consent is never read: preferences start OFF.
      final store = LocalDataStore(db);
      final person = await store.profiles.ensureActive();
      expect((await store.consent.currentPreferences(person.localPersonId)).values, everyElement(isFalse));
      final notes = (await db.query('migration_log', orderBy: 'id')).last['notes'] as String;
      expect(notes, contains('check_ins -> legacy_v1_check_ins (1 rows)'));
      expect(notes, contains('may contain plaintext and is not ciphertext'));
      await db.close();
    });

    test('is idempotent: a re-run renames nothing more and loses nothing; reopening does not migrate again',
        () async {
      await createLegacyV1();
      var db = await open(steppingClock());
      final before = await tables(db);
      await db.transaction((txn) => SenseSchema.migrateV1ToV2(txn, DateTime.utc(2026, 11, 9)));
      expect(await tables(db), before);
      expect(await db.query('legacy_v1_check_ins'), hasLength(1));
      final logCount = (await db.query('migration_log')).length;
      await db.close();
      db = await open(steppingClock());
      expect((await db.query('migration_log')).length, logCount, reason: 'already at v2');
      await db.close();
    });

    test('a migrated v1 database gets the strict v2 sleep-time constraint', () async {
      await createLegacyV1();
      final db = await open(steppingClock());
      final person = (await LocalDataStore(db).profiles.ensureActive()).localPersonId;
      Future<void> insertSleep(String id, String date, String bed) => db.rawInsert(
            'INSERT INTO sleep_records (id, local_person_id, local_date, tz_offset_minutes, created_at_utc, '
            'updated_at_utc, submitted_at_utc, schema_version, explicitly_submitted, changed_fields, default_fields, '
            'duration_minutes, bedtime_local, wake_time_local, rest_quality, source) '
            "VALUES (?, ?, ?, 330, 'x', 'x', 'x', 2, 1, '[]', '[]', 450, ?, '07:00', 4, 'MANUAL_LOG')",
            [id, person, date, bed],
          );
      await insertSleep('00000000-0000-4000-8000-000000000001', '2026-11-08', '23:59');
      for (final bad in ['24:00', '29:30', '12:60']) {
        await expectLater(insertSleep('00000000-0000-4000-8000-000000000002', '2026-11-09', bad),
            throwsA(isA<DatabaseException>()), reason: bad);
      }
      expect((await db.query('legacy_v1_check_ins')).single['mood_valence'], 2, reason: 'v1 data still preserved');
      await db.close();
    });

    test('a failed upgrade rolls back completely and leaves the v1 database intact', () async {
      await createLegacyV1();
      // A conflicting table makes the migration fail part-way.
      final legacy = await factory.openDatabase(path, options: OpenDatabaseOptions(version: 1));
      await legacy.execute('CREATE TABLE legacy_v1_check_ins (x INTEGER)');
      await legacy.close();
      await expectLater(open(), throwsA(anything));
      final db = await factory.openDatabase(path, options: OpenDatabaseOptions(version: 1));
      expect(await db.getVersion(), 1);
      final names = await tables(db);
      expect(names, containsAll(['check_ins', 'journal_entries', 'consent_settings']));
      expect(names, isNot(contains('local_profile')), reason: 'no partial v2 schema');
      expect((await db.query('check_ins')).single['mood_valence'], 2);
      await db.close();
    });
  });

  // ---- Identity -------------------------------------------------------------------------------
  group('Local pseudonymous profile', () {
    test('one active random UUID identity; ensureActive is stable', () async {
      final db = await open(steppingClock());
      final store = LocalDataStore(db, clock: steppingClock());
      expect(await store.profiles.active(), isNull);
      final a = await store.profiles.ensureActive();
      final b = await store.profiles.ensureActive();
      expect(a.localPersonId, b.localPersonId);
      expect(a.localPersonId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a.createdAtUtc, DateTime.utc(2026, 11, 8, 9));
      expect((await db.query('local_profile')).single.keys,
          unorderedEquals(['local_person_id', 'created_at_utc', 'is_active']),
          reason: 'no name, email or account fields');
      await expectLater(
          db.insert('local_profile',
              {'local_person_id': '00000000-0000-4000-8000-000000000000', 'created_at_utc': 'x', 'is_active': 1}),
          throwsA(isA<DatabaseException>()),
          reason: 'only one active identity');
      await db.close();
    });
  });

  // ---- Round trips -------------------------------------------------------------------------------
  group('Round trips', () {
    late Database db;
    late LocalDataStore store;
    late String person;
    setUp(() async {
      db = await open(steppingClock());
      store = LocalDataStore(db, clock: steppingClock(DateTime.utc(2026, 11, 8, 10)));
      person = (await store.profiles.ensureActive()).localPersonId;
      await allowAll(db, person);
    });
    tearDown(() => db.close());

    test('M1 check-in: three distinct 1 to 5 ratings with provenance', () async {
      final saved = await store.checkIns.upsert(person, checkIn(mood: 4, changed: {'mood_rating'}));
      final got = (await store.checkIns.byDate(person, '2026-11-08'))!;
      expect(got.id, saved.id);
      expect([got.entry.moodRating, got.entry.motivationEnergyRating, got.entry.perceivedStressRating], [4, 3, 2]);
      expect(got.entry.provenance.changedFields, {'mood_rating'});
      expect(got.entry.provenance.defaultFields, {'motivation_energy_rating', 'perceived_stress_rating'});
      expect(got.entry.provenance.submittedAtUtc, submitted);
      expect(got.entry.provenance.explicitlySubmitted, isTrue);
      expect(got.entry.day, day);
      expect(got.schemaVersion, 2);
      final cols = (await db.rawQuery('PRAGMA table_info(check_ins)')).map((c) => c['name']).toList();
      expect(cols.where((c) => '$c'.contains('valence') || '$c'.contains('arousal')), isEmpty);
    });

    test('M3 sleep: duration stored as given, never derived from the two times', () async {
      final entry = SleepEntry(
        durationMinutes: 600, // 23:30 to 07:00 would be 450; the answer is kept as entered
        bedtimeLocal: '23:30',
        wakeTimeLocal: '07:00',
        restQuality: 2,
        day: day,
        provenance: prov(SleepEntry.allFields, {'duration_minutes', 'rest_quality'}),
      );
      await store.sleep.upsert(person, entry);
      final got = (await store.sleep.byDate(person, '2026-11-08'))!.entry;
      expect([got.durationMinutes, got.bedtimeLocal, got.wakeTimeLocal, got.restQuality], [600, '23:30', '07:00', 2]);
      expect(got.source, SleepSource.manualLog);
      expect(got.provenance.defaultFields, {'bedtime_local', 'wake_time_local'});
    });

    test('M4 workload: deadlines up to 20', () async {
      await store.workload.upsert(
          person,
          WorkloadEntry(
              mentalDemand: 5,
              effort: 1,
              deadlines48h: 20,
              day: day,
              provenance: prov(WorkloadEntry.allFields, WorkloadEntry.allFields)));
      final got = (await store.workload.byDate(person, '2026-11-08'))!.entry;
      expect([got.mentalDemand, got.effort, got.deadlines48h], [5, 1, 20]);
    });

    test('M6 activity: untouched 6,800 kept exactly and flagged; adjusted values on the 500 grid', () async {
      final untouched = ActivityEntry(
          steps: 6800, activeMinutes: 35, day: day, provenance: prov(ActivityEntry.allFields, {}));
      expect(untouched.stepsIsInitialDefault, isTrue);
      await store.activity.upsert(person, untouched);
      var got = (await store.activity.byDate(person, '2026-11-08'))!.entry;
      expect(got.steps, 6800, reason: 'never rounded to 7,000');
      expect(got.stepsIsInitialDefault, isTrue);
      expect((await db.query('activity_records')).single['steps_is_initial_default'], 1);

      await store.activity.upsert(
          person,
          ActivityEntry(
              steps: 7000, activeMinutes: 40, day: day, provenance: prov(ActivityEntry.allFields, {'steps', 'active_minutes'})));
      got = (await store.activity.byDate(person, '2026-11-08'))!.entry;
      expect([got.steps, got.activeMinutes, got.stepsIsInitialDefault], [7000, 40, false]);
      expect(got.source, ActivitySource.manualLog);
    });

    test('range returns a person\'s records oldest first', () async {
      for (final d in ['2026-11-10', '2026-11-08', '2026-11-09']) {
        await store.checkIns.upsert(person, checkIn(d: LocalDay(d, 330)));
      }
      final list = await store.checkIns.range(person, fromDate: '2026-11-08', toDate: '2026-11-09');
      expect(list.map((r) => r.entry.day.date), ['2026-11-08', '2026-11-09']);
      expect(await store.checkIns.deleteByDate(person, '2026-11-09'), isTrue);
      expect(await store.checkIns.byDate(person, '2026-11-09'), isNull);
      expect(await store.checkIns.deleteByDate(person, '2026-11-09'), isFalse);
    });
  });

  // ---- Daily policy and timestamps --------------------------------------------------------------
  test('one record per person per date: a resubmission updates it, keeping id and creation time', () async {
    final db = await open(steppingClock());
    final store = LocalDataStore(db, clock: steppingClock(DateTime.utc(2026, 11, 8, 10)));
    final person = (await store.profiles.ensureActive()).localPersonId;
    await allowAll(db, person);
    final first = await store.checkIns.upsert(person, checkIn());
    final second = await store.checkIns.upsert(person, checkIn(stress: 5, changed: {'perceived_stress_rating'}));
    expect(second.id, first.id);
    expect(second.createdAtUtc, first.createdAtUtc);
    expect(second.updatedAtUtc.isAfter(first.updatedAtUtc), isTrue);
    final rows = await db.query('check_ins');
    expect(rows, hasLength(1));
    expect(rows.single['perceived_stress_rating'], 5);
    // 10:00:00 created the profile; the first save was 10:00:01, the second 10:00:02.
    expect(rows.single['created_at_utc'], '2026-11-08T10:00:01.000Z');
    expect(rows.single['updated_at_utc'], '2026-11-08T10:00:02.000Z');
    expect(rows.single['changed_fields'], '["perceived_stress_rating"]');
    // The database itself refuses a second row for the same date.
    final dup = Map<String, Object?>.from(rows.single)..['id'] = '00000000-0000-4000-8000-000000000001';
    await expectLater(db.insert('check_ins', dup), throwsA(isA<DatabaseException>()));
    await db.close();
  });

  // ---- Validation -------------------------------------------------------------------------------
  group('Validation (Dart) and constraints (SQLite)', () {
    test('out-of-range and off-grid values are rejected before writing', () {
      void bad(DailyEntry e, String field) =>
          expect(e.validate, throwsA(isA<DataValidationException>().having((x) => x.field, 'field', field)));
      bad(checkIn(mood: 0, changed: {'mood_rating'}), 'mood_rating');
      bad(checkIn(energy: 6, changed: {'motivation_energy_rating'}), 'motivation_energy_rating');
      bad(checkIn(stress: 9, changed: {'perceived_stress_rating'}), 'perceived_stress_rating');
      SleepEntry sleep({int dur = 450, String bed = '23:30', String wake = '07:00', int q = 4}) => SleepEntry(
          durationMinutes: dur,
          bedtimeLocal: bed,
          wakeTimeLocal: wake,
          restQuality: q,
          day: day,
          provenance: prov(SleepEntry.allFields, SleepEntry.allFields));
      bad(sleep(dur: 210), 'duration_minutes');
      bad(sleep(dur: 750), 'duration_minutes');
      bad(sleep(dur: 465), 'duration_minutes');
      bad(sleep(bed: '24:00'), 'bedtime_local');
      bad(sleep(wake: '7:00'), 'wake_time_local');
      bad(sleep(q: 6), 'rest_quality');
      WorkloadEntry work({int m = 3, int e = 3, int d = 1}) => WorkloadEntry(
          mentalDemand: m, effort: e, deadlines48h: d, day: day, provenance: prov(WorkloadEntry.allFields, WorkloadEntry.allFields));
      bad(work(m: 6), 'mental_demand');
      bad(work(e: 0), 'effort');
      bad(work(d: 21), 'deadlines_48h');
      bad(work(d: -1), 'deadlines_48h');
      ActivityEntry act(int steps, int mins, Set<String> changed) =>
          ActivityEntry(steps: steps, activeMinutes: mins, day: day, provenance: prov(ActivityEntry.allFields, changed));
      bad(act(6800, 35, {'steps'}), 'steps'); // 6,800 is only valid as the untouched default
      bad(act(6750, 35, {'steps'}), 'steps');
      bad(act(500, 35, {'steps'}), 'steps');
      bad(act(20500, 35, {'steps'}), 'steps');
      bad(act(7000, 37, {'steps', 'active_minutes'}), 'active_minutes');
      bad(act(7000, 125, {'steps', 'active_minutes'}), 'active_minutes');
      expect(() => const LocalDay('2026-02-30', 0).validate(), throwsA(isA<DataValidationException>()));
      expect(() => const LocalDay('2026-11-08', 900).validate(), throwsA(isA<DataValidationException>()));
    });

    test('provenance must account for every field, and untouched fields must hold the default', () {
      expect(checkIn(mood: 5).validate, throwsA(isA<DataValidationException>()),
          reason: 'mood marked untouched but not the default 3');
      final p = Provenance(changedFields: {'mood_rating'}, defaultFields: {'mood_rating'}, submittedAtUtc: submitted);
      expect(
          () => CheckInEntry(moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: day, provenance: p)
              .validate(),
          throwsA(isA<DataValidationException>()));
      expect(LocalDay.fromLocal(DateTime(2026, 1, 5, 23, 59)).date, '2026-01-05');
      expect(() => LocalDay.fromLocal(DateTime.utc(2026)), throwsA(isA<DataValidationException>()));
    });

    test('SQLite CHECK constraints reject invalid rows even if Dart validation is bypassed', () async {
      final db = await open(steppingClock());
      final person = (await LocalDataStore(db).profiles.ensureActive()).localPersonId;
      Map<String, Object?> base(String id) => {
            'id': id,
            'local_person_id': person,
            'local_date': '2026-11-08',
            'tz_offset_minutes': 330,
            'created_at_utc': 'x',
            'updated_at_utc': 'x',
            'submitted_at_utc': 'x',
            'schema_version': 2,
            'explicitly_submitted': 1,
            'changed_fields': '[]',
            'default_fields': '[]',
          };
      var n = 0;
      Future<void> rejects(String table, Map<String, Object?> cols) async {
        n++;
        await expectLater(
            db.insert(table, {...base('00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}'), ...cols}),
            throwsA(isA<DatabaseException>()),
            reason: '$table $cols');
      }

      await rejects('check_ins', {'mood_rating': 0, 'motivation_energy_rating': 3, 'perceived_stress_rating': 2});
      await rejects('sleep_records',
          {'duration_minutes': 465, 'bedtime_local': '23:30', 'wake_time_local': '07:00', 'rest_quality': 4, 'source': 'MANUAL_LOG'});
      await rejects('sleep_records',
          {'duration_minutes': 450, 'bedtime_local': '23:30', 'wake_time_local': '07:00', 'rest_quality': 4, 'source': 'HEALTH_CONNECT'});
      await rejects('workload_records', {'mental_demand': 3, 'effort': 3, 'deadlines_48h': 21});
      await rejects('activity_records',
          {'steps': 6800, 'steps_is_initial_default': 0, 'active_minutes': 35, 'source': 'MANUAL_LOG'});
      await rejects('activity_records',
          {'steps': 7000, 'steps_is_initial_default': 1, 'active_minutes': 35, 'source': 'MANUAL_LOG'});
      await rejects('activity_records',
          {'steps': 7000, 'steps_is_initial_default': 0, 'active_minutes': 37, 'source': 'MANUAL_LOG'});
      await rejects('check_ins', {
        'local_date': '08-11-2026',
        'mood_rating': 3,
        'motivation_energy_rating': 3,
        'perceived_stress_rating': 2,
      });
      await db.close();
    });

    test('sleep times: the SQLite CHECK enforces exactly the Dart HH:MM rule (direct SQL)', () async {
      final db = await open(steppingClock());
      final person = (await LocalDataStore(db).profiles.ensureActive()).localPersonId;
      var n = 0;
      // Raw SQL, bypassing every Dart validator. A fresh date per row avoids
      // the one-per-day rule. Returns true when SQLite accepts the row.
      Future<bool> sqlAccepts({String bed = '23:30', String wake = '07:00'}) async {
        n++;
        final date = DateTime.utc(2026, 1, 1).add(Duration(days: n)).toIso8601String().substring(0, 10);
        try {
          await db.rawInsert(
            'INSERT INTO sleep_records (id, local_person_id, local_date, tz_offset_minutes, created_at_utc, '
            'updated_at_utc, submitted_at_utc, schema_version, explicitly_submitted, changed_fields, default_fields, '
            'duration_minutes, bedtime_local, wake_time_local, rest_quality, source) '
            "VALUES (?, ?, ?, 330, 'x', 'x', 'x', 2, 1, '[]', '[]', 450, ?, ?, 4, 'MANUAL_LOG')",
            ['00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}', person, date, bed, wake],
          );
          return true;
        } on DatabaseException {
          return false;
        }
      }

      bool dartAccepts(String bed) {
        try {
          SleepEntry(
            durationMinutes: 450,
            bedtimeLocal: bed,
            wakeTimeLocal: '07:00',
            restQuality: 4,
            day: day,
            provenance: prov(SleepEntry.allFields, SleepEntry.allFields),
          ).validate();
          return true;
        } on DataValidationException {
          return false;
        }
      }

      const valid = ['00:00', '00:59', '09:05', '12:00', '19:59', '20:00', '23:00', '23:59'];
      const invalidHours = ['24:00', '29:30', '30:00', '99:99'];
      const invalidMinutes = ['12:60', '00:99', '23:75'];
      const wrongLength = ['7:30', '007:30', '12:3', '12:300', '', '23:59\n', ' 23:59'];
      const badSeparatorOrChars = ['aa:bb', '12-30', '12 30', '12.30', '1a:30', '12:3b', '12::0', '１２:３０'];

      for (final t in valid) {
        expect(await sqlAccepts(bed: t), isTrue, reason: 'bedtime $t should be accepted');
        expect(await sqlAccepts(wake: t), isTrue, reason: 'wake time $t should be accepted');
      }
      for (final t in [...invalidHours, ...invalidMinutes, ...wrongLength, ...badSeparatorOrChars]) {
        expect(await sqlAccepts(bed: t), isFalse, reason: 'bedtime "$t" should be rejected by SQLite');
        expect(await sqlAccepts(wake: t), isFalse, reason: 'wake time "$t" should be rejected by SQLite');
      }
      // Parity: for every case the database and the Dart validator agree.
      for (final t in [...valid, ...invalidHours, ...invalidMinutes, ...wrongLength, ...badSeparatorOrChars]) {
        expect(await sqlAccepts(bed: t), dartAccepts(t), reason: 'SQLite and Dart disagree on "$t"');
      }
      await db.close();
    });

    test('sleep times: repository writes still validate in Dart first and store valid boundaries', () async {
      final db = await open(steppingClock());
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      await allowAll(db, person);
      SleepEntry sleep(String bed, String wake, LocalDay d) => SleepEntry(
          durationMinutes: 450,
          bedtimeLocal: bed,
          wakeTimeLocal: wake,
          restQuality: 4,
          day: d,
          provenance: prov(SleepEntry.allFields, SleepEntry.allFields));
      final saved = await store.sleep.upsert(person, sleep('00:00', '23:59', day));
      expect((await store.sleep.byDate(person, day.date))!.entry.bedtimeLocal, '00:00');
      expect(saved.entry.wakeTimeLocal, '23:59');
      for (final bad in ['24:00', '12:60', '7:30', '12-30']) {
        expect(() => store.sleep.upsert(person, sleep(bad, '07:00', const LocalDay('2026-11-09', 330))),
            throwsA(isA<DataValidationException>().having((e) => e.field, 'field', 'bedtime_local')));
      }
      expect(await store.sleep.byDate(person, '2026-11-09'), isNull, reason: 'nothing written');
      await db.close();
    });
  });

  // ---- Integrity ---------------------------------------------------------------------------------
  group('Integrity', () {
    test('foreign keys: a record for an unknown person is refused; deleting a profile cascades', () async {
      final db = await open(steppingClock());
      final store = LocalDataStore(db);
      // Milestone B refuses an unknown person before the insert is attempted.
      await expectLater(store.checkIns.upsert('00000000-0000-4000-8000-00000000dead', checkIn()),
          throwsA(isA<ConsentDeniedException>()));
      // The foreign key still refuses it at the SQLite level.
      await expectLater(
          db.insert('check_ins', {
            'id': '00000000-0000-4000-8000-000000000001',
            'local_person_id': '00000000-0000-4000-8000-00000000dead',
            'local_date': '2026-11-08',
            'tz_offset_minutes': 0,
            'created_at_utc': 'x',
            'updated_at_utc': 'x',
            'submitted_at_utc': 'x',
            'schema_version': 2,
            'explicitly_submitted': 1,
            'changed_fields': '[]',
            'default_fields': '[]',
            'mood_rating': 3,
            'motivation_energy_rating': 3,
            'perceived_stress_rating': 2,
          }),
          throwsA(isA<DatabaseException>()));
      final person = (await store.profiles.ensureActive()).localPersonId;
      await allowAll(db, person);
      await store.checkIns.upsert(person, checkIn());
      expect(await store.profiles.delete(person), isTrue);
      expect(await db.query('check_ins'), isEmpty);
      await db.close();
    });

    test('a transaction that fails rolls back every write in it', () async {
      final db = await open(steppingClock());
      final person = (await LocalDataStore(db).profiles.ensureActive()).localPersonId;
      await allowAll(db, person);
      await expectLater(
        LocalDataStore.transaction(db, (store) async {
          await store.checkIns.upsert(person, checkIn());
          await store.workload.upsert(
              person,
              WorkloadEntry(
                  mentalDemand: 3, effort: 3, deadlines48h: 1, day: day, provenance: prov(WorkloadEntry.allFields, {})));
          throw StateError('simulated failure after two writes');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await db.query('check_ins'), isEmpty);
      expect(await db.query('workload_records'), isEmpty);
      await db.close();
    });

    test('records of different local people are isolated', () async {
      final db = await open(steppingClock());
      final store = LocalDataStore(db);
      final a = (await store.profiles.ensureActive()).localPersonId;
      const b = '11111111-1111-4111-8111-111111111111';
      await db.insert('local_profile', {'local_person_id': b, 'created_at_utc': 'x', 'is_active': 0});
      await allowAll(db, a);
      await allowAll(db, b);
      await store.checkIns.upsert(a, checkIn(mood: 1, changed: {'mood_rating'}));
      await store.checkIns.upsert(b, checkIn(mood: 5, changed: {'mood_rating'}));
      expect((await store.checkIns.byDate(a, '2026-11-08'))!.entry.moodRating, 1);
      expect((await store.checkIns.byDate(b, '2026-11-08'))!.entry.moodRating, 5);
      expect(await store.checkIns.range(a, fromDate: '2000-01-01', toDate: '2100-01-01'), hasLength(1));
      await store.checkIns.deleteByDate(a, '2026-11-08');
      expect(await store.checkIns.byDate(b, '2026-11-08'), isNotNull);
      await db.close();
    });
  });

  // ---- Boundaries ---------------------------------------------------------------------------------
  group('Boundaries', () {
    test('the data layer is pure Dart: no Flutter imports, no journal write, nothing in the app uses it', () {
      final files = Directory('lib/data/local').listSync().whereType<File>().toList();
      expect(files.map((f) => f.uri.pathSegments.last),
          containsAll(['records.dart', 'schema.dart', 'repositories.dart', 'sqlite_repositories.dart', 'local_data_store.dart']));
      // Directives are parsed (any quoting, export and part, conditional URIs).
      final lib = parseDartTree('lib');
      for (final f in files) {
        final src = f.readAsStringSync();
        final path = f.path.replaceAll('\\', '/');
        final flutter = lib[path]!.uris.where((u) => u.startsWith('package:flutter/')).toList();
        if (path == 'lib/data/local/sense_storage.dart') {
          // Milestone K1: the app-facing storage owner is the one Flutter-aware
          // file, and it may use foundation (ChangeNotifier) only.
          expect(flutter, ['package:flutter/foundation.dart'], reason: path);
        } else {
          expect(flutter, isEmpty, reason: path);
        }
        expect(RegExp(r"insert\(\s*'journal").hasMatch(src), isFalse, reason: f.path);
      }
      // Milestone K1: only the app entry point, the consent model and the
      // storage scope may reach the data layer, and only through the storage
      // owner (never the repositories, schema or database helpers directly).
      // Milestone K2 adds the Workload controller, which reaches workload
      // records only through the narrow WorkloadAccess re-exported there.
      const allowed = {
        'lib/main.dart',
        'lib/core/state/consent_preferences.dart',
        'lib/core/state/workload_controller.dart',
        // Milestone K3: the Check-in controller, through the narrow CheckInAccess.
        'lib/core/state/check_in_controller.dart',
        // Milestone K4: the Sleep controller, through the narrow SleepAccess.
        'lib/core/state/sleep_controller.dart',
        'lib/presentation/widgets/sense_storage_scope.dart',
      };
      final appFiles = lib.values.where((f) => !f.path.startsWith('lib/data/')).toList();
      expect(appFiles.map((f) => f.path), containsAll(allowed));
      for (final f in appFiles) {
        // Relative and package:mindpulse/ URIs, resolved to project paths.
        final data = f.directives.where((d) => d.projectPath?.startsWith('lib/data/') ?? false).toList();
        if (allowed.contains(f.path)) {
          expect(data.map((d) => '${d.kind.name} ${d.projectPath}'), everyElement('import lib/data/local/sense_storage.dart'),
              reason: f.path);
        } else {
          expect(data, isEmpty, reason: '${f.path} must not use the data layer');
        }
      }
    });
  });
}
