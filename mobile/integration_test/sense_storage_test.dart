// Milestone K1 on a device or emulator: the storage owner opens the REAL
// development namespace (Android Keystore + SQLCipher 4.20.0 + the native
// lifecycle registry and build policy), persists consent through the existing
// repository, and never touches the participant database.
//
// Run (debug build, with the explicit define):
//   flutter test integration_test/sense_storage_test.dart -d emulator-5554 \
//       --dart-define=SENSE_DEV_STORAGE=1
//
// The development namespace is destroyed at the end. An emulator Keystore is
// software-backed: this is not hardware-backed validation.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:mindpulse/data/local/sense_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = createDefaultSecureKeyPlatform();
  final policy = SenseStoragePolicy.fromEnvironment();

  WorkloadEntry workload(int demand) => WorkloadEntry(
        mentalDemand: demand,
        effort: 3,
        deadlines48h: 1,
        day: LocalDay.fromLocal(DateTime.now()),
        provenance: Provenance.fromChanged(
            allFields: WorkloadEntry.allFields, changed: {'mental_demand'}, submittedAtUtc: DateTime.now().toUtc()),
      );

  Future<Map<String, Object?>> inspectParticipant() => platform.inspect();
  Future<Map<String, Object?>> inspectDev() => platform.inspect(testNamespace: kDevelopmentStorageNamespace);

  Future<void> destroyDev() async {
    final r = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
    expect(r.cryptographicallyErased, isTrue);
  }

  setUpAll(() async {
    expect(currentBuildMode, BuildMode.debug);
    expect(kSenseDevStorageDefine, isTrue, reason: 'run with --dart-define=SENSE_DEV_STORAGE=1');
    expect(policy.developmentStorageEnabled, isTrue);
    // Start from an empty development namespace (a previous run may have left one).
    final s = await inspectDev();
    if (s['databasePresent'] == true || s['envelopePresent'] == true || s['keyAliasPresent'] == true) {
      await destroyDev();
    }
  });

  testWidgets('K1-1 the debug build cannot open participant storage (Dart and native)', (t) async {
    final before = await inspectParticipant();
    final storage = SenseStorage(policy: policy);
    final r = await storage.open(StorageTarget.participant) as StorageUnavailable;
    expect(r.reason, StorageUnavailableReason.buildNotEligible);
    expect(r.failureCode, EncryptedDatabaseFailureCode.buildNotProductionEligible);
    // The native gate, called directly, refuses too.
    final native = await platform.openKey();
    expect(native['status'], 'failed');
    expect(native['failure'], 'buildNotProductionEligible');
    expect(native.containsKey('passphrase'), isFalse);
    final after = await inspectParticipant();
    for (final k in ['databasePresent', 'envelopePresent', 'keyAliasPresent', 'setupPending']) {
      expect(after[k], before[k], reason: 'participant $k unchanged');
      expect(after[k], isFalse, reason: 'no participant $k');
    }
    storage.dispose();
  });

  testWidgets('K1-2 startup opens only the development namespace: separate path, key and lease', (t) async {
    final storage = SenseStorage(policy: policy);
    final ready = await storage.start() as StorageReady;
    expect(ready.target, StorageTarget.development);
    expect(ready.productionEligible, isFalse);
    expect(ready.cipherVersion, startsWith('4.20.0'));
    expect(ready.security.emulator, isTrue);
    expect(ready.database.path, contains('/test_namespaces/dev_storage/sense_encrypted_v1.db'));
    expect(await platform.hasPlaintextSqliteHeader(ready.database.path), isFalse, reason: 'encrypted on disk');

    final dev = await inspectDev();
    expect(dev['keyAliasPresent'], isTrue);
    expect(dev['lifecycle'], 'open');
    final participant = await inspectParticipant();
    expect(participant['keyAliasPresent'], isFalse);
    expect(participant['databasePresent'], isFalse);
    expect(participant['lifecycle'], 'idle', reason: 'a separate lease');

    // One connection: an independent provider and native destruction are refused.
    final second = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).open();
    expect((second as EncryptedDatabaseFailed).code, EncryptedDatabaseFailureCode.databaseAlreadyOpen);
    final nativeDestroy = await platform.destroy(testNamespace: kDevelopmentStorageNamespace);
    expect(nativeDestroy['status'], 'busy');
    expect((await inspectDev())['keyAliasPresent'], isTrue);

    await storage.close();
    expect(storage.state, isA<StorageClosed>());
    expect((await inspectDev())['lifecycle'], 'idle');
    storage.dispose();
  });

  testWidgets('K1-3 consent is persisted, authorizes writes, revocation blocks later writes', (t) async {
    final storage = SenseStorage(policy: policy);
    final prefs = ConsentPreferences()..attach(storage);
    final ready = await storage.start() as StorageReady;
    for (var i = 0; i < 100 && prefs.persistence != ConsentPersistence.persisted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(prefs.persistence, ConsentPersistence.persisted);
    expect(prefs.isDevelopmentStorage, isTrue);
    expect(InputModality.values.map(prefs.isEnabled), everyElement(isFalse));
    final id = ready.profile.localPersonId;

    // OFF by default: a write is refused.
    await expectLater(ready.store.workload.upsert(id, workload(2)), throwsA(isA<ConsentDeniedException>()));

    expect(await prefs.setEnabled(InputModality.workload, true), ConsentChangeResult.saved);
    final saved = await ready.store.workload.upsert(id, workload(4));
    expect(await prefs.setEnabled(InputModality.workload, false), ConsentChangeResult.saved);
    await expectLater(
      ready.store.workload.upsert(id, workload(5)),
      throwsA(isA<ConsentDeniedException>().having((e) => e.reason, 'reason', ConsentDenialReason.disabled)),
    );
    final kept = await ready.store.workload.byDate(id, saved.entry.day.date);
    expect(kept!.entry.mentalDemand, 4, reason: 'earlier record kept after revocation');
    final history = await ready.store.consent.history(id);
    expect(history.map((e) => '${e.modality}:${e.enabled}'), ['M4:true', 'M4:false']);

    prefs.detach();
    await storage.close();
    storage.dispose();
  });

  testWidgets('K1-4 a reopened owner reloads the latest snapshot and the same profile', (t) async {
    final storage = SenseStorage(policy: policy);
    final first = await storage.start() as StorageReady;
    final prefs = ConsentPreferences()..attach(storage);
    for (var i = 0; i < 100 && prefs.persistence != ConsentPersistence.persisted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await prefs.setEnabled(InputModality.sleep, true), ConsentChangeResult.saved);
    final person = first.profile.localPersonId;
    prefs.detach();
    await storage.close();
    storage.dispose();

    final again = SenseStorage(policy: policy);
    final reloaded = ConsentPreferences()..attach(again);
    final ready = await again.start() as StorageReady;
    for (var i = 0; i < 100 && reloaded.persistence != ConsentPersistence.persisted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(ready.profile.localPersonId, person);
    expect({for (final m in InputModality.values) if (reloaded.isEnabled(m)) m}, {InputModality.sleep});
    expect(reloaded.isEnabled(InputModality.workload), isFalse, reason: 'latest M4 event is OFF');
    reloaded.detach();
    await again.close();
    again.dispose();
  });

  testWidgets('K1-5 the development namespace can be destroyed; the participant key never existed', (t) async {
    await destroyDev();
    final dev = await inspectDev();
    expect(dev['databasePresent'], isFalse);
    expect(dev['keyAliasPresent'], isFalse);
    expect((await inspectParticipant())['keyAliasPresent'], isFalse);
  });

  testWidgets('K1-6 unknown channel methods are not implemented (no hidden participant path)', (t) async {
    const channel = MethodChannel('org.sense.mindpulse/secure_database');
    await expectLater(channel.invokeMethod('openParticipantInDebug'), throwsA(isA<MissingPluginException>()));
  });
}
