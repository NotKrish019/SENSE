import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/dart_source_guard.dart';

/// Milestone J: the Dart side of the encrypted-database provider, on the host
/// VM with a fake native platform. The real Keystore, lifecycle registry and
/// SQLCipher run on a device (android/app/src/androidTest and
/// integration_test/).
///
/// The "engine" used here is plain SQLite (sqflite_common_ffi). That is
/// deliberate: it proves the provider refuses a non-SQLCipher engine.
///
/// Host tests run in debug mode, so the existing behaviour is exercised
/// through a debug test namespace; the participant database is exercised with
/// an injected build mode (hardening M2).
void main() {
  sqfliteFfiInit();

  late Directory dir;
  late String dbPath;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sense_encrypted_provider_');
    dbPath = '${dir.path}/$kEncryptedDatabaseFileName';
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final validPassphrase = List.generate(64, (i) => '0123456789abcdef'[(i * 7) % 16]).join();
  const lease = '0123456789abcdef0123456789abcdef';
  const ns = 'host_test';

  Map<String, Object?> ready({String? passphrase, String? path}) => {
        'status': 'ready',
        'passphrase': passphrase ?? validPassphrase,
        'leaseId': lease,
        'databasePath': path ?? dbPath,
        'securityLevel': 'software',
        'emulator': true,
        'hardwareBackedEvidence': false,
        'productionEligible': false,
        'firstInitialization': true,
        'recoveredMissingDatabase': false,
        'legacyDatabase': 'absent',
      };

  Map<String, Object?> hardwareReady({String level = 'trustedEnvironment'}) => ready()
    ..['securityLevel'] = level
    ..['emulator'] = false
    ..['hardwareBackedEvidence'] = true
    ..['productionEligible'] = true;

  EncryptedDatabaseProvider testNs(SecureKeyPlatform p) => EncryptedDatabaseProvider(platform: p, testNamespace: ns);

  Future<Database> memoryDb() => databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

  group('Platform support', () {
    test('the default platform on the host VM is unsupported and never falls back to plaintext', () async {
      final provider = EncryptedDatabaseProvider();
      expect(provider.isSupported, isFalse);
      final r = await provider.open();
      expect(r, isA<EncryptedDatabaseFailed>().having((f) => f.code, 'code', EncryptedDatabaseFailureCode.unsupportedPlatform));
      expect(await provider.inspect(), isNull);
      expect(Directory(dir.path).listSync(), isEmpty);
    });

    test('an unsupported platform is never asked for a key or a database', () async {
      final fake = _FakePlatform(supported: false);
      final r = await EncryptedDatabaseProvider(platform: fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.unsupportedPlatform);
      expect(fake.calls, isEmpty);
    });
  });

  group('Native failures fail closed', () {
    const wire = {
      'envelopeMissingForExistingDatabase': EncryptedDatabaseFailureCode.envelopeMissingForExistingDatabase,
      'keyMissingForExistingDatabase': EncryptedDatabaseFailureCode.keyMissingForExistingDatabase,
      'keyAndEnvelopeMissingForExistingDatabase': EncryptedDatabaseFailureCode.keyAndEnvelopeMissingForExistingDatabase,
      'envelopeWithoutKey': EncryptedDatabaseFailureCode.envelopeWithoutKey,
      'orphanedKey': EncryptedDatabaseFailureCode.orphanedKey,
      'envelopeMalformed': EncryptedDatabaseFailureCode.envelopeMalformed,
      'envelopeAuthenticationFailed': EncryptedDatabaseFailureCode.envelopeAuthenticationFailed,
      'insecureKeyStorage': EncryptedDatabaseFailureCode.insecureKeyStorage,
      'plaintextDatabaseAtEncryptedPath': EncryptedDatabaseFailureCode.plaintextDatabaseAtEncryptedPath,
      'keystoreError': EncryptedDatabaseFailureCode.keystoreError,
      'initializationFailed': EncryptedDatabaseFailureCode.initializationFailed,
      'buildNotProductionEligible': EncryptedDatabaseFailureCode.buildNotProductionEligible,
      'lifecycleBusy': EncryptedDatabaseFailureCode.lifecycleBusy,
      'somethingNew': EncryptedDatabaseFailureCode.keystoreError,
    };
    for (final entry in wire.entries) {
      test('${entry.key} -> ${entry.value.name}, without opening or destroying anything', () async {
        final fake = _FakePlatform(openKeyReply: {
          'status': 'failed',
          'failure': entry.key,
          'legacyDatabase': 'plaintextSqlite',
        });
        final r = await testNs(fake).open();
        expect(r, isA<EncryptedDatabaseFailed>());
        r as EncryptedDatabaseFailed;
        expect(r.code, entry.value);
        expect(r.legacyDatabase, LegacyDatabaseState.plaintextSqlite);
        // A failed native reply holds no lease: nothing to release.
        expect(fake.calls, ['openKey']);
      });
    }

    test('a channel exception is a platform error', () async {
      final fake = _FakePlatform(openKeyThrows: () => Exception('channel failure'));
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.platformError);
    });
  });

  group('Key material and path validation', () {
    final bad = <String, Object?>{
      'empty passphrase (would mean an UNENCRYPTED SQLCipher database)': '',
      'too short': validPassphrase.substring(0, 63),
      'too long': '${validPassphrase}0',
      'uppercase hex': validPassphrase.toUpperCase(),
      'not hex': 'z' * 64,
      'not a string': 12345,
      'missing': null,
    };
    for (final entry in bad.entries) {
      test('rejects ${entry.key} before any database is opened, and releases the lease', () async {
        final reply = ready()..['passphrase'] = entry.value;
        final fake = _FakePlatform(openKeyReply: reply);
        final r = await testNs(fake).open();
        expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.invalidKeyMaterial);
        expect(fake.calls, isNot(contains('openEncrypted')));
        expect(fake.calls, ['openKey', 'release']);
      });
    }

    test('refuses the legacy file name or any unexpected path', () async {
      for (final path in ['${dir.path}/$kLocalDatabaseFileName', '${dir.path}/other.db', '', 'sense_encrypted_v1.db.bak']) {
        final fake = _FakePlatform(openKeyReply: ready(path: path));
        final r = await testNs(fake).open();
        expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.invalidKeyMaterial, reason: path);
        expect(fake.calls, isNot(contains('openEncrypted')));
      }
    });
  });

  group('Plaintext protection', () {
    test('a plaintext SQLite file at the encrypted path is refused and left byte-for-byte unchanged', () async {
      final plain = await databaseFactoryFfi.openDatabase(dbPath);
      await plain.execute('CREATE TABLE t (v TEXT)');
      await plain.insert('t', {'v': 'plaintext row'});
      await plain.close();
      final before = await File(dbPath).readAsBytes();

      final fake = _FakePlatform(openKeyReply: ready(), opener: _ffiOpener);
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.plaintextDatabaseAtEncryptedPath);
      expect(fake.calls, isNot(contains('openEncrypted')));
      expect(await File(dbPath).readAsBytes(), before);
    });

    test('an engine that is not SQLCipher is detected and its connection closed', () async {
      final fake = _FakePlatform(openKeyReply: ready(), opener: _ffiOpener);
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.notEncrypted);
      expect(fake.openedDatabases.single.isOpen, isFalse);
      expect(fake.calls.last, 'release');
    });

    test('"file is not a database" is a rejected key, never a reason to initialize', () async {
      final random = Random.secure();
      await File(dbPath).writeAsBytes(List.generate(8192, (_) => random.nextInt(256)));
      final before = await File(dbPath).readAsBytes();
      final fake = _FakePlatform(openKeyReply: ready()..['firstInitialization'] = false, opener: _ffiOpener);
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.databaseKeyRejected);
      expect(fake.calls, ['openKey', 'header', 'openEncrypted', 'release']);
      expect(await File(dbPath).readAsBytes(), before);
    });

    test('any other open error is databaseOpenFailed', () async {
      final fake = _FakePlatform(
          openKeyReply: ready(), opener: (path, pass, options) async => throw const FileSystemException('denied'));
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.databaseOpenFailed);
    });
  });

  group('Destruction', () {
    test('refuses while a database opened by the provider is still open', () async {
      final db = await memoryDb();
      final fake = _FakePlatform(
        openKeyReply: ready(),
        opener: (path, pass, options) async => db,
        cipherVersionOverride: true,
      );
      final provider = testNs(fake);
      final r = await provider.open();
      expect(r, isA<EncryptedDatabaseOpened>());
      await expectLater(provider.destroyKeyAndDatabase(), throwsStateError);
      expect(fake.calls, isNot(contains('destroy')));
      await db.close();
      final report = await provider.destroyKeyAndDatabase();
      expect(fake.calls.sublist(fake.calls.length - 2), ['release', 'destroy']);
      expect(report.cryptographicallyErased, isTrue);
    });

    test('is unsupported where encrypted storage is unsupported', () async {
      expect(EncryptedDatabaseProvider(platform: _FakePlatform(supported: false)).destroyKeyAndDatabase(),
          throwsUnsupportedError);
    });
  });

  group('No key material in results', () {
    test('toString of every result type omits the passphrase', () async {
      final db = await memoryDb();
      final fake = _FakePlatform(
          openKeyReply: ready(), opener: (path, pass, options) async => db, cipherVersionOverride: true);
      final opened = await testNs(fake).open();
      final failed = await testNs(_FakePlatform(openKeyReply: {'status': 'failed', 'failure': 'orphanedKey'})).open();
      for (final s in [opened.toString(), failed.toString()]) {
        expect(s, isNot(contains(validPassphrase)));
        expect(s, isNot(contains(validPassphrase.substring(0, 16))));
        expect(s, isNot(contains(lease)));
      }
      await db.close();
    });
  });

  test('SenseDatabase.options carries the schema version used by open()', () {
    expect(SenseDatabase.options().version, kSchemaVersion);
    expect(SenseDatabase.options().onCreate, isNotNull);
    expect(SenseDatabase.options().onUpgrade, isNotNull);
  });

  // ---- Hardening M2: explicit production eligibility ------------------------------------------

  group('Build-mode policy (M2)', () {
    EncryptedDatabaseProvider participant(SecureKeyPlatform p, BuildMode mode) =>
        EncryptedDatabaseProvider(platform: p, buildMode: mode);

    test('this host test runs in debug mode', () {
      expect(currentBuildMode, BuildMode.debug);
      expect(EncryptedDatabaseProvider(platform: _FakePlatform()).buildMode, BuildMode.debug);
    });

    for (final mode in [BuildMode.debug, BuildMode.profile]) {
      test('${mode.name} builds cannot open the participant database, even with a hardware key', () async {
        final fake = _FakePlatform(openKeyReply: hardwareReady());
        final r = await participant(fake, mode).open();
        expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.buildNotProductionEligible);
        expect(r.refusal, LifecycleRefusal.buildNotProductionEligible);
        expect(fake.calls, isEmpty, reason: 'refused before any native call');
        await expectLater(participant(fake, mode).destroyKeyAndDatabase(),
            throwsA(isA<EncryptedDatabaseLifecycleError>().having((e) => e.reason, 'reason', LifecycleRefusal.buildNotProductionEligible)));
      });
    }

    for (final mode in [BuildMode.profile, BuildMode.release]) {
      test('test namespaces are unavailable in ${mode.name} builds', () async {
        final fake = _FakePlatform(openKeyReply: ready());
        final r = await EncryptedDatabaseProvider(platform: fake, testNamespace: ns, buildMode: mode).open();
        expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.testNamespaceUnavailable);
        expect(fake.calls, isEmpty);
      });
    }

    for (final level in ['trustedEnvironment', 'strongBox', 'hardwareUnspecified']) {
      test('release with $level metadata opens and is production eligible', () async {
        final db = await memoryDb();
        final fake = _FakePlatform(openKeyReply: hardwareReady(level: level), opener: (p, k, o) async => db, cipherVersionOverride: true);
        final r = await participant(fake, BuildMode.release).open();
        expect(r, isA<EncryptedDatabaseOpened>(), reason: '$r');
        expect((r as EncryptedDatabaseOpened).productionEligible, isTrue);
        expect(fake.calls, ['openKey', 'header', 'openEncrypted', 'header', 'commitOpen']);
        await db.close();
      });
    }

    final rejected = <String, Map<String, Object?> Function()>{
      'SOFTWARE': () => hardwareReady()
        ..['securityLevel'] = 'software'
        ..['hardwareBackedEvidence'] = false,
      'UNKNOWN': () => hardwareReady()
        ..['securityLevel'] = 'unknown'
        ..['hardwareBackedEvidence'] = false,
      'an unrecognised level string': () => hardwareReady()..['securityLevel'] = 'quantum',
      'an emulator reporting TEE': () => hardwareReady()..['emulator'] = true,
      'a reply that is not production eligible': () => hardwareReady()..['productionEligible'] = false,
      'eligible but without hardware evidence': () => hardwareReady()..['hardwareBackedEvidence'] = false,
      'a successful key operation alone (no security facts)': () => hardwareReady()..remove('securityLevel'),
    };
    for (final entry in rejected.entries) {
      test('release rejects ${entry.key} before opening any database', () async {
        final fake = _FakePlatform(openKeyReply: entry.value(), opener: _ffiOpener);
        final r = await participant(fake, BuildMode.release).open();
        expect(r, isA<EncryptedDatabaseFailed>());
        expect((r as EncryptedDatabaseFailed).code,
            anyOf(EncryptedDatabaseFailureCode.insecureKeyStorage, EncryptedDatabaseFailureCode.invalidKeyMaterial));
        expect(fake.calls, isNot(contains('openEncrypted')));
        expect(fake.calls.last, 'release');
      });
    }

    test('a cached connection cannot bypass the gate', () async {
      final db = await memoryDb();
      final fake = _FakePlatform(openKeyReply: hardwareReady(), opener: (p, k, o) async => db, cipherVersionOverride: true);
      final provider = participant(fake, BuildMode.release);
      expect(await provider.open(), isA<EncryptedDatabaseOpened>());
      // While open, no second handle is ever returned (no gate-free reuse).
      final again = await participant(fake, BuildMode.release).open();
      expect((again as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.databaseAlreadyOpen);
      expect(fake.calls.where((c) => c == 'openKey'), hasLength(1));
      // After closing, the native gate decides again: a now-software key is refused.
      await provider.close();
      fake.openKeyReply = hardwareReady()
        ..['securityLevel'] = 'software'
        ..['hardwareBackedEvidence'] = false
        ..['productionEligible'] = false;
      final third = await provider.open();
      expect((third as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.insecureKeyStorage);
    });
  });

  // ---- Hardening M1: lifecycle ownership ------------------------------------------------------

  group('Lifecycle owner (M1)', () {
    test('destroy during an open waits for it, then refuses because the database is open', () async {
      final db = await memoryDb();
      final gate = Completer<void>();
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => db, cipherVersionOverride: true, openKeyGate: gate.future);
      final provider = testNs(fake);
      final opening = provider.open();
      final destroying = provider.destroyKeyAndDatabase();
      await pumpEventQueue();
      expect(fake.calls, ['openKey'], reason: 'destroy has not started while the open is in progress');
      gate.complete();
      expect(await opening, isA<EncryptedDatabaseOpened>());
      await expectLater(destroying,
          throwsA(isA<EncryptedDatabaseLifecycleError>().having((e) => e.reason, 'reason', LifecycleRefusal.databaseOpen)));
      expect(fake.calls, isNot(contains('destroy')));
      await db.close();
    });

    test('destroy through a second provider instance is refused while the first holds the database', () async {
      final db = await memoryDb();
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => db, cipherVersionOverride: true);
      final first = testNs(fake);
      expect(await first.open(), isA<EncryptedDatabaseOpened>());
      await expectLater(testNs(fake).destroyKeyAndDatabase(), throwsA(isA<EncryptedDatabaseLifecycleError>()));
      expect(fake.calls, isNot(contains('destroy')));
      await first.close();
      expect((await testNs(fake).destroyKeyAndDatabase()).cryptographicallyErased, isTrue);
    });

    test('simultaneous opens from two providers yield exactly one connection', () async {
      final gate = Completer<void>();
      final dbs = <Database>[];
      final fake = _FakePlatform(
          openKeyReply: ready(),
          opener: (p, k, o) async => (await memoryDb())..also(dbs.add),
          cipherVersionOverride: true,
          openKeyGate: gate.future);
      final a = testNs(fake).open();
      final b = testNs(fake).open();
      gate.complete();
      final results = await Future.wait([a, b]);
      expect(results.whereType<EncryptedDatabaseOpened>(), hasLength(1));
      expect((results.whereType<EncryptedDatabaseFailed>().single).code, EncryptedDatabaseFailureCode.databaseAlreadyOpen);
      expect(fake.calls.where((c) => c == 'openKey'), hasLength(1));
      expect(dbs, hasLength(1));
      for (final d in dbs) {
        await d.close();
      }
    });

    test('a native lifecycle refusal (another engine) is typed and opens nothing', () async {
      final fake = _FakePlatform(openKeyReply: {'status': 'failed', 'failure': 'lifecycleBusy', 'busyReason': 'openInProgress'});
      final r = await testNs(fake).open() as EncryptedDatabaseFailed;
      expect(r.code, EncryptedDatabaseFailureCode.lifecycleBusy);
      expect(r.refusal, LifecycleRefusal.openInProgress);
      expect(fake.calls, ['openKey']);

      fake.destroyReply = {'status': 'busy', 'busyReason': 'orphanedConnection'};
      await expectLater(testNs(fake).destroyKeyAndDatabase(),
          throwsA(isA<EncryptedDatabaseLifecycleError>().having((e) => e.reason, 'reason', LifecycleRefusal.orphanedConnection)));
    });

    test('open immediately after destroy completes', () async {
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => memoryDb(), cipherVersionOverride: true);
      final provider = testNs(fake);
      await provider.destroyKeyAndDatabase();
      final r = await provider.open();
      expect(r, isA<EncryptedDatabaseOpened>());
      await provider.close();
    });

    test('a failed open releases its lease and the next open proceeds', () async {
      final db = await memoryDb();
      var attempt = 0;
      final fake = _FakePlatform(
          openKeyReply: ready(),
          opener: (p, k, o) async => attempt++ == 0 ? throw const FileSystemException('boom') : db,
          cipherVersionOverride: true);
      final provider = testNs(fake);
      final first = await provider.open();
      expect((first as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.databaseOpenFailed);
      expect(fake.calls.last, 'release');
      expect(fake.leaseHeld, isFalse);
      expect(await provider.open(), isA<EncryptedDatabaseOpened>());
      expect(fake.leaseHeld, isTrue);
      await provider.close();
      expect(fake.leaseHeld, isFalse);
    });

    test('repeated close is safe, also after closing the database directly', () async {
      final db = await memoryDb();
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => db, cipherVersionOverride: true);
      final provider = testNs(fake);
      await provider.close(); // nothing open
      expect(await provider.open(), isA<EncryptedDatabaseOpened>());
      await db.close(); // closed directly
      await provider.close();
      await provider.close();
      expect(fake.calls.where((c) => c == 'release'), hasLength(1));
      expect(fake.leaseHeld, isFalse);
    });

    test('a directly closed database is reconciled before the next open', () async {
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => memoryDb(), cipherVersionOverride: true);
      final provider = testNs(fake);
      final o = await provider.open() as EncryptedDatabaseOpened;
      await o.database.close();
      final again = await provider.open() as EncryptedDatabaseOpened;
      expect(fake.calls, ['openKey', 'header', 'openEncrypted', 'header', 'commitOpen', 'release', 'openKey', 'header', 'openEncrypted', 'header', 'commitOpen']);
      await again.database.close();
      await provider.close();
    });

    test('a refused registration closes the connection and releases the lease', () async {
      final db = await memoryDb();
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => db, cipherVersionOverride: true)
        ..commitReply = {'committed': false};
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.lifecycleBusy);
      expect(db.isOpen, isFalse);
      expect(fake.calls.last, 'release');
    });
  });

  // ---- Hardening L5: typed errors and cleanup ---------------------------------------------------

  group('Error normalization (L5)', () {
    test('a StateError from the channel (e.g. a null reply) is a platform error', () async {
      final r = await testNs(_FakePlatform(openKeyThrows: () => StateError('null reply'))).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.platformError);
    });

    final malformed = <String, Map<String, Object?>>{
      'no status': {'failure': 'orphanedKey'},
      'unknown status': {'status': 'maybe'},
      'status of the wrong type': {'status': 1},
      'failure of the wrong type': {'status': 'failed', 'failure': 42},
    };
    for (final entry in malformed.entries) {
      test('a malformed reply (${entry.key}) is typed and opens nothing', () async {
        final fake = _FakePlatform(openKeyReply: entry.value);
        final r = await testNs(fake).open();
        expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.malformedReply, reason: entry.key);
        expect(fake.calls, ['openKey']);
      });
    }

    for (final badLease in [null, '', 'xyz', 42, lease.toUpperCase()]) {
      test('a ready reply with lease id $badLease is malformed and never opens', () async {
        final fake = _FakePlatform(openKeyReply: ready()..['leaseId'] = badLease);
        final r = await testNs(fake).open();
        expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.malformedReply);
        expect(fake.calls, ['openKey']);
      });
    }

    test('a file-system error before opening is a storage error; the lease is released', () async {
      final fake = _FakePlatform(openKeyReply: ready(), headerThrowsOnCall: 1);
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.storageError);
      expect(fake.calls, ['openKey', 'header', 'release']);
    });

    test('a file-system error after opening closes the connection', () async {
      final db = await memoryDb();
      final fake =
          _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => db, cipherVersionOverride: true, headerThrowsOnCall: 2);
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.storageError);
      expect(db.isOpen, isFalse);
      expect(fake.calls.last, 'release');
    });

    test('a failing post-open verification (an Error, not an Exception) closes the connection', () async {
      final inner = await memoryDb();
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => _ThrowingCipherVersionDatabase(inner));
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.notEncrypted);
      expect(inner.isOpen, isFalse);
      expect(fake.calls.last, 'release');
    });

    test('an Error thrown by the SQLCipher opener is a typed open failure', () async {
      final fake = _FakePlatform(openKeyReply: ready(), opener: (p, k, o) async => throw StateError('driver bug'));
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.databaseOpenFailed);
      expect(fake.calls.last, 'release');
    });

    test('a failing lease release during cleanup does not escape', () async {
      final fake = _FakePlatform(openKeyReply: ready()..['passphrase'] = 'short')..releaseThrows = true;
      final r = await testNs(fake).open();
      expect((r as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.invalidKeyMaterial);
    });

    test('inspect and destroy turn channel and reply failures into typed exceptions', () async {
      final throwing = _FakePlatform(inspectReply: null);
      await expectLater(testNs(throwing).inspect(),
          throwsA(isA<EncryptedStoragePlatformException>().having((e) => e.code, 'code', EncryptedDatabaseFailureCode.platformError)));
      await expectLater(testNs(_FakePlatform(inspectReply: {'databasePath': 7})).inspect(),
          throwsA(isA<EncryptedStoragePlatformException>().having((e) => e.code, 'code', EncryptedDatabaseFailureCode.malformedReply)));
      await expectLater(testNs(_FakePlatform()..destroyReply = {'status': 'destroyed'}).destroyKeyAndDatabase(),
          throwsA(isA<EncryptedStoragePlatformException>().having((e) => e.code, 'code', EncryptedDatabaseFailureCode.malformedReply)));
      await expectLater(testNs(_FakePlatform()..destroyThrows = true).destroyKeyAndDatabase(),
          throwsA(isA<EncryptedStoragePlatformException>().having((e) => e.code, 'code', EncryptedDatabaseFailureCode.platformError)));
    });
  });

  // ---- Static guards ----------------------------------------------------------------------------

  group('Static guards', () {
    String read(String p) => File(p).readAsStringSync();
    // Parsed with the Dart analyzer: any quoting, export/part, conditional URIs,
    // and identifiers in code only (test/support/dart_source_guard.dart).
    final lib = parseDartTree('lib');
    const platformIo = 'lib/data/local/encrypted/secure_key_platform_io.dart';

    test('only the Android platform file may import the SQLCipher driver (one connection owner)', () {
      final importers =
          lib.values.where((f) => f.uris.any((u) => u.startsWith('package:sqflite_sqlcipher'))).map((f) => f.path);
      expect(importers, [platformIo]);
      expect(lib[platformIo]!.of(DirectiveKind.export), isEmpty, reason: 'the driver is never re-exported');
      expect(read(platformIo), contains('singleInstance: true'));
      // The platform file is reached only through the conditional import in
      // secure_key_platform.dart (dart.library.io), never directly.
      final dependents = lib.values.where((f) => f.projectDependencies.contains(platformIo)).map((f) => f.path);
      expect(dependents, ['lib/data/local/encrypted/secure_key_platform.dart']);
    });

    test('the provider library never imports dart:io (web builds) and nothing outside encrypted/ uses it', () {
      expect(lib['lib/data/local/encrypted/encrypted_database.dart']!.uris, isNot(contains('dart:io')));
      final users = lib.values
          .where((f) => !f.path.startsWith('lib/data/local/encrypted/'))
          .where((f) => f.identifiers.contains('EncryptedDatabaseProvider'))
          .map((f) => f.path);
      // Milestone K1: the storage owner is the only user (one connection owner).
      expect(users, ['lib/data/local/sense_storage.dart'], reason: 'only SenseStorage may open the encrypted database');
    });
  });
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

typedef _Opener = Future<Database> Function(String path, String passphrase, OpenDatabaseOptions options);

/// Opens with plain SQLite (no SQLCipher): the passphrase is ignored.
Future<Database> _ffiOpener(String path, String passphrase, OpenDatabaseOptions options) =>
    databaseFactoryFfi.openDatabase(path, options: options);

/// A fake native side with a one-lease model of the lifecycle registry.
class _FakePlatform implements SecureKeyPlatform {
  final bool supported;
  Map<String, Object?>? openKeyReply;
  final Object Function()? openKeyThrows;
  final _Opener? opener;
  final Future<void>? openKeyGate;
  final Map<String, Object?>? inspectReply;
  final int? headerThrowsOnCall;
  Map<String, Object?> commitReply = {'committed': true};
  Map<String, Object?> destroyReply = {
    'status': 'destroyed',
    'envelopeDeleted': true,
    'keyDeleted': true,
    'databaseFilesDeleted': <String>[],
    'databaseFilesRemaining': <String>[],
  };
  bool releaseThrows = false;
  bool destroyThrows = false;
  bool leaseHeld = false;
  int _headerCalls = 0;

  /// Wraps the opened database so `PRAGMA cipher_version` reports SQLCipher.
  final bool cipherVersionOverride;
  final List<String> calls = [];
  final List<Database> openedDatabases = [];

  _FakePlatform({
    this.supported = true,
    this.openKeyReply,
    this.openKeyThrows,
    this.opener,
    this.cipherVersionOverride = false,
    this.openKeyGate,
    this.inspectReply = const {
      'databasePath': '/x/sense_encrypted_v1.db',
      'envelopePath': '/x/sense_db_key_v1.envelope',
      'legacyDatabasePath': '/x/mindpulse_secure.db',
      'lifecycle': 'idle',
    },
    this.headerThrowsOnCall,
  });

  @override
  bool get isSupported => supported;

  @override
  Future<Map<String, Object?>> inspect({String? testNamespace}) async {
    calls.add('inspect');
    final r = inspectReply;
    if (r == null) throw StateError('null reply');
    return Map.of(r);
  }

  @override
  Future<Map<String, Object?>> openKey({String? testNamespace}) async {
    calls.add('openKey');
    if (openKeyGate != null) await openKeyGate;
    if (openKeyThrows != null) throw openKeyThrows!();
    final reply = Map.of(openKeyReply!);
    if (reply['status'] == 'ready') leaseHeld = true;
    return reply;
  }

  @override
  Future<Map<String, Object?>> commitOpen(String leaseId, {String? testNamespace}) async {
    calls.add('commitOpen');
    return Map.of(commitReply);
  }

  @override
  Future<Map<String, Object?>> release(String leaseId, {String? testNamespace}) async {
    calls.add('release');
    if (releaseThrows) throw Exception('channel failure');
    leaseHeld = false;
    return {'released': true};
  }

  @override
  Future<Map<String, Object?>> destroy({String? testNamespace}) async {
    calls.add('destroy');
    if (destroyThrows) throw Exception('channel failure');
    return Map.of(destroyReply);
  }

  @override
  Future<Database> openEncrypted(String path, String passphrase, OpenDatabaseOptions options) async {
    calls.add('openEncrypted');
    final db = await opener!(path, passphrase, options);
    final result = cipherVersionOverride ? _CipherVersionDatabase(db) : db;
    openedDatabases.add(result);
    return result;
  }

  @override
  Future<bool> hasPlaintextSqliteHeader(String path) async {
    calls.add('header');
    _headerCalls++;
    if (_headerCalls == headerThrowsOnCall) throw const SecureStorageIoException();
    final f = File(path);
    if (!await f.exists()) return false;
    final bytes = await f.openRead(0, 16).fold<List<int>>([], (a, b) => a..addAll(b));
    return String.fromCharCodes(bytes) == 'SQLite format 3\u0000';
  }
}

/// A plain-SQLite database that answers `PRAGMA cipher_version` like SQLCipher,
/// to reach the success path on the host. Real SQLCipher runs on the device.
class _CipherVersionDatabase implements Database {
  final Database _inner;
  _CipherVersionDatabase(this._inner);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.trim() == 'PRAGMA cipher_version') {
      return [
        {'cipher_version': '4.20.0 community'}
      ];
    }
    return _inner.rawQuery(sql, arguments);
  }

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Future<void> close() => _inner.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// `PRAGMA cipher_version` throws an Error (not an Exception).
class _ThrowingCipherVersionDatabase implements Database {
  final Database _inner;
  _ThrowingCipherVersionDatabase(this._inner);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async =>
      throw StateError('engine failure');

  @override
  bool get isOpen => _inner.isOpen;

  @override
  Future<void> close() => _inner.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}
