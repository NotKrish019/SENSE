import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_service.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:sqflite/sqflite.dart' as plain;
import 'package:sqflite/sqlite_api.dart';

/// Milestone J, test groups B (SQLCipher) and C (on-disk encryption), on an
/// Android device or emulator, through the real platform channel, Android
/// Keystore, sqflite_sqlcipher driver and SQLCipher for Android 4.20.0.
///
/// Every test uses its own debug-only test namespace (own Keystore alias and
/// directory), and destroys it afterwards. The app's real key and files, and
/// any real legacy database, are never touched.
///
///   flutter test integration_test/encrypted_database_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = createDefaultSecureKeyPlatform();
  final random = Random.secure();

  String hexOf(int bytes) => List.generate(bytes, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  late String ns;
  late EncryptedDatabaseProvider provider;
  late Map<String, Object?> paths;
  late String dbPath;
  late String legacyPath;
  late String storageDir;
  final toClose = <Database>[];

  setUp(() async {
    ns = 'itest_${hexOf(6)}';
    provider = EncryptedDatabaseProvider(testNamespace: ns);
    paths = await platform.inspect(testNamespace: ns);
    dbPath = paths['databasePath'] as String;
    legacyPath = paths['legacyDatabasePath'] as String;
    storageDir = paths['storageDirectory'] as String;
    expect(paths['databasePresent'], isFalse);
    expect(paths['envelopePresent'], isFalse);
    expect(paths['keyAliasPresent'], isFalse);
  });

  tearDown(() async {
    for (final db in toClose) {
      if (db.isOpen) await db.close();
    }
    toClose.clear();
    // Through the lifecycle owner: releases any lease, then destroys.
    await provider.close();
    await provider.destroyKeyAndDatabase();
    final dir = Directory(storageDir);
    if (await dir.exists()) await dir.delete(recursive: true);
  });


  Future<EncryptedDatabaseOpened> openOk() async {
    final r = await provider.open();
    expect(r, isA<EncryptedDatabaseOpened>(), reason: '$r');
    final opened = r as EncryptedDatabaseOpened;
    toClose.add(opened.database);
    return opened;
  }

  /// The raw passphrase through the native lease protocol, for driver-level
  /// tests that open the file directly: the lease is taken, [body] runs, then
  /// the setup is committed (if a database now exists) and the lease released.
  Future<T> withRawKey<T>(Future<T> Function(String passphrase) body) async {
    await provider.close();
    final key = await platform.openKey(testNamespace: ns);
    expect(key['status'], 'ready', reason: '${key['failure']}');
    final lease = key['leaseId'] as String;
    try {
      return await body(key['passphrase'] as String);
    } finally {
      await platform.commitOpen(lease, testNamespace: ns);
      await platform.release(lease, testNamespace: ns);
    }
  }

  Future<String> sha(String path) async => sha256.convert(await File(path).readAsBytes()).toString();

  Future<Map<String, List<int>>> filesOf(String base) async => {
        for (final suffix in ['', '-wal', '-shm', '-journal'])
          if (await File('$base$suffix').exists()) '$base$suffix': await File('$base$suffix').readAsBytes(),
      };

  int indexOf(List<int> hay, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= hay.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  List<List<int>> encodings(String s) => [
        utf8.encode(s),
        [for (final c in s.codeUnits) ...[c & 0xff, c >> 8]], // UTF-16LE
        [for (final c in s.codeUnits) ...[c >> 8, c & 0xff]], // UTF-16BE
      ];

  void expectAbsent(Map<String, List<int>> files, String secret, String what) {
    for (final f in files.entries) {
      for (final e in encodings(secret)) {
        expect(indexOf(f.value, e), -1, reason: '$what found in ${f.key.split('/').last}');
      }
    }
  }

  bool plaintextHeader(List<int> bytes) =>
      bytes.length >= 16 && String.fromCharCodes(bytes.sublist(0, 16)) == 'SQLite format 3\u0000';

  Future<int> count(DatabaseExecutor db, String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM "$table"')).first['n'] as int;

  // ---- B. SQLCipher ---------------------------------------------------------------------------

  group('B. SQLCipher database', () {
    testWidgets('first open creates key, envelope and schema v2 with SQLCipher 4.20.0', (tester) async {
      final o = await openOk();
      // ignore: avoid_print
      print('SENSE-EVIDENCE cipher_version="${o.cipherVersion}" ${o.security} '
          'productionEligible=${o.productionEligible}');
      expect(o.cipherVersion, startsWith(kExpectedSqlCipherVersion));
      expect(o.firstInitialization, isTrue);
      expect(o.recoveredMissingDatabase, isFalse);
      expect(o.legacyDatabase, LegacyDatabaseState.absent);
      if (o.security.emulator) {
        expect(o.security.hardwareBackedEvidence, isFalse);
        expect(o.productionEligible, isFalse);
      }
      expect(o.databasePath, dbPath);
      expect(dbPath, endsWith('/$kEncryptedDatabaseFileName'));
      expect(dbPath, contains('/no_backup/'));
      expect((await o.database.rawQuery('PRAGMA user_version')).first.values.first, kSchemaVersion);
      for (final t in ['local_profile', 'check_ins', 'consent_events', 'migration_log']) {
        expect(await count(o.database, t), t == 'migration_log' ? 1 : 0, reason: t);
      }
      final status = (await provider.inspect())!;
      expect([status.databasePresent, status.envelopePresent, status.keyAliasPresent], [true, true, true]);
      expect(await File(status.envelopePath).length(), 70);
      expect(status.envelopePath, endsWith('/$kDatabaseKeyEnvelopeFileName'));
    });

    testWidgets('PRAGMA integrity_check and cipher_integrity_check succeed', (tester) async {
      final db = (await openOk()).database;
      await LocalDataStore(db).profiles.ensureActive();
      expect((await db.rawQuery('PRAGMA integrity_check')).first.values.first, 'ok');
      expect(await db.rawQuery('PRAGMA cipher_integrity_check'), isEmpty);
      final kdf = (await db.rawQuery('PRAGMA kdf_iter')).first.values.first;
      final provider_ = (await db.rawQuery('PRAGMA cipher_provider')).first.values.first;
      final mode = (await db.rawQuery('PRAGMA journal_mode')).first.values.first;
      // ignore: avoid_print
      print('SENSE-EVIDENCE kdf_iter=$kdf cipher_provider=$provider_ journal_mode=$mode');
    });

    testWidgets('a wrong passphrase cannot read the database, which is neither deleted nor modified', (tester) async {
      final o = await openOk();
      final person = (await LocalDataStore(o.database).profiles.ensureActive()).localPersonId;
      await o.database.close();
      final before = await sha(dbPath);

      for (final wrong in [hexOf(32), '']) {
        await expectLater(
          platform.openEncrypted(dbPath, wrong, SenseDatabase.options()),
          throwsA(isA<DatabaseException>()),
          reason: wrong.isEmpty ? 'empty key' : 'random key',
        );
        expect(await File(dbPath).exists(), isTrue, reason: 'a wrong key must never delete the database');
        expect(await sha(dbPath), before, reason: 'a wrong key must never modify the database');
      }
      final again = await openOk();
      expect(again.firstInitialization, isFalse);
      expect((await LocalDataStore(again.database).profiles.active())!.localPersonId, person);
    });

    testWidgets('the passphrase is used exactly as given (UTF-8 passphrase, not a raw key)', (tester) async {
      await withRawKey((pass) async {
        final db = await platform.openEncrypted(dbPath, pass, SenseDatabase.options());
        await db.close();
        for (final variant in [pass.toUpperCase(), "x'$pass'", '$pass ', pass.substring(1)]) {
          await expectLater(platform.openEncrypted(dbPath, variant, SenseDatabase.options()),
              throwsA(isA<DatabaseException>()));
        }
        final ok = await platform.openEncrypted(dbPath, pass, SenseDatabase.options());
        expect(await EncryptedDatabaseProvider.cipherVersionOf(ok), startsWith(kExpectedSqlCipherVersion));
        await ok.close();
      });
    });

    testWidgets('the database survives close and reopening by a new provider', (tester) async {
      final sentinel = 'SENSE-REOPEN-${hexOf(8)}';
      final db = (await openOk()).database;
      await db.execute('CREATE TABLE probe (v TEXT NOT NULL)');
      await db.insert('probe', {'v': sentinel});
      await db.close();

      final reopened = await EncryptedDatabaseProvider(testNamespace: ns).open() as EncryptedDatabaseOpened;
      toClose.add(reopened.database);
      expect(reopened.firstInitialization, isFalse);
      expect((await reopened.database.query('probe')).single['v'], sentinel);
    });

    testWidgets('schema v1 -> v2 migration runs over SQLCipher and preserves legacy rows', (tester) async {
      // Create the key, then a v1-shaped encrypted database with it.
      final v1 = await withRawKey((pass) => platform.openEncrypted(
        dbPath,
        pass,
        OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE check_ins (id INTEGER PRIMARY KEY, mood_valence REAL)');
            await db.execute('CREATE TABLE consent_settings (modality TEXT, is_consented INTEGER)');
            await db.insert('check_ins', {'mood_valence': 0.5});
            await db.insert('consent_settings', {'modality': 'M1', 'is_consented': 1});
          },
        ),
      ));
      await v1.close();

      final o = await openOk();
      expect(o.firstInitialization, isFalse);
      final db = o.database;
      expect((await db.rawQuery('PRAGMA user_version')).first.values.first, 2);
      expect(await count(db, 'legacy_v1_check_ins'), 1);
      expect(await count(db, 'legacy_v1_consent_settings'), 1);
      expect(await count(db, 'check_ins'), 0);
      expect(await count(db, 'consent_events'), 0, reason: 'legacy consent is never read; preferences start OFF');
      final log = await db.query('migration_log', orderBy: 'id');
      expect(log.single['from_version'], 1);
      expect(log.single['to_version'], 2);
      expect((await db.rawQuery('PRAGMA integrity_check')).first.values.first, 'ok');
    });

    testWidgets('transactions, consent-gated writes, export and erase behave as on plain SQLite', (tester) async {
      final db = (await openOk()).database;
      final store = LocalDataStore(db);
      final person = (await store.profiles.ensureActive()).localPersonId;
      const day = LocalDay('2026-11-09', 330);
      final submitted = DateTime.utc(2026, 11, 9, 8);
      CheckInEntry checkIn() => CheckInEntry(
          moodRating: 3,
          motivationEnergyRating: 3,
          perceivedStressRating: 2,
          day: day,
          provenance: Provenance.fromChanged(allFields: CheckInEntry.allFields, changed: const {}, submittedAtUtc: submitted));
      SleepEntry sleep() => SleepEntry(
          durationMinutes: 450,
          bedtimeLocal: '23:30',
          wakeTimeLocal: '07:00',
          restQuality: 4,
          day: day,
          provenance: Provenance.fromChanged(allFields: SleepEntry.allFields, changed: const {}, submittedAtUtc: submitted));

      // Default OFF: the write is refused and nothing is stored.
      await expectLater(store.checkIns.upsert(person, checkIn()),
          throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.notRecorded)));
      expect(await count(db, 'check_ins'), 0);

      // Consent and record in one transaction: committed together.
      await LocalDataStore.transaction(db, (s) async {
        await s.consent.recordChange(person, 'M1', true);
        await s.checkIns.upsert(person, checkIn());
      });
      expect(await count(db, 'check_ins'), 1);

      // A failing transaction rolls back both the consent change and the write.
      await expectLater(
        LocalDataStore.transaction(db, (s) async {
          await s.consent.recordChange(person, 'M3', true);
          await s.sleep.upsert(person, sleep());
          throw StateError('abort');
        }),
        throwsStateError,
      );
      expect(await count(db, 'sleep_records'), 0);
      expect(await store.consent.isEnabled(person, 'M3'), isFalse);

      // Append-only history; turning M1 off blocks the next write.
      await store.consent.recordChange(person, 'M1', false);
      await expectLater(store.checkIns.upsert(person, checkIn()),
          throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.disabled)));
      expect((await store.consent.history(person, modality: 'M1')).length, 2);

      // Export and erase over the encrypted database.
      final service = LocalDataService(db);
      final export = await service.exportAllUserData();
      expect(jsonEncode(export), contains(person));
      final erased = await service.eraseAllUserData();
      expect(erased.deletedRows['check_ins'], 1);
      expect(await count(db, 'check_ins'), 0);
      expect(await count(db, 'consent_events'), 0);
      // Existing erase contract: a fresh local identity, all preferences OFF.
      expect(erased.previousLocalPersonIds, [person]);
      final fresh = (await db.query('local_profile')).single['local_person_id'];
      expect(fresh, erased.newLocalPersonId);
      expect(fresh, isNot(person));
      expect((await store.consent.currentPreferences(fresh as String)).values, everyElement(isFalse));
      expect(await count(db, 'migration_log'), 1);
    });

    testWidgets('a plaintext SQLite file at the encrypted path is refused unchanged; no key is created', (tester) async {
      await Directory(storageDir).create(recursive: true);
      final p = await plain.databaseFactory.openDatabase(dbPath);
      await p.execute('CREATE TABLE t (v TEXT)');
      await p.insert('t', {'v': 'plaintext'});
      await p.close();
      final before = await sha(dbPath);

      final r = await provider.open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.plaintextDatabaseAtEncryptedPath);
      expect(await sha(dbPath), before);
      final s = (await provider.inspect())!;
      expect(s.envelopePresent, isFalse);
      expect(s.keyAliasPresent, isFalse);
    });

    testWidgets('the SQLCipher driver does not accept a plaintext database and leaves it unchanged', (tester) async {
      await Directory(storageDir).create(recursive: true);
      final probe = '$storageDir/plaintext_probe.db';
      final p = await plain.databaseFactory.openDatabase(probe);
      await p.execute('CREATE TABLE t (v TEXT)');
      await p.insert('t', {'v': 'plaintext'});
      await p.close();
      final before = await sha(probe);
      // The driver's own fallback tries PRAGMA cipher_migrate on any failed
      // open; it must fail without rewriting the plaintext file.
      await expectLater(platform.openEncrypted(probe, hexOf(32), OpenDatabaseOptions()), throwsA(isA<DatabaseException>()));
      expect(await sha(probe), before);
      expect(plaintextHeader(await File(probe).readAsBytes()), isTrue);
      await plain.databaseFactory.deleteDatabase(probe);
    });

    testWidgets('a legacy plaintext database is detected, preserved byte-for-byte and not migrated', (tester) async {
      const legacySentinel = 'SENSE-LEGACY-PLAINTEXT-ROW';
      await Directory(File(legacyPath).parent.path).create(recursive: true);
      final legacy = await plain.databaseFactory.openDatabase(legacyPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, v) async {
              await db.execute('CREATE TABLE journal_entries (id INTEGER PRIMARY KEY, raw_text_encrypted TEXT)');
              await db.insert('journal_entries', {'raw_text_encrypted': legacySentinel});
            },
          ));
      await legacy.close();
      final before = await sha(legacyPath);
      final modified = await File(legacyPath).lastModified();

      final o = await openOk();
      expect(o.legacyDatabase, LegacyDatabaseState.plaintextSqlite);
      expect((await provider.inspect())!.legacyDatabase, LegacyDatabaseState.plaintextSqlite);
      final tables = (await o.database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((r) => r['name']);
      expect(tables.where((t) => '$t'.startsWith('legacy_v1_')), isEmpty);
      await o.database.close();
      expectAbsent(await filesOf(dbPath), legacySentinel, 'legacy row');

      expect(await sha(legacyPath), before);
      expect(await File(legacyPath).lastModified(), modified);
      expect(plaintextHeader(await File(legacyPath).readAsBytes()), isTrue);
    });
  });

  // ---- C. On-disk encryption ------------------------------------------------------------------

  group('C. On-disk encryption', () {
    for (final wal in [false, true]) {
      testWidgets('a raw sentinel never reaches disk in plaintext (${wal ? 'WAL' : 'default journal'} mode)',
          (tester) async {
        final sentinel = 'SENSE-SENTINEL-${hexOf(12)}';
        final pass = await withRawKey((pass) async {
          await platform.openEncrypted(dbPath, pass, SenseDatabase.options()).then((d) => d.close());
          return pass;
        });

        final o = await openOk();
        final db = o.database;
        if (wal) {
          expect((await db.rawQuery('PRAGMA journal_mode=WAL')).first.values.first, 'wal');
        }
        await db.execute('CREATE TABLE probe (v TEXT NOT NULL)');
        await db.transaction((t) => t.insert('probe', {'v': sentinel}));

        // Committed but still open (in WAL mode the row is only in the -wal file).
        var files = await filesOf(dbPath);
        if (wal) expect(files.keys.any((k) => k.endsWith('-wal')), isTrue);
        expectAbsent(files, sentinel, 'sentinel (open)');

        if (wal) {
          await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        }
        await db.close();
        files = await filesOf(dbPath);
        // ignore: avoid_print
        print('SENSE-EVIDENCE wal=$wal files=${files.map((k, v) => MapEntry(k.split('/').last, v.length))}');
        expect(plaintextHeader(files[dbPath]!), isFalse, reason: 'main file has the plaintext SQLite header');
        expectAbsent(files, sentinel, 'sentinel (closed)');
        expectAbsent(files, pass, 'passphrase');

        // The correct key reads it back; a wrong key cannot.
        final again = await openOk();
        expect((await again.database.query('probe')).single['v'], sentinel);
        await again.database.close();
        await expectLater(platform.openEncrypted(dbPath, hexOf(32), SenseDatabase.options()),
            throwsA(isA<DatabaseException>()));
      });
    }
  });

  // ---- Key destruction --------------------------------------------------------------------------

  group('Key destruction', () {
    testWidgets('refuses while open, then erases key, envelope and files; a retained copy cannot be reopened',
        (tester) async {
      final o = await openOk();
      await o.database.execute('CREATE TABLE probe (v TEXT)');
      await o.database.insert('probe', {'v': 'before destroy'});
      await expectLater(provider.destroyKeyAndDatabase(), throwsStateError);
      expect((await provider.inspect())!.keyAliasPresent, isTrue);

      await o.database.close();
      final retained = await File(dbPath).readAsBytes(); // e.g. bytes left on the medium
      final report = await provider.destroyKeyAndDatabase();
      expect(report.cryptographicallyErased, isTrue);
      expect(report.databaseFilesRemaining, isEmpty);
      expect(report.databaseFilesDeleted, contains(kEncryptedDatabaseFileName));
      final s = (await provider.inspect())!;
      expect([s.databasePresent, s.envelopePresent, s.keyAliasPresent], [false, false, false]);

      // The retained ciphertext has no key that could open it: fail closed.
      await File(dbPath).writeAsBytes(retained);
      final r = await provider.open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.keyAndEnvelopeMissingForExistingDatabase);
      expect((await provider.inspect())!.keyAliasPresent, isFalse, reason: 'no key may be generated for it');
      await File(dbPath).delete();

      // A fresh database gets a new key that cannot open the retained copy.
      final fresh = await openOk();
      expect(fresh.firstInitialization, isTrue);
      await fresh.database.close();
      final freshKey = await withRawKey((pass) async => pass);
      final copy = '$storageDir/retained_copy.db';
      await File(copy).writeAsBytes(retained);
      await expectLater(platform.openEncrypted(copy, freshKey, OpenDatabaseOptions()), throwsA(isA<DatabaseException>()));
      await File(copy).delete();
    });
  });

  // ---- Logs ---------------------------------------------------------------------------------------

  group('Logs', () {
    testWidgets('neither the passphrase nor a stored sentinel appears in the app log', (tester) async {
      final sentinel = 'SENSE-LOG-SENTINEL-${hexOf(10)}';
      final pass = await withRawKey((pass) async => pass);
      final o = await openOk();
      await o.database.execute('CREATE TABLE probe (v TEXT)');
      await o.database.insert('probe', {'v': sentinel});
      await o.database.query('probe');
      await o.database.close();
      await platform.openEncrypted(dbPath, hexOf(32), SenseDatabase.options()).then((d) => d.close(), onError: (_) {});
      final log = await Process.run('logcat', ['-d', '-v', 'raw']);
      final text = '${log.stdout}';
      expect(text, isNotEmpty);
      expect(text.contains(pass), isFalse, reason: 'passphrase in logcat');
      expect(text.contains(pass.toUpperCase()), isFalse);
      expect(text.contains(sentinel), isFalse, reason: 'sentinel in logcat');
    });
  });

  // ---- D. Hardening (M1, M2, L1, L3) ------------------------------------------------------------

  group('D. Hardening', () {
    testWidgets('M2: this debug build cannot open the participant database (Dart and native)', (tester) async {
      final participant = EncryptedDatabaseProvider();
      expect(participant.buildMode, BuildMode.debug);
      final before = await platform.inspect();
      expect([before['envelopePresent'], before['keyAliasPresent'], before['setupPending']], [false, false, false],
          reason: 'the debug test app must not hold participant key material');

      final r = await participant.open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.buildNotProductionEligible);
      // The native gate refuses too, independently of the Dart check.
      final native = await platform.openKey();
      expect(native['status'], 'failed');
      expect(native['failure'], 'buildNotProductionEligible');
      expect(native.containsKey('passphrase'), isFalse);
      expect(native['buildKind'], 'debug');
      await expectLater(participant.destroyKeyAndDatabase(), throwsA(isA<EncryptedDatabaseLifecycleError>()));

      final after = await platform.inspect();
      expect([after['databasePresent'], after['envelopePresent'], after['keyAliasPresent'], after['setupPending']],
          [false, false, false, false]);
      expect(after['lifecycle'], 'idle');
    });

    testWidgets('M1: destroy during an open, through a second provider and natively, is refused', (tester) async {
      final opening = provider.open();
      final destroying = provider.destroyKeyAndDatabase();
      final o = await opening;
      expect(o, isA<EncryptedDatabaseOpened>(), reason: '$o');
      toClose.add((o as EncryptedDatabaseOpened).database);
      await expectLater(destroying,
          throwsA(isA<EncryptedDatabaseLifecycleError>().having((e) => e.reason, 'reason', LifecycleRefusal.databaseOpen)));
      await expectLater(EncryptedDatabaseProvider(testNamespace: ns).destroyKeyAndDatabase(),
          throwsA(isA<EncryptedDatabaseLifecycleError>()));

      // The native registry refuses on its own (another engine would see this).
      final nativeDestroy = await platform.destroy(testNamespace: ns);
      expect(nativeDestroy['status'], 'busy');
      expect(nativeDestroy['busyReason'], 'databaseOpen');
      final nativeOpen = await platform.openKey(testNamespace: ns);
      expect(nativeOpen['failure'], 'lifecycleBusy');
      expect(nativeOpen.containsKey('passphrase'), isFalse);

      final s = (await provider.inspect())!;
      expect(s.lifecycle, 'open');
      expect([s.databasePresent, s.envelopePresent, s.keyAliasPresent], [true, true, true],
          reason: 'the key and envelope of a live connection are never deleted');
      // The registered connection is unaffected by the refused attempts.
      expect((await o.database.rawQuery('SELECT COUNT(*) AS n FROM migration_log')).first['n'], 1);
    });

    testWidgets('M1: simultaneous opens yield one connection; close is repeatable; open right after destroy', (tester) async {
      final results = await Future.wait([provider.open(), EncryptedDatabaseProvider(testNamespace: ns).open()]);
      final opened = results.whereType<EncryptedDatabaseOpened>().toList();
      expect(opened, hasLength(1));
      toClose.add(opened.single.database);
      expect(results.whereType<EncryptedDatabaseFailed>().single.code, EncryptedDatabaseFailureCode.databaseAlreadyOpen);

      await provider.close();
      await provider.close();
      await EncryptedDatabaseProvider(testNamespace: ns).close();
      expect((await provider.inspect())!.lifecycle, 'idle');

      expect((await provider.destroyKeyAndDatabase()).cryptographicallyErased, isTrue);
      final again = await openOk();
      expect(again.firstInitialization, isTrue);
    });

    testWidgets('M1: a failed open releases its lease', (tester) async {
      await Directory(storageDir).create(recursive: true);
      final p = await plain.databaseFactory.openDatabase(dbPath);
      await p.close();
      // Native refuses (plaintext header) before a lease survives.
      expect(((await provider.open()) as EncryptedDatabaseFailed).code,
          anyOf(EncryptedDatabaseFailureCode.plaintextDatabaseAtEncryptedPath, EncryptedDatabaseFailureCode.storageError));
      expect((await provider.inspect())!.lifecycle, 'idle');
      await plain.databaseFactory.deleteDatabase(dbPath);
      await openOk();
      expect((await provider.inspect())!.lifecycle, 'open');
    });

    testWidgets('L3: killed during initial database creation, the next open completes the same setup', (tester) async {
      // Take the key, then fail half-way through schema creation (the open
      // transaction rolls back; the file stays), without committing the setup.
      final key = await platform.openKey(testNamespace: ns);
      final lease = key['leaseId'] as String;
      await expectLater(
        platform.openEncrypted(
          dbPath,
          key['passphrase'] as String,
          OpenDatabaseOptions(
            version: kSchemaVersion,
            onCreate: (db, v) async {
              await db.execute('CREATE TABLE half_created (x TEXT)');
              throw StateError('process killed mid-creation');
            },
          ),
        ),
        throwsStateError,
      );
      await platform.release(lease, testNamespace: ns);
      final pending = (await provider.inspect())!;
      expect(pending.setupPending, isTrue);
      expect(pending.keyAliasPresent && pending.envelopePresent, isTrue);

      final o = await openOk();
      expect(o.firstInitialization, isTrue, reason: 'the interrupted first initialization continues');
      expect(o.recoveredMissingDatabase, isFalse);
      expect((await o.database.rawQuery('PRAGMA user_version')).first.values.first, kSchemaVersion);
      final tables = (await o.database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((r) => r['name']);
      expect(tables, isNot(contains('half_created')));
      expect(tables, contains('consent_events'));
      expect((await provider.inspect())!.setupPending, isFalse, reason: 'cleared by the commit');
    });

    testWidgets('L3: an empty database file left by a kill is created with the existing key', (tester) async {
      final key = await platform.openKey(testNamespace: ns);
      await File(dbPath).writeAsBytes(const []);
      await platform.release(key['leaseId'] as String, testNamespace: ns);
      final o = await openOk();
      expect(o.firstInitialization, isTrue);
      expect((await o.database.rawQuery('PRAGMA integrity_check')).first.values.first, 'ok');
      expect(plaintextHeader(await File(dbPath).readAsBytes()), isFalse);
    });

    testWidgets('L1: failed opens (wrong key, plaintext file) leave no new or changed files', (tester) async {
      final o = await openOk();
      await o.database.close();
      await provider.close();
      final probe = '$storageDir/plaintext_probe.db';
      final p = await plain.databaseFactory.openDatabase(probe);
      await p.execute('CREATE TABLE t (v TEXT)');
      await p.close();

      Future<Map<String, String>> snapshot() async => {
            for (final f in Directory(storageDir).listSync(recursive: true).whereType<File>())
              f.path: await sha(f.path),
          };
      final before = await snapshot();
      await expectLater(platform.openEncrypted(dbPath, hexOf(32), OpenDatabaseOptions()), throwsA(isA<DatabaseException>()));
      await expectLater(platform.openEncrypted(probe, hexOf(32), OpenDatabaseOptions()), throwsA(isA<DatabaseException>()));
      final after = await snapshot();
      // ignore: avoid_print
      print('SENSE-EVIDENCE L1 files before=${before.keys.map((k) => k.split('/').last).toList()} '
          'after=${after.keys.map((k) => k.split('/').last).toList()}');
      expect(after, before, reason: 'cipher_migrate retries must not create, alter or remove files');
      expect(after.keys.where((k) => k.contains('migrat')), isEmpty);
      await plain.databaseFactory.deleteDatabase(probe);
    });
  });
}
