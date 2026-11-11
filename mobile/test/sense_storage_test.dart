// Milestone K1: the application storage owner (SenseStorage) and repository-
// backed consent preferences.
//
// Host tests: the native Keystore side is replaced by FakeSecureKeyPlatform,
// which opens disposable plain-SQLite files through sqflite_common_ffi. That is
// confined to test/; the real encrypted engine, the native build policy and
// the Keystore checks run on the device (integration_test/sense_storage_test.dart).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/dart_source_guard.dart';
import 'support/fake_secure_key_platform.dart';

const _debugDev = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true);
const _debugDefault = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: false);
const _profileDev = SenseStoragePolicy(buildMode: BuildMode.profile, developmentDefine: true);
const _releaseDev = SenseStoragePolicy(buildMode: BuildMode.release, developmentDefine: true);

void main() {
  late Directory dir;
  final owners = <SenseStorage>[];

  setUpAll(sqfliteFfiInit);
  setUp(() => dir = Directory.systemTemp.createTempSync('sense_k1_'));
  tearDown(() async {
    for (final s in owners) {
      await s.close();
    }
    owners.clear();
    ConsentPreferences.instance.reset();
    dir.deleteSync(recursive: true);
  });

  SenseStorage owner(SenseStoragePolicy policy, FakeSecureKeyPlatform platform) {
    final s = SenseStorage(policy: policy, platform: platform);
    owners.add(s);
    return s;
  }

  LocalDay today() => LocalDay.fromLocal(DateTime.now());

  WorkloadEntry workload(int demand) => WorkloadEntry(
        mentalDemand: demand,
        effort: 3,
        deadlines48h: 1,
        day: today(),
        provenance: Provenance.fromChanged(
            allFields: WorkloadEntry.allFields, changed: {'mental_demand'}, submittedAtUtc: DateTime.now().toUtc()),
      );

  // ---- Policy ---------------------------------------------------------------------------------

  group('SenseStorage policy', () {
    test('the define needs a debug build; startup never targets the participant database', () {
      expect(_debugDefault.developmentStorageEnabled, isFalse);
      expect(_debugDev.developmentStorageEnabled, isTrue);
      expect(_profileDev.developmentStorageEnabled, isFalse);
      expect(_releaseDev.developmentStorageEnabled, isFalse);
      for (final p in [_debugDefault, _profileDev, _releaseDev]) {
        expect(p.startupTarget, isNull);
      }
      expect(_debugDev.startupTarget, StorageTarget.development);
      expect(kDevelopmentStorageNamespace, 'dev_storage');
      expect(kDevelopmentStorageLabel, 'DEVELOPMENT DATA — NOT FOR PARTICIPANTS');
    });

    test('this test build has development storage disabled by default (no define)', () {
      expect(kSenseDevStorageDefine, isFalse);
      expect(SenseStoragePolicy.fromEnvironment().developmentStorageEnabled, isFalse);
    });

    test('debug without the define: unavailable, and nothing is opened or created', () async {
      final p = FakeSecureKeyPlatform(dir);
      final s = owner(_debugDefault, p);
      expect(await s.start(), isA<StorageUnavailable>()
          .having((u) => u.reason, 'reason', StorageUnavailableReason.developmentStorageDisabled));
      expect(p.calls, isEmpty, reason: 'participant storage is not initialized at normal debug startup');
      expect(dir.listSync(), isEmpty);
      expect(await s.open(StorageTarget.development), isA<StorageUnavailable>());
      expect(p.calls, isEmpty);
    });

    test('profile and release builds reject development storage whatever the define says', () async {
      for (final (policy, reason) in [
        (_profileDev, StorageUnavailableReason.buildNotEligible),
        (_releaseDev, StorageUnavailableReason.participantStorageNotEnabled),
      ]) {
        final p = FakeSecureKeyPlatform(dir);
        final s = owner(policy, p);
        expect((await s.start() as StorageUnavailable).reason, reason, reason: policy.buildMode.name);
        expect((await s.open(StorageTarget.development) as StorageUnavailable).reason,
            StorageUnavailableReason.buildNotEligible);
        expect(p.calls, isEmpty, reason: policy.buildMode.name);
      }
    });

    test('debug and profile cannot open the participant database (refused before any key call)', () async {
      for (final policy in [_debugDev, _debugDefault, _profileDev]) {
        final p = FakeSecureKeyPlatform(dir);
        final s = owner(policy, p);
        final r = await s.open(StorageTarget.participant) as StorageUnavailable;
        expect(r.reason, StorageUnavailableReason.buildNotEligible);
        expect(r.failureCode, EncryptedDatabaseFailureCode.buildNotProductionEligible);
        expect(p.calls, isEmpty, reason: policy.buildMode.name);
      }
      expect(dir.listSync(), isEmpty);
    });
  });

  // ---- Lifecycle ------------------------------------------------------------------------------

  group('SenseStorage lifecycle', () {
    test('debug with the define opens ONLY the development namespace, never production eligible', () async {
      final p = FakeSecureKeyPlatform(dir);
      final s = owner(_debugDev, p);
      final states = <String>[];
      s.addListener(() => states.add(s.state.runtimeType.toString()));
      final r = await s.start() as StorageReady;
      expect(states, ['StorageOpening', 'StorageReady']);
      expect(r.target, StorageTarget.development);
      expect(r.isDevelopment, isTrue);
      expect(r.productionEligible, isFalse);
      expect(p.openKeyNamespaces, ['dev_storage']);
      expect(r.database.isOpen, isTrue);
      expect((await r.database.rawQuery('PRAGMA user_version')).first.values.first, kSchemaVersion);
      expect(r.profile.localPersonId, hasLength(36));
      expect((await r.store.profiles.active())!.localPersonId, r.profile.localPersonId);
      expect(Directory('${dir.path}/participant').existsSync(), isFalse, reason: 'participant path untouched');
    });

    test('uses the existing lifecycle owner: an independent provider cannot open a second connection', () async {
      final p = FakeSecureKeyPlatform(dir);
      final s = owner(_debugDev, p);
      await s.start();
      final other = EncryptedDatabaseProvider(platform: p, testNamespace: 'dev_storage', buildMode: BuildMode.debug);
      final second = await other.open() as EncryptedDatabaseFailed;
      expect(second.code, EncryptedDatabaseFailureCode.databaseAlreadyOpen);
      expect(p.calls.where((c) => c == 'openKey'), hasLength(1));
      await s.close();
      final afterClose = await other.open();
      expect(afterClose, isA<EncryptedDatabaseOpened>(), reason: 'the lease was released on close');
      await other.close();
    });

    test('concurrent and repeated opens return the one connection', () async {
      final p = FakeSecureKeyPlatform(dir);
      final s = owner(_debugDev, p);
      final results = await Future.wait([s.start(), s.open(StorageTarget.development), s.start()]);
      expect(results.toSet(), hasLength(1));
      expect(identical(results.first, s.state), isTrue);
      expect(p.calls.where((c) => c == 'openKey'), hasLength(1));
      expect(() => s.open(StorageTarget.participant), throwsStateError, reason: 'close first');
    });

    test('close releases the lease and closes the connection; repeatable; reopen keeps the profile', () async {
      final p = FakeSecureKeyPlatform(dir);
      final s = owner(_debugDev, p);
      final first = await s.start() as StorageReady;
      await s.close();
      expect(s.state, isA<StorageClosed>());
      expect(first.database.isOpen, isFalse);
      expect(p.calls.where((c) => c == 'release'), hasLength(1));
      await s.close();
      expect(p.calls.where((c) => c == 'release'), hasLength(1));
      final again = await s.open(StorageTarget.development) as StorageReady;
      expect(again.profile.localPersonId, first.profile.localPersonId);
    });

    test('key, hardware and encryption failures are reported, never worked around', () async {
      for (final failure in [
        'insecureKeyStorage',
        'envelopeAuthenticationFailed',
        'keyMissingForExistingDatabase',
        'plaintextDatabaseAtEncryptedPath',
        'orphanedKey',
      ]) {
        final p = FakeSecureKeyPlatform(dir, failWith: failure);
        final s = owner(_debugDev, p);
        final r = await s.start() as StorageUnavailable;
        expect(r.reason, StorageUnavailableReason.openFailed, reason: failure);
        expect(r.reason.isFailure, isTrue);
        expect(r.failureCode!.name, failure);
        expect(p.calls, isNot(contains('openEncrypted')), reason: 'no database is opened: $failure');
        expect(s.ready, isNull);
      }
    });

    test('unsupported platform: unavailable, no fallback', () async {
      final p = FakeSecureKeyPlatform(dir, supported: false);
      final s = owner(_debugDev, p);
      expect((await s.start() as StorageUnavailable).reason, StorageUnavailableReason.unsupportedPlatform);
      expect(p.calls, isEmpty);
    });

    test('development storage is never production eligible, even if a reply claims it', () async {
      final p = FakeSecureKeyPlatform(dir)..productionEligibleOverride = true;
      final s = owner(_debugDev, p);
      final r = await s.start() as StorageReady;
      expect(r.productionEligible, isFalse);
      expect(r.isDevelopment, isTrue);
    });
  });

  // ---- Persisted consent ---------------------------------------------------------------------

  group('Persisted consent', () {
    Future<(SenseStorage, StorageReady, ConsentPreferences)> persisted(FakeSecureKeyPlatform p) async {
      final s = owner(_debugDev, p);
      final prefs = ConsentPreferences();
      prefs.attach(s);
      final ready = await s.start() as StorageReady;
      await pumpEventQueue();
      expect(prefs.persistence, ConsentPersistence.persisted);
      return (s, ready, prefs);
    }

    test('every modality starts OFF, in memory and when loaded from an empty database', () async {
      final prefs = ConsentPreferences();
      expect(prefs.persistence, ConsentPersistence.memoryOnly);
      expect(InputModality.values.map(prefs.isEnabled), everyElement(isFalse));
      final (_, ready, loaded) = await persisted(FakeSecureKeyPlatform(dir));
      expect(InputModality.values.map(loaded.isEnabled), everyElement(isFalse));
      expect(await ready.store.consent.history(ready.profile.localPersonId), isEmpty);
      expect(loaded.isDevelopmentStorage, isTrue);
      expect(loaded.savedStateNote, 'saved to development storage');
    });

    test('opt-in appends exactly one event; opt-out appends a later OFF event; history is kept', () async {
      final (_, ready, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      final id = ready.profile.localPersonId;
      expect(await prefs.setEnabled(InputModality.sleep, true), ConsentChangeResult.saved);
      expect(prefs.isEnabled(InputModality.sleep), isTrue);
      var history = await ready.store.consent.history(id);
      expect(history.map((e) => '${e.modality}:${e.enabled}'), ['M3:true']);
      expect(await prefs.setEnabled(InputModality.sleep, true), ConsentChangeResult.unchanged);
      expect(await ready.store.consent.history(id), hasLength(1), reason: 'no duplicate event');
      expect(await prefs.setEnabled(InputModality.sleep, false), ConsentChangeResult.saved);
      history = await ready.store.consent.history(id);
      expect(history.map((e) => '${e.modality}:${e.enabled}'), ['M3:true', 'M3:false']);
      expect(history[1].id, greaterThan(history[0].id));
      expect(prefs.isEnabled(InputModality.sleep), isFalse);
    });

    test('each modality maps to its existing identifier (M1 to M6)', () async {
      final (_, ready, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      for (final m in InputModality.values) {
        await prefs.setEnabled(m, true);
      }
      final history = await ready.store.consent.history(ready.profile.localPersonId);
      expect(history.map((e) => e.modality), ['M1', 'M2', 'M3', 'M4', 'M5', 'M6']);
      expect(InputModality.checkIn.code, 'M1');
      expect(InputModality.sleep.code, 'M3');
      expect(InputModality.workload.code, 'M4');
    });

    test('rapid changes are saved in order', () async {
      final (_, ready, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      final results = await Future.wait([
        prefs.setEnabled(InputModality.workload, true),
        prefs.setEnabled(InputModality.workload, false),
        prefs.setEnabled(InputModality.workload, true),
      ]);
      expect(results, everyElement(ConsentChangeResult.saved));
      final history = await ready.store.consent.history(ready.profile.localPersonId);
      expect(history.map((e) => e.enabled), [true, false, true]);
      expect(prefs.isEnabled(InputModality.workload), isTrue);
    });

    test('a restart reloads the latest persisted snapshot', () async {
      final p = FakeSecureKeyPlatform(dir);
      final (s, _, prefs) = await persisted(p);
      await prefs.setEnabled(InputModality.checkIn, true);
      await prefs.setEnabled(InputModality.workload, true);
      await prefs.setEnabled(InputModality.checkIn, false);
      prefs.detach();
      await s.close();

      final s2 = owner(_debugDev, FakeSecureKeyPlatform(dir));
      final reloaded = ConsentPreferences()..attach(s2);
      await s2.start();
      await pumpEventQueue();
      expect(reloaded.persistence, ConsentPersistence.persisted);
      expect({for (final m in InputModality.values) if (reloaded.isEnabled(m)) m}, {InputModality.workload});
    });

    test('a failed write is not shown as saved and changes nothing', () async {
      final (_, ready, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      // Test-only fault: make every consent insert fail.
      await ready.database.execute(
          "CREATE TRIGGER k1_block BEFORE INSERT ON consent_events BEGIN SELECT RAISE(ABORT, 'blocked'); END");
      var notified = 0;
      prefs.addListener(() => notified++);
      expect(await prefs.setEnabled(InputModality.sleep, true), ConsentChangeResult.failed);
      expect(prefs.isEnabled(InputModality.sleep), isFalse);
      expect(prefs.isPending(InputModality.sleep), isFalse);
      expect(notified, greaterThan(0), reason: 'the pending state was shown and cleared');
      expect(await ready.store.consent.history(ready.profile.localPersonId), isEmpty);
    });

    test('changes are refused while saved preferences load', () async {
      final gate = Completer<void>();
      final p = FakeSecureKeyPlatform(dir)..openKeyGate = gate.future;
      final s = owner(_debugDev, p);
      final prefs = ConsentPreferences()..attach(s);
      final opening = s.start();
      await pumpEventQueue();
      expect(s.state, isA<StorageOpening>());
      expect(prefs.persistence, ConsentPersistence.loading);
      expect(await prefs.setEnabled(InputModality.sleep, true), ConsentChangeResult.notReady);
      gate.complete();
      await opening;
      await pumpEventQueue();
      expect(prefs.isEnabled(InputModality.sleep), isFalse);
    });

    test('when storage becomes ready, the saved snapshot replaces in-memory choices', () async {
      // Saved state: only M3 on.
      final (s, _, first) = await persisted(FakeSecureKeyPlatform(dir));
      await first.setEnabled(InputModality.sleep, true);
      first.detach();
      await s.close();

      final s2 = owner(_debugDev, FakeSecureKeyPlatform(dir));
      final prefs = ConsentPreferences();
      expect(await prefs.setEnabled(InputModality.journal, true), ConsentChangeResult.heldInMemory);
      prefs.attach(s2);
      await s2.start();
      await pumpEventQueue();
      expect(prefs.isEnabled(InputModality.journal), isFalse, reason: 'in-memory choice is not authoritative');
      expect(prefs.isEnabled(InputModality.sleep), isTrue);
    });

    test('storage failure: choices are in memory, labelled unavailable, and saved values are not kept', () async {
      final (s, _, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      await prefs.setEnabled(InputModality.sleep, true);
      await s.close();
      expect(prefs.persistence, ConsentPersistence.memoryOnly);
      expect(prefs.isEnabled(InputModality.sleep), isFalse);

      final failing = owner(_debugDev, FakeSecureKeyPlatform(dir, failWith: 'insecureKeyStorage'));
      final p2 = ConsentPreferences()..attach(failing);
      await failing.start();
      expect(p2.persistence, ConsentPersistence.storageUnavailable);
      expect(p2.savedStateNote, 'not saved');
      expect(await p2.setEnabled(InputModality.sleep, true), ConsentChangeResult.heldInMemory);
    });

    test('in-memory preferences never authorize a write', () async {
      final p = FakeSecureKeyPlatform(dir);
      final s = owner(_debugDev, p);
      final ready = await s.start() as StorageReady;
      // Not attached: ON in memory only.
      final memory = ConsentPreferences();
      await memory.setEnabled(InputModality.workload, true);
      expect(memory.isEnabled(InputModality.workload), isTrue);
      await expectLater(
        ready.store.workload.upsert(ready.profile.localPersonId, workload(3)),
        throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.notRecorded)),
      );
      expect(await ready.store.workload.byDate(ready.profile.localPersonId, today().date), isNull);
    });

    test('unavailable storage offers no store to write to', () async {
      final s = owner(_debugDefault, FakeSecureKeyPlatform(dir));
      final prefs = ConsentPreferences()..attach(s);
      await s.start();
      await prefs.setEnabled(InputModality.workload, true);
      expect(prefs.persistence, ConsentPersistence.memoryOnly);
      expect(s.ready, isNull);
    });

    test('revocation blocks later writes and keeps earlier records', () async {
      final (_, ready, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      final id = ready.profile.localPersonId;
      await prefs.setEnabled(InputModality.workload, true);
      final saved = await ready.store.workload.upsert(id, workload(4));
      expect(await prefs.setEnabled(InputModality.workload, false), ConsentChangeResult.saved);
      await expectLater(
        ready.store.workload.upsert(id, workload(5)),
        throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.disabled)),
      );
      final kept = await ready.store.workload.byDate(id, today().date);
      expect(kept!.id, saved.id);
      expect(kept.entry.mentalDemand, 4, reason: 'the earlier record is unchanged');
    });

    test('detaching drops back to memory with everything OFF', () async {
      final (_, _, prefs) = await persisted(FakeSecureKeyPlatform(dir));
      await prefs.setEnabled(InputModality.activity, true);
      prefs.detach();
      expect(prefs.persistence, ConsentPersistence.memoryOnly);
      expect(InputModality.values.map(prefs.isEnabled), everyElement(isFalse));
    });
  });

  // ---- Static guards ----------------------------------------------------------------------------

  group('K1 static guards', () {
    String read(String p) => File(p).readAsStringSync();
    // Code only: line comments and doc comments removed.
    String code(String p) => read(p).split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
    // Parsed with the Dart analyzer (test/support/dart_source_guard.dart):
    // single- and double-quoted URIs, export and part directives, conditional
    // imports, and identifiers in code only (not comments or strings).
    final lib = parseDartTree('lib');
    const legacyHelper = 'lib/data/database/database_helper.dart';

    test('FFI (plain SQLite) is confined to test code; the app has no plaintext opener', () {
      for (final f in lib.values) {
        for (final uri in f.uris) {
          expect(uri, isNot(startsWith('package:sqflite_common_ffi')), reason: f.path);
          expect(uri, isNot(startsWith('package:sqlite3/')), reason: f.path);
          if (f.path != legacyHelper) {
            // The deprecated, uncalled legacy helper is the only plaintext-plugin
            // importer; everything else uses the API types (sqlite_api.dart) only.
            expect(uri, isNot(allOf(startsWith('package:sqflite/'), isNot('package:sqflite/sqlite_api.dart'))),
                reason: f.path);
          }
        }
        expect(f.identifiers.intersection({'databaseFactoryFfi', 'sqfliteFfiInit'}), isEmpty, reason: f.path);
        if (f.path != legacyHelper) {
          expect(f.identifiers.intersection({'getDatabasesPath', 'databaseFactory'}), isEmpty, reason: f.path);
        }
      }
      // openDatabase: the frozen legacy helper, the SQLCipher platform file,
      // and the factory-injected SenseDatabase.open (host tests pass FFI).
      expect(lib.values.where((f) => f.identifiers.contains('openDatabase')).map((f) => f.path), [
        legacyHelper,
        'lib/data/local/encrypted/secure_key_platform_io.dart',
        'lib/data/local/local_data_store.dart',
      ]);
      expect(Directory('test/support').listSync().map((f) => f.uri.pathSegments.last),
          contains('fake_secure_key_platform.dart'));
    });

    test('the frozen legacy plaintext database helper stays unused', () {
      for (final f in lib.values.where((f) => f.path != legacyHelper)) {
        expect(f.projectDependencies, isNot(contains(legacyHelper)), reason: f.path);
        expect(f.identifiers, isNot(contains('DatabaseHelper')), reason: f.path);
      }
    });

    test('presentation code cannot reach the database, repositories, or Export and Erase', () {
      // Members that only reach storage internals: the ready state and its
      // store and connection, raw SQL, repository writes, and data rights.
      const ownerInternals = {'ready', 'store', 'database', 'profiles', 'checkIns', 'ensureActive', 'snapshot'};
      const sql = {'rawQuery', 'rawInsert', 'rawUpdate', 'rawDelete', 'execute', 'batch', 'transaction', 'query',
          'insert', 'update', 'delete'};
      const writes = {'upsert', 'deleteByDate', 'recordChange'};
      const rights = {'exportAllUserData', 'exportAllUserDataJson', 'eraseAllUserData'};
      const dataTypes = {'StorageReady', 'LocalDataStore', 'LocalDataService', 'EraseResult', 'SenseDatabase',
          'Database', 'DatabaseExecutor', 'Transaction', 'Batch', 'EncryptedDatabaseProvider', 'DatabaseHelper',
          'openDatabase', 'LocalProfileRepository', 'DailyRecordRepository', 'ConsentRepository',
          'SqliteLocalProfileRepository', 'SqliteDailyRecordRepository', 'SqliteConsentRepository',
          // Milestone K2: the service bound to the connection stays inside the owner.
          'WorkloadRecordService', 'WorkloadRepository'};
      // The consent model is the one non-data reader of the ready store: it
      // reads the consent snapshot and appends consent events, nothing else.
      const consentModel = 'lib/core/state/consent_preferences.dart';
      const ownerHolders = {'lib/main.dart', 'lib/presentation/widgets/sense_storage_scope.dart', consentModel};
      final app = lib.values.where((f) => !f.path.startsWith('lib/data/')).toList();
      expect(app.map((f) => f.path), containsAll([...ownerHolders, 'lib/presentation/screens/settings_screen.dart']));
      for (final f in app) {
        final consent = f.path == consentModel;
        final banned = consent
            ? {...sql, ...rights, 'database', 'profiles', 'checkIns', 'ensureActive', 'upsert', 'deleteByDate'}
            : {...sql, ...rights, ...ownerInternals, ...writes};
        expect(f.memberAccesses.intersection(banned), isEmpty, reason: f.path);
        expect(f.identifiers.intersection(dataTypes.difference({if (consent) 'StorageReady'})), isEmpty,
            reason: f.path);
        if (!ownerHolders.contains(f.path)) {
          expect(f.identifiers.intersection({'SenseStorage', 'SenseStorageScope'}), isEmpty, reason: f.path);
        }
      }
    });

    test('the storage owner opens only through the encrypted provider and never the legacy database', () {
      final src = code('lib/data/local/sense_storage.dart');
      expect(src, contains('EncryptedDatabaseProvider('));
      expect(src, isNot(contains('openDatabase')));
      expect(src, isNot(contains('SenseDatabase.open')));
      expect(src, isNot(contains('mindpulse_secure')));
      expect(src, isNot(contains('kLocalDatabaseFileName')));
      expect(src, isNot(contains('DatabaseHelper')));
      expect(src, contains("String.fromEnvironment('SENSE_DEV_STORAGE') == '1'"));
    });

    test('Check-in and Sleep Save handlers remain disconnected', () {
      for (final screen in ['check_in_screen.dart', 'sleep_screen.dart']) {
        final src = read('lib/presentation/screens/$screen');
        final facts = lib['lib/presentation/screens/$screen']!;
        expect(facts.identifiers.intersection({'SenseStorage', 'WorkloadController', 'workloadAccessOf'}), isEmpty,
            reason: screen);
        expect(facts.memberAccesses, isNot(contains('upsert')), reason: screen);
        expect(src, contains('NatureNotSavedNote'), reason: screen);
      }
      expect(read('lib/presentation/screens/sleep_screen.dart'), contains("showNatureNotSavedMessage(context, 'sleep entry')"));
    });

    // ---- Milestone K2: Workload persistence boundary ---------------------------------------
    test('K2: the storage owner re-exports only the narrow workload surface (show lists, no store or database)', () {
      final owner = lib['lib/data/local/sense_storage.dart']!;
      final exports = owner.of(DirectiveKind.export).toList();
      expect(exports.map((e) => e.projectPath).toSet(),
          {'lib/data/local/local_data_store.dart', 'lib/data/local/workload_records.dart'});
      for (final e in exports) {
        expect(e.shown, isNotNull, reason: '${e.uri} must use an explicit show list');
      }
      final shown = {for (final e in exports) ...e.shown!};
      expect(shown.intersection({
        'Database', 'DatabaseExecutor', 'LocalDataStore', 'SenseDatabase', 'WorkloadRecordService',
        'WorkloadRepository', 'DailyRecordRepository', 'ConsentRepository', 'LocalProfileRepository',
        'SqliteDailyRecordRepository', 'LocalDataService', 'requireConsent', 'ConsentEvent',
      }), isEmpty);
      // The workload service is built only by the owner.
      final builders = lib.values.where((f) => f.identifiers.contains('WorkloadRecordService')).map((f) => f.path);
      expect(builders.toSet(), {'lib/data/local/sense_storage.dart', 'lib/data/local/workload_records.dart'});
    });

    test('K2: Workload saves only through WorkloadController and WorkloadAccess (no screen-level consent gate)', () {
      const screen = 'lib/presentation/screens/workload_screen.dart';
      const controller = 'lib/core/state/workload_controller.dart';
      const scope = 'lib/presentation/widgets/sense_storage_scope.dart';
      final s = lib[screen]!;
      expect(s.identifiers, containsAll(['WorkloadController', 'workloadAccessOf']));
      // The screen's one use of the access is handing it to its controller:
      // it never keeps it, calls save or loadDay on it, or passes it elsewhere.
      expect(s.identifierCounts['workloadAccessOf'], 1);
      expect(s.callSites['workloadAccessOf'], {'WorkloadController(access:)'});
      expect(s.identifiers.intersection({'WorkloadAccess', 'WorkloadEntry', 'SenseStorage', 'SenseStorageScope'}),
          isEmpty);
      // Only these files touch the workload access surface.
      final users = lib.values
          .where((f) => !f.path.startsWith('lib/data/'))
          .where((f) => f.identifiers.intersection({'WorkloadAccess', 'workloadAccessOf'}).isNotEmpty)
          .map((f) => f.path)
          .toSet();
      expect(users, {screen, controller, scope});
      // Consent is enforced by the repository inside the write transaction:
      // neither the controller nor the screen reads in-memory preferences.
      for (final p in [screen, controller]) {
        expect(lib[p]!.identifiers.intersection({'ConsentPreferences', 'InputModality', 'isEnabled'}), isEmpty,
            reason: p);
        expect(lib[p]!.projectDependencies, isNot(contains('lib/core/state/consent_preferences.dart')), reason: p);
      }
      // The controller writes only through WorkloadAccess.save.
      expect(lib[controller]!.memberAccesses, containsAll(['save', 'loadDay']));
    });

    test('the app creates the owner (no global connection) and attaches the shared consent model', () {
      final main = read('lib/main.dart');
      expect(main, contains('SenseStorage(policy: SenseStoragePolicy.fromEnvironment())'));
      expect(main, contains('_consent.attach(_storage)'));
      expect(main, contains('DevelopmentStorageBanner('));
      expect(main, isNot(contains('static')));
    });
  });
}
