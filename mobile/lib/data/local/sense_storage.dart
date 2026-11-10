// SENSE application storage owner (Milestone K1).
//
// The one place in the app that holds the encrypted database connection. It
// opens through [EncryptedDatabaseProvider] (which owns the per-isolate
// lifecycle owner, the native lease, the build policy and the Keystore
// checks), binds the existing repositories with [LocalDataStore], and makes
// sure the single active local profile exists.
//
// What it opens:
// * Development storage: an isolated test namespace ([kDevelopmentStorageNamespace])
//   with its own directory, Keystore alias and lifecycle lease. Only in a
//   debuggable debug build AND only with `--dart-define=SENSE_DEV_STORAGE=1`.
//   Never production eligible. Profile and release builds reject it here, in
//   the provider and natively, whatever the define says.
// * Nothing else at startup. The participant database is never opened at
//   startup in this milestone (participant data collection is not connected,
//   and physical-device validation is outstanding). [open] with
//   [StorageTarget.participant] exists for later milestones and is refused by
//   the provider and natively in debug and profile builds; in a release build
//   it additionally requires a hardware-backed key.
//
// Fail closed: any failure leaves the state [StorageUnavailable]. There is no
// plaintext fallback, no retry with another engine, no reset of a database
// that fails to open, and no access to the legacy `mindpulse_secure.db`.
//
// This is the only file under lib/data/local (top level) that imports Flutter,
// and only `foundation` (ChangeNotifier): it is the app-facing owner. The
// records, schema, repositories, store and export/erase service stay pure Dart.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqlite_api.dart';

import 'encrypted/encrypted_database.dart';
import 'local_data_store.dart';

/// `--dart-define=SENSE_DEV_STORAGE=1` was given at build time.
const bool kSenseDevStorageDefine = String.fromEnvironment('SENSE_DEV_STORAGE') == '1';

/// The development storage namespace: `no_backup/test_namespaces/dev_storage/`
/// with Keystore alias `sense_db_wrapping_key_v1__dev_storage`.
const String kDevelopmentStorageNamespace = 'dev_storage';

/// The persistent label shown whenever development storage is enabled.
const String kDevelopmentStorageLabel = 'DEVELOPMENT DATA — NOT FOR PARTICIPANTS';

/// Which encrypted database a [SenseStorage] serves.
enum StorageTarget {
  /// The real participant database. Release builds with a hardware-backed key only.
  participant,

  /// The isolated development namespace. Debug builds with the explicit define only.
  development,
}

/// Why storage is not available. Policy reasons are expected states, not errors.
enum StorageUnavailableReason {
  /// Not started yet.
  notStarted,

  /// Debug build without `--dart-define=SENSE_DEV_STORAGE=1` (the default).
  developmentStorageDisabled,

  /// Release build: participant storage is not connected in this milestone.
  participantStorageNotEnabled,

  /// This build may not open the requested storage (for example profile, or
  /// debug asking for the participant database).
  buildNotEligible,

  /// Not Android (web, desktop, host tests). There is no plaintext fallback.
  unsupportedPlatform,

  /// The encrypted database could not be opened (key, envelope, hardware,
  /// lifecycle or engine failure). See [StorageUnavailable.failureCode].
  openFailed,

  /// The database opened but the local profile could not be read or created.
  profileUnavailable,
}

extension StorageUnavailableReasonKind on StorageUnavailableReason {
  /// True for an actual failure; false for an expected policy state.
  bool get isFailure => switch (this) {
        StorageUnavailableReason.openFailed || StorageUnavailableReason.profileUnavailable => true,
        _ => false,
      };
}

sealed class SenseStorageState {
  const SenseStorageState();
}

final class StorageUnavailable extends SenseStorageState {
  final StorageUnavailableReason reason;

  /// The provider's typed failure, for diagnostics only. Never shown to people.
  final EncryptedDatabaseFailureCode? failureCode;
  const StorageUnavailable(this.reason, {this.failureCode});

  @override
  String toString() => 'StorageUnavailable(${reason.name}${failureCode == null ? '' : ', ${failureCode!.name}'})';
}

final class StorageOpening extends SenseStorageState {
  final StorageTarget target;
  const StorageOpening(this.target);

  @override
  String toString() => 'StorageOpening(${target.name})';
}

final class StorageReady extends SenseStorageState {
  final StorageTarget target;

  /// The one authorized connection. Owned by [SenseStorage]: never close it directly.
  final Database database;

  /// Repositories bound to [database].
  final LocalDataStore store;

  /// The single active pseudonymous local profile.
  final LocalProfile profile;

  /// False for development storage, always.
  final bool productionEligible;
  final String cipherVersion;
  final KeySecurityReport security;

  const StorageReady({
    required this.target,
    required this.database,
    required this.store,
    required this.profile,
    required this.productionEligible,
    required this.cipherVersion,
    required this.security,
  });

  bool get isDevelopment => target == StorageTarget.development;

  @override
  String toString() => 'StorageReady(${target.name}, productionEligible: $productionEligible, $security)';
}

final class StorageClosed extends SenseStorageState {
  const StorageClosed();

  @override
  String toString() => 'StorageClosed()';
}

/// The build facts that decide what [SenseStorage] may open.
class SenseStoragePolicy {
  final BuildMode buildMode;

  /// `--dart-define=SENSE_DEV_STORAGE=1`.
  final bool developmentDefine;

  const SenseStoragePolicy({required this.buildMode, required this.developmentDefine});

  /// The policy of this build.
  factory SenseStoragePolicy.fromEnvironment() =>
      SenseStoragePolicy(buildMode: currentBuildMode, developmentDefine: kSenseDevStorageDefine);

  /// Development storage needs BOTH a debug build and the explicit define.
  bool get developmentStorageEnabled => buildMode == BuildMode.debug && developmentDefine;

  /// What startup opens: the development namespace when enabled, otherwise nothing.
  StorageTarget? get startupTarget => developmentStorageEnabled ? StorageTarget.development : null;

  /// Why startup opens nothing.
  StorageUnavailableReason get startupUnavailableReason => switch (buildMode) {
        BuildMode.debug => StorageUnavailableReason.developmentStorageDisabled,
        BuildMode.profile => StorageUnavailableReason.buildNotEligible,
        BuildMode.release => StorageUnavailableReason.participantStorageNotEnabled,
      };
}

/// Owns the app's single encrypted database connection (Milestone K1).
///
/// Create one per app (not a global), pass it down the widget tree, call
/// [start] once, and [close] on shutdown. Open and close are serialized.
class SenseStorage extends ChangeNotifier {
  final SenseStoragePolicy policy;
  final SecureKeyPlatform _platform;
  final UtcClock? _clock;
  final IdGenerator? _ids;
  final String developmentNamespace;

  SenseStorage({
    required this.policy,
    SecureKeyPlatform? platform,
    UtcClock? clock,
    IdGenerator? ids,
    this.developmentNamespace = kDevelopmentStorageNamespace,
  })  : _platform = platform ?? createDefaultSecureKeyPlatform(),
        _clock = clock,
        _ids = ids;

  SenseStorageState _state = const StorageUnavailable(StorageUnavailableReason.notStarted);
  EncryptedDatabaseProvider? _provider;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  SenseStorageState get state => _state;

  /// The ready state, or null.
  StorageReady? get ready => switch (_state) { final StorageReady r => r, _ => null };

  bool get developmentStorageEnabled => policy.developmentStorageEnabled;

  void _set(SenseStorageState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  Future<T> _serialized<T>(Future<T> Function() body) {
    final done = Completer<void>();
    final previous = _tail;
    _tail = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }

  /// Opens what this build may open at startup: the development namespace
  /// when enabled, otherwise nothing (the state explains why). Never throws.
  Future<SenseStorageState> start() {
    final target = policy.startupTarget;
    if (target == null) {
      return _serialized(() async {
        if (_state is StorageReady || _state is StorageOpening) return _state;
        _set(StorageUnavailable(policy.startupUnavailableReason));
        return _state;
      });
    }
    return open(target);
  }

  /// Opens [target]. A second call while it is open returns the same ready
  /// state (no second connection). Throws [StateError] if a different target
  /// is open. Otherwise never throws: failures become [StorageUnavailable].
  Future<SenseStorageState> open(StorageTarget target) => _serialized(() async {
        final current = _state;
        if (current is StorageReady) {
          if (current.target == target) return current;
          throw StateError('Another storage target is open; close it first.');
        }
        if (_disposed) return _state;

        // Dart-side policy for development storage (the provider and native
        // code enforce the same rule independently).
        if (target == StorageTarget.development && !policy.developmentStorageEnabled) {
          _set(StorageUnavailable(policy.buildMode == BuildMode.debug
              ? StorageUnavailableReason.developmentStorageDisabled
              : StorageUnavailableReason.buildNotEligible));
          return _state;
        }

        _set(StorageOpening(target));
        final provider = EncryptedDatabaseProvider(
          platform: _platform,
          clock: _clock,
          buildMode: policy.buildMode,
          testNamespace: target == StorageTarget.development ? developmentNamespace : null,
        );
        final EncryptedDatabaseOpenResult result;
        try {
          result = await provider.open();
        } catch (_) {
          // open() is documented never to throw; fail closed if it ever does.
          _set(const StorageUnavailable(StorageUnavailableReason.openFailed,
              failureCode: EncryptedDatabaseFailureCode.platformError));
          return _state;
        }
        switch (result) {
          case EncryptedDatabaseFailed(:final code):
            _set(StorageUnavailable(_reasonFor(code), failureCode: code));
            return _state;
          case final EncryptedDatabaseOpened opened:
            // Defence in depth: development storage is never production
            // eligible, and the participant database always must be.
            final eligibleOk = target == StorageTarget.development ? !opened.productionEligible : opened.productionEligible;
            if (!eligibleOk) {
              await _closeQuietly(provider);
              _set(const StorageUnavailable(StorageUnavailableReason.openFailed,
                  failureCode: EncryptedDatabaseFailureCode.insecureKeyStorage));
              return _state;
            }
            final store = LocalDataStore(opened.database, clock: _clock, ids: _ids);
            final LocalProfile profile;
            try {
              profile = await store.profiles.ensureActive();
            } catch (_) {
              await _closeQuietly(provider);
              _set(const StorageUnavailable(StorageUnavailableReason.profileUnavailable));
              return _state;
            }
            _provider = provider;
            _set(StorageReady(
              target: target,
              database: opened.database,
              store: store,
              profile: profile,
              productionEligible: target == StorageTarget.participant && opened.productionEligible,
              cipherVersion: opened.cipherVersion,
              security: opened.security,
            ));
            return _state;
        }
      });

  /// Closes the connection and releases its lifecycle lease. Safe to call
  /// repeatedly. If closing fails the state becomes [StorageUnavailable] and
  /// the lease stays held (destruction stays refused: fail safe).
  Future<void> close() => _serialized(() async {
        final provider = _provider;
        if (_state is! StorageReady || provider == null) return;
        _provider = null;
        try {
          await provider.close();
          _set(const StorageClosed());
        } catch (_) {
          _set(const StorageUnavailable(StorageUnavailableReason.openFailed,
              failureCode: EncryptedDatabaseFailureCode.platformError));
        }
      });

  /// Closes, then disposes. For app shutdown.
  Future<void> shutdown() async {
    await close();
    dispose();
  }

  Future<void> _closeQuietly(EncryptedDatabaseProvider provider) async {
    try {
      await provider.close();
    } catch (_) {
      // The lease stays held: destruction remains refused (fail safe).
    }
  }

  static StorageUnavailableReason _reasonFor(EncryptedDatabaseFailureCode code) => switch (code) {
        EncryptedDatabaseFailureCode.unsupportedPlatform => StorageUnavailableReason.unsupportedPlatform,
        EncryptedDatabaseFailureCode.buildNotProductionEligible ||
        EncryptedDatabaseFailureCode.testNamespaceUnavailable =>
          StorageUnavailableReason.buildNotEligible,
        _ => StorageUnavailableReason.openFailed,
      };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
