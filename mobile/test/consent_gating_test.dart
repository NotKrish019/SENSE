import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Milestone B: append-only modality consent history and mandatory write
/// gating, tested directly against the repositories on disposable SQLite
/// files. Nothing here is connected to the app, and the database is NOT
/// encrypted.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sense_consent_');
    path = '${dir.path}/$kLocalDatabaseFileName';
  });
  tearDown(() async {
    await factory.deleteDatabase(path);
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<Database> open() => SenseDatabase.open(factory: factory, path: path);

  const day = LocalDay('2026-11-08', 330);
  final submitted = DateTime.utc(2026, 11, 8, 8, 30);
  Provenance untouched(Set<String> all) =>
      Provenance.fromChanged(allFields: all, changed: const {}, submittedAtUtc: submitted);

  CheckInEntry checkIn([LocalDay d = day]) => CheckInEntry(
      moodRating: 3, motivationEnergyRating: 3, perceivedStressRating: 2, day: d, provenance: untouched(CheckInEntry.allFields));
  SleepEntry sleep([LocalDay d = day]) => SleepEntry(
      durationMinutes: 450,
      bedtimeLocal: '23:30',
      wakeTimeLocal: '07:00',
      restQuality: 4,
      day: d,
      provenance: untouched(SleepEntry.allFields));
  WorkloadEntry workload([LocalDay d = day]) =>
      WorkloadEntry(mentalDemand: 3, effort: 3, deadlines48h: 1, day: d, provenance: untouched(WorkloadEntry.allFields));
  ActivityEntry activity([LocalDay d = day]) =>
      ActivityEntry(steps: 6800, activeMinutes: 35, day: d, provenance: untouched(ActivityEntry.allFields));

  /// The four gated daily repositories, with the preference each requires.
  List<({String modality, String table, Future<Object?> Function(String person) write})> gated(LocalDataStore s) => [
        (modality: 'M1', table: 'check_ins', write: (p) => s.checkIns.upsert(p, checkIn())),
        (modality: 'M3', table: 'sleep_records', write: (p) => s.sleep.upsert(p, sleep())),
        (modality: 'M4', table: 'workload_records', write: (p) => s.workload.upsert(p, workload())),
        (modality: 'M6', table: 'activity_records', write: (p) => s.activity.upsert(p, activity())),
      ];

  Matcher denied(String modality, ConsentDenialReason reason) => throwsA(isA<ConsentDeniedException>()
      .having((e) => e.modality, 'modality', modality)
      .having((e) => e.reason, 'reason', reason));

  Future<int> count(Database db, String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n'] as int;

  // ---- Defaults ------------------------------------------------------------------------------
  group('Consent defaults', () {
    test('a new local person has all six preferences OFF and no events are seeded', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      expect(await count(db, 'consent_events'), 0);
      expect(await store.consent.currentPreferences(person),
          {'M1': false, 'M2': false, 'M3': false, 'M4': false, 'M5': false, 'M6': false});
      for (final m in kModalityCodes) {
        expect(await store.consent.isEnabled(person, m), isFalse, reason: m);
      }
      final snap = await store.consent.snapshot(person);
      expect(snap.latest.keys, kModalityCodes);
      expect(snap.latest.values, everyElement(isNull));
      expect(await store.consent.history(person), isEmpty);
      await db.close();
    });

    test('a missing preference reads OFF, also for an unknown person', () async {
      final db = await open();
      final store = LocalDataStore(db);
      const nobody = '00000000-0000-4000-8000-00000000beef';
      expect((await store.consent.currentPreferences(nobody)).values, everyElement(isFalse));
      expect(await store.consent.isEnabled(nobody, 'M1'), isFalse);
      await db.close();
    });

    test('unknown modalities and unknown people cannot record events', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      expect(() => store.consent.recordChange(person, 'M7', true), throwsA(isA<DataValidationException>()));
      expect(() => store.consent.isEnabled(person, 'm1'), throwsA(isA<DataValidationException>()));
      await expectLater(store.consent.recordChange('00000000-0000-4000-8000-00000000beef', 'M1', true),
          throwsA(isA<DataValidationException>()));
      expect(await count(db, 'consent_events'), 0);
      await db.close();
    });

    test('the persistent identifiers match the in-memory UI identifiers M1 to M6', () {
      expect(InputModality.values.map((m) => m.code).toList(), kModalityCodes);
    });
  });

  // ---- History -------------------------------------------------------------------------------
  group('Consent history', () {
    test('each change appends an event; earlier events stay intact; the latest wins', () async {
      final db = await open();
      var t = DateTime.utc(2026, 11, 8, 9);
      final store = LocalDataStore(db, clock: () => t = t.add(const Duration(minutes: 1)));
      final person = (await store.profiles.ensureActive()).localPersonId;

      final on = await store.consent.recordChange(person, 'M3', true);
      expect(on.enabled, isTrue);
      expect(on.changedAtUtc, DateTime.utc(2026, 11, 8, 9, 2));
      expect(await store.consent.isEnabled(person, 'M3'), isTrue);

      final off = await store.consent.recordChange(person, 'M3', false);
      expect(off.id, greaterThan(on.id));
      expect(await store.consent.isEnabled(person, 'M3'), isFalse);

      final history = await store.consent.history(person, modality: 'M3');
      expect(history.map((e) => e.id), [on.id, off.id]);
      expect(history.map((e) => e.enabled), [true, false]);
      expect(history.first.changedAtUtc, on.changedAtUtc, reason: 'the first event is not overwritten');
      final row = (await db.query('consent_events', where: 'id = ?', whereArgs: [on.id])).single;
      expect(row['enabled'], 1, reason: 'stored row unchanged');
      expect((await store.consent.snapshot(person)).latest['M3']!.id, off.id);
      await db.close();
    });

    test('modalities are independent', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      await store.consent.recordChange(person, 'M1', true);
      await store.consent.recordChange(person, 'M6', true);
      await store.consent.recordChange(person, 'M6', false);
      expect(await store.consent.currentPreferences(person),
          {'M1': true, 'M2': false, 'M3': false, 'M4': false, 'M5': false, 'M6': false});
      expect(await store.consent.history(person), hasLength(3));
      expect(await store.consent.history(person, modality: 'M1'), hasLength(1));
      await db.close();
    });

    test('different local people are isolated', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final a = (await store.profiles.ensureActive()).localPersonId;
      const b = '11111111-1111-4111-8111-111111111111';
      await db.insert('local_profile', {'local_person_id': b, 'created_at_utc': '2026-11-08T00:00:00.000Z', 'is_active': 0});
      await store.consent.recordChange(a, 'M1', true);
      expect(await store.consent.isEnabled(b, 'M1'), isFalse);
      expect(await store.consent.history(b), isEmpty);
      await store.consent.recordChange(b, 'M1', true);
      await store.consent.recordChange(a, 'M1', false);
      expect(await store.consent.isEnabled(a, 'M1'), isFalse);
      expect(await store.consent.isEnabled(b, 'M1'), isTrue);
      await expectLater(store.checkIns.upsert(a, checkIn()), denied('M1', ConsentDenialReason.disabled));
      await store.checkIns.upsert(b, checkIn());
      expect(await count(db, 'check_ins'), 1);
      await db.close();
    });

    test('events with the same timestamp are ordered by their increasing event id', () async {
      final db = await open();
      final frozen = DateTime.utc(2026, 11, 8, 12);
      final store = LocalDataStore(db, clock: () => frozen);
      final person = (await store.profiles.ensureActive()).localPersonId;
      final e1 = await store.consent.recordChange(person, 'M4', true);
      final e2 = await store.consent.recordChange(person, 'M4', false);
      final e3 = await store.consent.recordChange(person, 'M4', true);
      final history = await store.consent.history(person, modality: 'M4');
      expect(history.map((e) => e.changedAtUtc).toSet(), {frozen}, reason: 'identical timestamps');
      expect(history.map((e) => e.id), [e1.id, e2.id, e3.id]);
      expect(e1.id < e2.id && e2.id < e3.id, isTrue);
      expect(await store.consent.isEnabled(person, 'M4'), isTrue, reason: 'latest by id, not by time');
      await store.consent.recordChange(person, 'M4', false);
      expect(await store.consent.isEnabled(person, 'M4'), isFalse);
      // Repeated reads give the same order.
      expect((await store.consent.history(person)).map((e) => e.id).toList(),
          (await store.consent.history(person)).map((e) => e.id).toList());
      await db.close();
    });
  });

  // ---- Write gating ----------------------------------------------------------------------------
  group('Write gating', () {
    test('each of M1, M3, M4 and M6 refuses writes while its preference was never turned on', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      for (final g in gated(store)) {
        await expectLater(g.write(person), denied(g.modality, ConsentDenialReason.notRecorded), reason: g.table);
        expect(await count(db, g.table), 0, reason: g.table);
      }
      await db.close();
    });

    test('each repository requires its own preference, and only that one', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      // M2 (journal) and M5 (voice) unlock nothing: they have no write repository.
      await store.consent.recordChange(person, 'M2', true);
      await store.consent.recordChange(person, 'M5', true);
      for (final g in gated(store)) {
        await expectLater(g.write(person), denied(g.modality, ConsentDenialReason.notRecorded));
      }
      for (final g in gated(store)) {
        await store.consent.recordChange(person, g.modality, true);
        await g.write(person);
        expect(await count(db, g.table), 1, reason: '${g.modality} allows ${g.table}');
        for (final other in gated(store).where((o) => o.table != g.table)) {
          final enabled = await store.consent.isEnabled(person, other.modality);
          if (!enabled) {
            await expectLater(other.write(person), denied(other.modality, ConsentDenialReason.notRecorded));
          }
        }
      }
      await db.close();
    });

    test('turning a preference off blocks later writes, keeps existing records; on again allows writes', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      for (final g in gated(store)) {
        await store.consent.recordChange(person, g.modality, true);
        await g.write(person);
        await store.consent.recordChange(person, g.modality, false);
        await expectLater(g.write(person), denied(g.modality, ConsentDenialReason.disabled));
        expect(await count(db, g.table), 1, reason: 'turning ${g.modality} off does not delete ${g.table}');
        await store.consent.recordChange(person, g.modality, true);
        await g.write(person); // same date: updates the one record
        expect(await count(db, g.table), 1);
      }
      expect(await store.checkIns.byDate(person, day.date), isNotNull);
      await db.close();
    });

    test('a missing local profile fails closed', () async {
      final db = await open();
      final store = LocalDataStore(db);
      const nobody = '00000000-0000-4000-8000-00000000beef';
      for (final g in gated(store)) {
        await expectLater(g.write(nobody), denied(g.modality, ConsentDenialReason.noProfile));
        expect(await count(db, g.table), 0);
      }
      await db.close();
    });

    test('an unreadable consent state fails closed: no fallback to legacy all-on seeds', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      for (final g in gated(store)) {
        await store.consent.recordChange(person, g.modality, true);
      }
      // A legacy pre-ticked table must not be consulted.
      await db.execute('CREATE TABLE legacy_v1_consent_settings (modality_key TEXT PRIMARY KEY, '
          'is_consented INTEGER NOT NULL, updated_timestamp_utc TEXT NOT NULL)');
      await db.insert('legacy_v1_consent_settings', {'modality_key': 'check_in', 'is_consented': 1, 'updated_timestamp_utc': 'x'});
      // Simulate an unavailable consent table (disposable database only).
      await db.execute('ALTER TABLE consent_events RENAME TO consent_events_unavailable');
      for (final g in gated(store)) {
        await expectLater(
            g.write(person),
            throwsA(isA<ConsentDeniedException>()
                .having((e) => e.reason, 'reason', ConsentDenialReason.unavailable)
                .having((e) => e.cause, 'cause', isNotNull)));
        expect(await count(db, g.table), 0);
      }
      await db.close();
    });

    test('a corrupt consent row fails closed', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      await db.insert('consent_events',
          {'local_person_id': person, 'modality': 'M1', 'enabled': 1, 'changed_at_utc': 'not a timestamp'});
      await expectLater(store.checkIns.upsert(person, checkIn()), denied('M1', ConsentDenialReason.unavailable));
      expect(await count(db, 'check_ins'), 0);
      await db.close();
    });

    test('the denial message is safe: it names the modality and contains no record values', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      try {
        await store.sleep.upsert(person, sleep());
        fail('expected a denial');
      } on ConsentDeniedException catch (e) {
        expect(e.message, contains('M3'));
        expect(e.toString(), isNot(contains(person)));
        expect(e.toString(), isNot(contains('23:30')));
      }
      await db.close();
    });
  });

  // ---- Transactions --------------------------------------------------------------------------
  group('Transaction integrity', () {
    test('a consent change and a record written under it commit together', () async {
      final db = await open();
      final person = (await LocalDataStore(db).profiles.ensureActive()).localPersonId;
      await LocalDataStore.transaction(db, (store) async {
        await store.consent.recordChange(person, 'M1', true);
        await store.checkIns.upsert(person, checkIn());
      });
      expect(await count(db, 'consent_events'), 1);
      expect(await count(db, 'check_ins'), 1);
      await db.close();
    });

    test('a failure after both rolls back the event and the record', () async {
      final db = await open();
      final person = (await LocalDataStore(db).profiles.ensureActive()).localPersonId;
      await expectLater(
        LocalDataStore.transaction(db, (store) async {
          await store.consent.recordChange(person, 'M6', true);
          await store.activity.upsert(person, activity());
          throw StateError('simulated failure');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await count(db, 'consent_events'), 0);
      expect(await count(db, 'activity_records'), 0);
      expect(await LocalDataStore(db).consent.isEnabled(person, 'M6'), isFalse);
      await db.close();
    });

    test('a denied write inside a transaction rolls back the whole transaction', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      await store.consent.recordChange(person, 'M1', true);
      await expectLater(
        LocalDataStore.transaction(db, (txStore) async {
          await txStore.checkIns.upsert(person, checkIn());
          await txStore.consent.recordChange(person, 'M3', false);
          await txStore.sleep.upsert(person, sleep()); // M3 off: denied
        }),
        denied('M3', ConsentDenialReason.disabled),
      );
      expect(await count(db, 'check_ins'), 0);
      expect(await count(db, 'consent_events'), 1, reason: 'only the event from before the transaction');
      await db.close();
    });

    test('a write waits for an open consent change and then sees it (same connection)', () async {
      final db = await open();
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      await store.consent.recordChange(person, 'M1', true);

      final release = Completer<void>();
      final turnedOff = Completer<void>();
      final change = LocalDataStore.transaction(db, (txStore) async {
        await txStore.consent.recordChange(person, 'M1', false);
        turnedOff.complete();
        await release.future; // hold the transaction open
      });
      await turnedOff.future;
      var writeFinished = false;
      final write = store.checkIns.upsert(person, checkIn()).whenComplete(() => writeFinished = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(writeFinished, isFalse, reason: 'the write is queued behind the consent transaction');
      release.complete();
      await change;
      await expectLater(write, denied('M1', ConsentDenialReason.disabled));
      expect(await count(db, 'check_ins'), 0);
      await db.close();
    });

    test('two connections: a write waits for an open consent change on another connection, then is refused',
        () async {
      // Setup on its own connection: one person with M1 ON.
      final setup = await open();
      final person = (await LocalDataStore(setup).profiles.ensureActive()).localPersonId;
      await LocalDataStore(setup).consent.recordChange(person, 'M1', true);
      await setup.close();

      // Connection A runs in a separate isolate with its own in-isolate SQLite,
      // so B can genuinely wait on SQLite's lock without blocking A. (All
      // sqflite_common_ffi connections in one isolate share a single worker.)
      final fromA = ReceivePort();
      final messages = StreamIterator<Object?>(fromA);
      Future<Object?> nextFromA() async {
        if (!await messages.moveNext().timeout(const Duration(seconds: 20))) return null;
        return messages.current;
      }

      const holdMs = 800;
      await Isolate.spawn(_holdConsentOffUncommitted, [fromA.sendPort, path, person, holdMs],
          onError: fromA.sendPort, errorsAreFatal: true);

      // 1. A has written M1 OFF inside a transaction it has not committed.
      expect(await nextFromA(), 'uncommitted');

      // 2. B attempts an M1 write while A's transaction is open.
      final b = await factory.openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));
      await b.rawQuery('PRAGMA busy_timeout = 20000'); // wait for the lock instead of failing at once
      await b.execute('PRAGMA foreign_keys = ON');
      final clock = Stopwatch()..start();
      final outcome = await LocalDataStore(b)
          .checkIns
          .upsert(person, checkIn())
          .then<Object?>((_) => 'written', onError: (Object e) => e);
      clock.stop();

      // 3. A then committed; B could not finish before that.
      expect(await nextFromA(), 'committed');
      expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(holdMs ~/ 2),
          reason: 'B was blocked until A finished (elapsed ${clock.elapsedMilliseconds} ms)');

      // 4. B's write is refused because the committed latest event is OFF.
      expect(outcome, isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.disabled),
          reason: 'outcome: $outcome');

      // 5. No record was inserted; the OFF event is the latest.
      expect(await count(b, 'check_ins'), 0);
      expect(await LocalDataStore(b).consent.isEnabled(person, 'M1'), isFalse);
      await b.close();
      fromA.close();
    });
  });

  // ---- Boundaries ----------------------------------------------------------------------------
  group('Boundaries', () {
    String read(String p) => File(p).readAsStringSync();

    test('only the consent model uses the consent repository; no screen writes records or opens a database', () {
      final appFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('lib/data/'));
      for (final f in appFiles) {
        final path = f.path.replaceAll('\\', '/');
        final src = f.readAsStringSync();
        expect(src, isNot(contains('SenseDatabase')), reason: path);
        expect(src, isNot(contains('openDatabase')), reason: path);
        expect(src, isNot(contains('EncryptedDatabaseProvider')), reason: path);
        // Milestone K1: Save handlers stay disconnected; no daily record is written.
        expect(src, isNot(contains('.upsert(')), reason: path);
        expect(src, isNot(contains('deleteByDate')), reason: path);
        if (path != 'lib/core/state/consent_preferences.dart') {
          expect(src, isNot(contains('recordChange')), reason: path);
          expect(src, isNot(contains('.consent.')), reason: path);
        }
      }
      expect(read('lib/data/local/local_data_store.dart'), isNot(contains('static final')),
          reason: 'no global instance that silently opens the database');
      expect(read('lib/data/local/sense_storage.dart'), isNot(contains('static final')),
          reason: 'the storage owner is created by the app, never a global connection');
    });

    test('consent history has no update or delete path in the repository code', () {
      final src = read('lib/data/local/sqlite_repositories.dart');
      expect(src, isNot(contains("update('consent_events'")));
      expect(src, isNot(contains("delete('consent_events'")));
      expect(src.toUpperCase(), isNot(contains('UPDATE CONSENT_EVENTS')));
      expect(src.toUpperCase(), isNot(contains('DELETE FROM CONSENT_EVENTS')));
    });

    test('no journal, voice or Health Connect persistence is introduced', () {
      for (final f in Directory('lib/data/local').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(RegExp(r"insert\(\s*'(journal|voice)").hasMatch(src), isFalse, reason: f.path);
        expect(RegExp(r'CREATE TABLE[^(]*(journal|voice|health)', caseSensitive: false).hasMatch(src), isFalse,
            reason: f.path);
      }
      final pubspec = read('pubspec.yaml');
      for (final pkg in ['health:', 'record:', 'speech_to_text:', 'flutter_secure_storage:']) {
        expect(pubspec, isNot(contains(pkg)), reason: pkg);
      }
      // Milestone J adds exactly one SQLCipher driver, pinned exactly (see
      // docs/architecture/encrypted_local_storage.md). No other is allowed.
      expect(RegExp(r'^\s+\w*sqlcipher\w*:.*$', multiLine: true).allMatches(pubspec).map((m) => m[0]!.trim()),
          ['sqflite_sqlcipher: 3.4.1']);
    });

    test('the consent model starts OFF and in memory, and reaches storage only through the owner', () {
      final prefs = ConsentPreferences.instance..reset();
      expect(prefs.persistence, ConsentPersistence.memoryOnly);
      expect(InputModality.values.map(prefs.isEnabled), everyElement(isFalse));
      prefs.setEnabled(InputModality.sleep, true);
      expect(prefs.isEnabled(InputModality.sleep), isTrue);
      prefs.reset();
      final model = read('lib/core/state/consent_preferences.dart');
      final screen = read('lib/presentation/screens/consent_screen.dart');
      for (final src in [model, screen]) {
        expect(src, isNot(contains('sqflite')));
      }
      // Milestone K1: the model may use the storage owner only; the screen none.
      expect(RegExp(r"import '[^']*data/[^']*'").allMatches(model).map((m) => m[0]),
          ["import '../../data/local/sense_storage.dart'"]);
      expect(screen, isNot(contains('data/local')));
      expect(model, contains('By default nothing here is persisted'));
      expect(screen, contains('Your choices are kept only while the app is open. They are not saved'));
    });
  });
}

/// Connection A for the two-connection test, in its own isolate: turns M1 OFF
/// inside a transaction, reports 'uncommitted', holds the transaction (and
/// SQLite's write lock) open for the given time, then commits and reports
/// 'committed'.
Future<void> _holdConsentOffUncommitted(List<Object> args) async {
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
    await store.consent.recordChange(person, 'M1', false);
    send.send('uncommitted');
    await Future<void>.delayed(Duration(milliseconds: holdMs));
  });
  send.send('committed');
  await db.close();
}
