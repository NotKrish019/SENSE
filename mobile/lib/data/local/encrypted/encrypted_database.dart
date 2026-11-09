// SENSE encrypted local database (Milestone J): SQLCipher storage keyed by a
// passphrase wrapped with an Android Keystore AES-256-GCM key.
//
// INFRASTRUCTURE ONLY, NOT USED BY THE APP. No production screen, Save
// handler or `main.dart` opens this database; Settings Export/Erase remain
// unavailable; raw journal text is never persisted. Opening it is an explicit
// call that only tests make today. Real participant data additionally needs a
// physical-device validation of the key's hardware backing (see
// docs/architecture/encrypted_local_storage.md).
//
// Fail closed everywhere: an unsupported platform, a build that is not
// production eligible, any inconsistent key state, a rejected key, a plaintext
// file at the encrypted path, or an engine that does not report SQLCipher all
// return [EncryptedDatabaseFailed]. Nothing here creates a new key for an
// existing database, deletes or resets a database after an error, opens or
// migrates the legacy plaintext `mindpulse_secure.db`, or falls back to
// plaintext SQLite. Nothing here logs, and no result, exception or `toString`
// contains the passphrase.
//
// Lifecycle (hardening finding M1): every provider for the same database
// shares one lifecycle owner per isolate, which serialises open, close and
// destroy; across isolates and Flutter engines the native lifecycle registry
// (one per Android process) holds a lease from before the key is resolved
// until the connection is closed, and refuses destruction while any lease
// exists.

import 'dart:async';

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:sqflite/sqlite_api.dart';

import '../local_data_store.dart';
import 'secure_key_platform.dart';

export 'secure_key_platform.dart' show SecureKeyPlatform, SecureStorageIoException, createDefaultSecureKeyPlatform;

/// Versioned file names inside Android `noBackupFilesDir`.
const String kEncryptedDatabaseFileName = 'sense_encrypted_v1.db';
const String kDatabaseKeyEnvelopeFileName = 'sense_db_key_v1.envelope';
const String kDatabaseSetupMarkerFileName = 'sense_db_setup_v1.pending';

/// The SQLCipher release this build packages (android/build.gradle.kts).
const String kExpectedSqlCipherVersion = '4.20.0';

/// The SQLCipher passphrase format produced by the native key manager:
/// 32 random bytes as 64 lowercase hex characters.
final RegExp _passphraseFormat = RegExp(r'^[0-9a-f]{64}$');

/// Native lifecycle lease ids: 16 random bytes as 32 lowercase hex characters.
final RegExp _leaseFormat = RegExp(r'^[0-9a-f]{32}$');

/// The Flutter build mode, which decides what may be opened (finding M2).
enum BuildMode { debug, profile, release }

/// The build mode this code was compiled in.
BuildMode get currentBuildMode => kReleaseMode
    ? BuildMode.release
    : kProfileMode
        ? BuildMode.profile
        : BuildMode.debug;

/// Where the Keystore reports the wrapping key lives (not attestation-verified).
enum KeySecurityLevel { strongBox, trustedEnvironment, hardwareUnspecified, software, unknown }

/// Why a StrongBox-capable device created the key outside StrongBox.
enum StrongBoxFallback { strongBoxUnavailable, strongBoxProviderRejected }

/// The legacy `mindpulse_secure.db`. Classified from its header only; never
/// opened, converted, renamed or deleted.
enum LegacyDatabaseState { absent, plaintextSqlite, empty, unrecognized }

/// Why the lifecycle owner refused an open or a destroy.
enum LifecycleRefusal {
  /// A connection from this or another provider is open.
  databaseOpen,

  /// Another open is between key unwrap and registration (another engine).
  openInProgress,

  /// A connection registered by a detached Flutter engine may still be open.
  orphanedConnection,
  destroyInProgress,

  /// Only release builds may touch the participant database.
  buildNotProductionEligible,

  /// Test namespaces exist only in debug builds.
  testNamespaceUnavailable,
}

enum EncryptedDatabaseFailureCode {
  /// Not Android (Chrome, desktop, host tests). No plaintext fallback.
  unsupportedPlatform,

  /// Debug or profile build asking for the participant database.
  buildNotProductionEligible,

  /// A test namespace outside a debug build.
  testNamespaceUnavailable,

  /// This database is already open (one connection, one owner). Share the
  /// existing [EncryptedDatabaseOpened] instead of opening again.
  databaseAlreadyOpen,

  /// The native lifecycle registry refused (see [EncryptedDatabaseFailed.refusal]).
  lifecycleBusy,
  envelopeMissingForExistingDatabase,
  keyMissingForExistingDatabase,
  keyAndEnvelopeMissingForExistingDatabase,
  envelopeWithoutKey,
  orphanedKey,
  envelopeMalformed,
  envelopeAuthenticationFailed,

  /// No evidence of a hardware-backed key for the participant database.
  insecureKeyStorage,

  /// A plaintext SQLite file sits at the encrypted-database path.
  plaintextDatabaseAtEncryptedPath,
  keystoreError,
  initializationFailed,

  /// The native reply did not contain a well-formed passphrase or path.
  invalidKeyMaterial,

  /// The native reply did not have the expected shape or types.
  malformedReply,

  /// The database files could not be inspected (file-system error).
  storageError,

  /// SQLCipher rejected the key ("file is not a database"). Never treated as
  /// permission to initialize a fresh database.
  databaseKeyRejected,

  /// Opening failed for another reason.
  databaseOpenFailed,

  /// The opened database is not SQLCipher-encrypted (no cipher version, or a
  /// plaintext header on disk). The connection is closed immediately.
  notEncrypted,

  /// The platform channel failed or threw.
  platformError,
}

/// Security facts about the wrapping key.
class KeySecurityReport {
  final KeySecurityLevel reportedLevel;

  /// The device was recognised as an emulator; its Keystore report is never
  /// treated as hardware evidence.
  final bool emulator;

  /// A secure-hardware report on a non-emulator. Still not attestation-verified.
  final bool hardwareBackedEvidence;

  const KeySecurityReport({required this.reportedLevel, required this.emulator, required this.hardwareBackedEvidence});

  bool get _reportsSecureHardware => switch (reportedLevel) {
        KeySecurityLevel.strongBox || KeySecurityLevel.trustedEnvironment || KeySecurityLevel.hardwareUnspecified => true,
        KeySecurityLevel.software || KeySecurityLevel.unknown => false,
      };

  @override
  String toString() =>
      'KeySecurityReport(${reportedLevel.name}, emulator: $emulator, hardwareBackedEvidence: $hardwareBackedEvidence)';
}

sealed class EncryptedDatabaseOpenResult {
  const EncryptedDatabaseOpenResult();
}

final class EncryptedDatabaseOpened extends EncryptedDatabaseOpenResult {
  /// The open SQLCipher database, at schema version [kSchemaVersion]. Use it
  /// with `LocalDataStore` / `LocalDataService` exactly like the plaintext one.
  /// Close it with [EncryptedDatabaseProvider.close] (closing it directly is
  /// also safe: the owner releases its lease on the next lifecycle call).
  final Database database;
  final String databasePath;

  /// `PRAGMA cipher_version`, e.g. "4.20.0 community".
  final String cipherVersion;
  final KeySecurityReport security;

  /// True only for the participant database in a release build with a
  /// hardware-backed key. Test-namespace databases are never eligible.
  final bool productionEligible;
  final bool firstInitialization;

  /// The database file was missing while a valid key and envelope existed
  /// after a completed setup; an empty database was created with the
  /// existing key. Callers must treat this as an alert, not routine.
  final bool recoveredMissingDatabase;
  final LegacyDatabaseState legacyDatabase;
  final StrongBoxFallback? strongBoxFallback;

  const EncryptedDatabaseOpened({
    required this.database,
    required this.databasePath,
    required this.cipherVersion,
    required this.security,
    required this.productionEligible,
    required this.firstInitialization,
    required this.recoveredMissingDatabase,
    required this.legacyDatabase,
    this.strongBoxFallback,
  });

  @override
  String toString() => 'EncryptedDatabaseOpened(cipher: $cipherVersion, $security, '
      'productionEligible: $productionEligible, first: $firstInitialization, '
      'recoveredMissingDatabase: $recoveredMissingDatabase, legacy: ${legacyDatabase.name}, '
      'strongBoxFallback: ${strongBoxFallback?.name})';
}

final class EncryptedDatabaseFailed extends EncryptedDatabaseOpenResult {
  final EncryptedDatabaseFailureCode code;
  final LegacyDatabaseState? legacyDatabase;
  final KeySecurityReport? security;

  /// Set for [EncryptedDatabaseFailureCode.lifecycleBusy].
  final LifecycleRefusal? refusal;

  const EncryptedDatabaseFailed(this.code, {this.legacyDatabase, this.security, this.refusal});

  @override
  String toString() => 'EncryptedDatabaseFailed(${code.name}, legacy: ${legacyDatabase?.name}, refusal: ${refusal?.name})';
}

/// Presence of each component, without creating anything.
class EncryptedStorageStatus {
  final bool databasePresent;
  final bool envelopePresent;
  final bool keyAliasPresent;

  /// A first-time initialization started and its database is not confirmed yet.
  final bool setupPending;
  final LegacyDatabaseState legacyDatabase;

  /// Native lifecycle state: idle, opening, open, orphaned or destroying.
  final String lifecycle;
  final String databasePath;
  final String envelopePath;
  final String legacyDatabasePath;

  const EncryptedStorageStatus({
    required this.databasePresent,
    required this.envelopePresent,
    required this.keyAliasPresent,
    required this.setupPending,
    required this.legacyDatabase,
    required this.lifecycle,
    required this.databasePath,
    required this.envelopePath,
    required this.legacyDatabasePath,
  });
}

/// Outcome of [EncryptedDatabaseProvider.destroyKeyAndDatabase].
class KeyDestructionReport {
  final bool envelopeDeleted;
  final bool keyDeleted;
  final List<String> databaseFilesDeleted;
  final List<String> databaseFilesRemaining;

  const KeyDestructionReport({
    required this.envelopeDeleted,
    required this.keyDeleted,
    required this.databaseFilesDeleted,
    required this.databaseFilesRemaining,
  });

  /// The key is gone, so any remaining copy of the database bytes is
  /// unreadable. Says nothing about physical sanitization of the medium.
  bool get cryptographicallyErased => envelopeDeleted && keyDeleted;
}

/// The lifecycle refused an operation. Typed; carries no key material.
class EncryptedDatabaseLifecycleError extends StateError {
  final LifecycleRefusal reason;
  EncryptedDatabaseLifecycleError(this.reason) : super('Encrypted database lifecycle refused: ${reason.name}');
}

/// A platform-channel or reply failure outside `open()` (which returns
/// [EncryptedDatabaseFailed] instead). Carries no native exception detail.
class EncryptedStoragePlatformException implements Exception {
  final EncryptedDatabaseFailureCode code;
  const EncryptedStoragePlatformException(this.code);

  @override
  String toString() => 'EncryptedStoragePlatformException(${code.name})';
}

/// One per database (participant, or one test namespace) per isolate, shared
/// by every provider: serialises open, close and destroy.
class _LifecycleOwner {
  Future<void> _tail = Future<void>.value();
  _ActiveConnection? active;

  Future<T> serialized<T>(Future<T> Function() body) {
    final done = Completer<void>();
    final previous = _tail;
    _tail = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }
}

class _ActiveConnection {
  final Database database;
  final String leaseId;
  _ActiveConnection(this.database, this.leaseId);
}

final Expando<Map<String, _LifecycleOwner>> _owners = Expando('sense encrypted database owners');

_LifecycleOwner _ownerFor(SecureKeyPlatform platform, String? testNamespace) {
  final byNamespace = _owners[platform] ??= <String, _LifecycleOwner>{};
  return byNamespace[testNamespace ?? ''] ??= _LifecycleOwner();
}

/// Opens the SQLCipher database (Milestone J). Explicit dependency injection,
/// no global instance; every provider for the same platform and namespace
/// shares one lifecycle owner.
class EncryptedDatabaseProvider {
  final SecureKeyPlatform _platform;
  final UtcClock? _clock;

  /// Debug builds only: isolates on-device tests in their own Keystore alias
  /// and directory. Profile and release builds reject it (here and natively).
  final String? testNamespace;

  /// Normally [currentBuildMode]; injectable for host tests of the policy.
  final BuildMode buildMode;

  EncryptedDatabaseProvider({SecureKeyPlatform? platform, UtcClock? clock, this.testNamespace, BuildMode? buildMode})
      : _platform = platform ?? createDefaultSecureKeyPlatform(),
        _clock = clock,
        buildMode = buildMode ?? currentBuildMode;

  bool get isSupported => _platform.isSupported;

  _LifecycleOwner get _owner => _ownerFor(_platform, testNamespace);

  LifecycleRefusal? get _policyRefusal {
    if (testNamespace == null) {
      return buildMode == BuildMode.release ? null : LifecycleRefusal.buildNotProductionEligible;
    }
    return buildMode == BuildMode.debug ? null : LifecycleRefusal.testNamespaceUnavailable;
  }

  /// Component presence. Returns null where unsupported; throws
  /// [EncryptedStoragePlatformException] on a channel or reply failure.
  Future<EncryptedStorageStatus?> inspect() async {
    if (!_platform.isSupported) return null;
    final Map<String, Object?> r;
    try {
      r = await _platform.inspect(testNamespace: testNamespace);
    } catch (_) {
      throw const EncryptedStoragePlatformException(EncryptedDatabaseFailureCode.platformError);
    }
    final databasePath = r['databasePath'], envelopePath = r['envelopePath'], legacyPath = r['legacyDatabasePath'];
    final lifecycle = r['lifecycle'];
    if (databasePath is! String || envelopePath is! String || legacyPath is! String || lifecycle is! String) {
      throw const EncryptedStoragePlatformException(EncryptedDatabaseFailureCode.malformedReply);
    }
    return EncryptedStorageStatus(
      databasePresent: r['databasePresent'] == true,
      envelopePresent: r['envelopePresent'] == true,
      keyAliasPresent: r['keyAliasPresent'] == true,
      setupPending: r['setupPending'] == true,
      legacyDatabase: _legacy(r['legacyDatabase']),
      lifecycle: lifecycle,
      databasePath: databasePath,
      envelopePath: envelopePath,
      legacyDatabasePath: legacyPath,
    );
  }

  /// Unwraps (or, on the very first call, creates) the key and opens the
  /// encrypted database, creating or migrating schema v2. At most one
  /// connection per database exists: while one is open, every further open
  /// (from any provider) fails with [EncryptedDatabaseFailureCode.databaseAlreadyOpen].
  Future<EncryptedDatabaseOpenResult> open() async {
    if (!_platform.isSupported) {
      return const EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.unsupportedPlatform);
    }
    final refusal = _policyRefusal;
    if (refusal != null) {
      return EncryptedDatabaseFailed(
          refusal == LifecycleRefusal.buildNotProductionEligible
              ? EncryptedDatabaseFailureCode.buildNotProductionEligible
              : EncryptedDatabaseFailureCode.testNamespaceUnavailable,
          refusal: refusal);
    }
    return _owner.serialized(_openSerialized);
  }

  /// Releases the lease of a connection that was closed directly. Returns a
  /// failure if the registered connection is still open.
  Future<EncryptedDatabaseFailed?> _reconcile() async {
    final active = _owner.active;
    if (active == null) return null;
    if (active.database.isOpen) {
      return const EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.databaseAlreadyOpen,
          refusal: LifecycleRefusal.databaseOpen);
    }
    try {
      await _platform.release(active.leaseId, testNamespace: testNamespace);
    } catch (_) {
      return const EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.platformError);
    }
    _owner.active = null;
    return null;
  }

  Future<EncryptedDatabaseOpenResult> _openSerialized() async {
    final busy = await _reconcile();
    if (busy != null) return busy;

    final Map<String, Object?> reply;
    try {
      reply = await _platform.openKey(testNamespace: testNamespace);
    } catch (_) {
      return const EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.platformError);
    }
    final legacy = _legacy(reply['legacyDatabase']);
    final security = _security(reply);
    final status = reply['status'];
    if (status == 'failed') {
      final failure = reply['failure'];
      if (failure is! String) {
        return EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.malformedReply, legacyDatabase: legacy);
      }
      final code = _failure(failure);
      return EncryptedDatabaseFailed(code,
          legacyDatabase: legacy,
          security: security,
          refusal: code == EncryptedDatabaseFailureCode.lifecycleBusy ? _refusal(reply['busyReason']) : null);
    }
    if (status != 'ready') {
      return EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.malformedReply, legacyDatabase: legacy);
    }
    final leaseId = reply['leaseId'];
    if (leaseId is! String || !_leaseFormat.hasMatch(leaseId)) {
      // Without a valid lease id nothing can be released: the native lease (if
      // any) stays held, which keeps destruction refused (fail-safe).
      return EncryptedDatabaseFailed(EncryptedDatabaseFailureCode.malformedReply, legacyDatabase: legacy);
    }

    // From here on, every failure closes any connection and releases the lease.
    Database? db;
    Future<EncryptedDatabaseFailed> fail(EncryptedDatabaseFailureCode code) async {
      final opened = db;
      if (opened != null) {
        try {
          if (opened.isOpen) await opened.close();
        } catch (_) {
          // Closing failed: the lease is still released below only if the
          // connection is no longer open; otherwise it stays held (fail-safe).
          if (opened.isOpen) {
            return EncryptedDatabaseFailed(code, legacyDatabase: legacy, security: security);
          }
        }
      }
      try {
        await _platform.release(leaseId, testNamespace: testNamespace);
      } catch (_) {
        // The native lease stays held; destruction remains refused (fail-safe).
      }
      return EncryptedDatabaseFailed(code, legacyDatabase: legacy, security: security);
    }

    final passphrase = reply['passphrase'];
    final path = reply['databasePath'];
    if (passphrase is! String ||
        !_passphraseFormat.hasMatch(passphrase) ||
        path is! String ||
        !path.endsWith('/$kEncryptedDatabaseFileName') ||
        security == null) {
      return await fail(EncryptedDatabaseFailureCode.invalidKeyMaterial);
    }

    final productionEligible = reply['productionEligible'] == true;
    if (testNamespace == null) {
      // The participant database: native code enforced this already; checked
      // again from the reply's own facts, never from "the key operation worked".
      final hardware = security.hardwareBackedEvidence && !security.emulator && security._reportsSecureHardware;
      if (!productionEligible || !hardware || buildMode != BuildMode.release) {
        return await fail(EncryptedDatabaseFailureCode.insecureKeyStorage);
      }
    }

    // Native code checked this too; checked again immediately before opening.
    try {
      if (await _platform.hasPlaintextSqliteHeader(path)) {
        return await fail(EncryptedDatabaseFailureCode.plaintextDatabaseAtEncryptedPath);
      }
    } on SecureStorageIoException {
      return await fail(EncryptedDatabaseFailureCode.storageError);
    } catch (_) {
      return await fail(EncryptedDatabaseFailureCode.storageError);
    }

    try {
      db = await _platform.openEncrypted(path, passphrase, SenseDatabase.options(clock: _clock));
    } on DatabaseException catch (e) {
      return await fail(_isNotADatabase(e)
          ? EncryptedDatabaseFailureCode.databaseKeyRejected
          : EncryptedDatabaseFailureCode.databaseOpenFailed);
    } catch (_) {
      return await fail(EncryptedDatabaseFailureCode.databaseOpenFailed);
    }
    final database = db;

    // Prove the connection is SQLCipher and the file on disk is not plaintext.
    final String cipherVersion;
    try {
      cipherVersion = await cipherVersionOf(database);
      if (cipherVersion.isEmpty) return await fail(EncryptedDatabaseFailureCode.notEncrypted);
      if (await _platform.hasPlaintextSqliteHeader(path)) return await fail(EncryptedDatabaseFailureCode.notEncrypted);
    } on SecureStorageIoException {
      return await fail(EncryptedDatabaseFailureCode.storageError);
    } catch (_) {
      return await fail(EncryptedDatabaseFailureCode.notEncrypted);
    }

    // Register the connection before the lifecycle lock is released.
    try {
      final committed = await _platform.commitOpen(leaseId, testNamespace: testNamespace);
      if (committed['committed'] != true) {
        return await fail(EncryptedDatabaseFailureCode.lifecycleBusy);
      }
    } catch (_) {
      return await fail(EncryptedDatabaseFailureCode.platformError);
    }
    _owner.active = _ActiveConnection(database, leaseId);
    return EncryptedDatabaseOpened(
      database: database,
      databasePath: path,
      cipherVersion: cipherVersion,
      security: security,
      productionEligible: testNamespace == null && productionEligible,
      firstInitialization: reply['firstInitialization'] == true,
      recoveredMissingDatabase: reply['recoveredMissingDatabase'] == true,
      legacyDatabase: legacy,
      strongBoxFallback: switch (reply['strongBoxFallback']) {
        'strongBoxUnavailable' => StrongBoxFallback.strongBoxUnavailable,
        'strongBoxProviderRejected' => StrongBoxFallback.strongBoxProviderRejected,
        _ => null,
      },
    );
  }

  /// Closes the open connection (if any) and releases its lifecycle lease.
  /// Safe to call repeatedly, and after the database was closed directly.
  Future<void> close() async {
    if (!_platform.isSupported) return;
    await _owner.serialized(() async {
      final active = _owner.active;
      if (active == null) return;
      if (active.database.isOpen) await active.database.close();
      try {
        await _platform.release(active.leaseId, testNamespace: testNamespace);
      } catch (_) {
        // Keep the record so the next lifecycle call retries the release.
        throw const EncryptedStoragePlatformException(EncryptedDatabaseFailureCode.platformError);
      }
      _owner.active = null;
    });
  }

  /// Cryptographic erasure: removes the key envelope, the Keystore alias and
  /// (best effort) the database with its WAL/SHM/journal files.
  ///
  /// Throws [EncryptedDatabaseLifecycleError] (a [StateError]) and changes
  /// nothing while a connection is open or an open is in progress, in this
  /// or any other provider, isolate or Flutter engine of the process. Not
  /// connected to Settings or to `LocalDataService.eraseAllUserData`.
  Future<KeyDestructionReport> destroyKeyAndDatabase() async {
    if (!_platform.isSupported) {
      throw UnsupportedError('Encrypted local storage is not available on this platform.');
    }
    final refusal = _policyRefusal;
    if (refusal != null) throw EncryptedDatabaseLifecycleError(refusal);
    return _owner.serialized(() async {
      final busy = await _reconcile();
      if (busy != null) {
        if (busy.refusal != null) throw EncryptedDatabaseLifecycleError(busy.refusal!);
        throw EncryptedStoragePlatformException(busy.code);
      }
      final Map<String, Object?> r;
      try {
        r = await _platform.destroy(testNamespace: testNamespace);
      } catch (_) {
        throw const EncryptedStoragePlatformException(EncryptedDatabaseFailureCode.platformError);
      }
      final status = r['status'];
      if (status == 'busy') {
        throw EncryptedDatabaseLifecycleError(_refusal(r['busyReason']) ?? LifecycleRefusal.databaseOpen);
      }
      final deleted = r['databaseFilesDeleted'], remaining = r['databaseFilesRemaining'];
      if (status != 'destroyed' || deleted is! List || remaining is! List) {
        throw const EncryptedStoragePlatformException(EncryptedDatabaseFailureCode.malformedReply);
      }
      return KeyDestructionReport(
        envelopeDeleted: r['envelopeDeleted'] == true,
        keyDeleted: r['keyDeleted'] == true,
        databaseFilesDeleted: [for (final f in deleted) '$f'],
        databaseFilesRemaining: [for (final f in remaining) '$f'],
      );
    });
  }

  /// `PRAGMA cipher_version`; empty when the engine is not SQLCipher.
  static Future<String> cipherVersionOf(DatabaseExecutor db) async {
    final rows = await db.rawQuery('PRAGMA cipher_version');
    if (rows.isEmpty) return '';
    final v = rows.first.values.first;
    return v is String ? v : '';
  }

  static bool _isNotADatabase(DatabaseException e) =>
      e.getResultCode() == 26 || e.toString().contains('file is not a database');

  static LegacyDatabaseState _legacy(Object? wire) => switch (wire) {
        'absent' => LegacyDatabaseState.absent,
        'plaintextSqlite' => LegacyDatabaseState.plaintextSqlite,
        'empty' => LegacyDatabaseState.empty,
        _ => LegacyDatabaseState.unrecognized,
      };

  static LifecycleRefusal? _refusal(Object? wire) => switch (wire) {
        'openInProgress' => LifecycleRefusal.openInProgress,
        'databaseOpen' => LifecycleRefusal.databaseOpen,
        'orphanedConnection' => LifecycleRefusal.orphanedConnection,
        'destroyInProgress' => LifecycleRefusal.destroyInProgress,
        _ => null,
      };

  static KeySecurityReport? _security(Map<String, Object?> r) {
    final level = r['securityLevel'];
    if (level is! String) return null;
    return KeySecurityReport(
      reportedLevel: switch (level) {
        'strongBox' => KeySecurityLevel.strongBox,
        'trustedEnvironment' => KeySecurityLevel.trustedEnvironment,
        'hardwareUnspecified' => KeySecurityLevel.hardwareUnspecified,
        'software' => KeySecurityLevel.software,
        _ => KeySecurityLevel.unknown,
      },
      emulator: r['emulator'] == true,
      hardwareBackedEvidence: r['hardwareBackedEvidence'] == true,
    );
  }

  static EncryptedDatabaseFailureCode _failure(String wire) => switch (wire) {
        'buildNotProductionEligible' => EncryptedDatabaseFailureCode.buildNotProductionEligible,
        'lifecycleBusy' => EncryptedDatabaseFailureCode.lifecycleBusy,
        'envelopeMissingForExistingDatabase' => EncryptedDatabaseFailureCode.envelopeMissingForExistingDatabase,
        'keyMissingForExistingDatabase' => EncryptedDatabaseFailureCode.keyMissingForExistingDatabase,
        'keyAndEnvelopeMissingForExistingDatabase' =>
          EncryptedDatabaseFailureCode.keyAndEnvelopeMissingForExistingDatabase,
        'envelopeWithoutKey' => EncryptedDatabaseFailureCode.envelopeWithoutKey,
        'orphanedKey' => EncryptedDatabaseFailureCode.orphanedKey,
        'envelopeMalformed' => EncryptedDatabaseFailureCode.envelopeMalformed,
        'envelopeAuthenticationFailed' => EncryptedDatabaseFailureCode.envelopeAuthenticationFailed,
        'insecureKeyStorage' => EncryptedDatabaseFailureCode.insecureKeyStorage,
        'plaintextDatabaseAtEncryptedPath' => EncryptedDatabaseFailureCode.plaintextDatabaseAtEncryptedPath,
        'initializationFailed' => EncryptedDatabaseFailureCode.initializationFailed,
        _ => EncryptedDatabaseFailureCode.keystoreError,
      };
}
