// SENSE encrypted local database (Milestone J): the platform boundary.
//
// Android implements this with the native Keystore key manager, the
// process-wide lifecycle registry and the SQLCipher driver
// (secure_key_platform_io.dart). Every other platform, including Chrome, gets
// the unsupported implementation: there is no plaintext fallback anywhere.

import 'package:sqflite/sqlite_api.dart';

import 'secure_key_platform_unsupported.dart'
    if (dart.library.io) 'secure_key_platform_io.dart' as impl;

/// Native key and lifecycle operations and the SQLCipher opener. Replies are
/// plain maps from the platform channel; `EncryptedDatabaseProvider` validates
/// and interprets them. Only the provider should call these: the lease
/// protocol (openKey -> commitOpen/release) is what keeps opening and
/// destruction mutually exclusive.
abstract interface class SecureKeyPlatform {
  /// True only where encrypted storage is implemented (Android).
  bool get isSupported;

  /// Presence of the database, envelope, key alias, setup marker and legacy
  /// file, and the lifecycle state. Creates nothing.
  Future<Map<String, Object?>> inspect({String? testNamespace});

  /// Takes the process-wide lifecycle lease, then runs the native policy gate
  /// and fail-closed state machine; on success the reply holds the
  /// passphrase and the lease id.
  Future<Map<String, Object?>> openKey({String? testNamespace});

  /// The database for [leaseId] was opened and verified.
  Future<Map<String, Object?>> commitOpen(String leaseId, {String? testNamespace});

  /// The open for [leaseId] failed, or its connection was closed.
  Future<Map<String, Object?>> release(String leaseId, {String? testNamespace});

  /// Cryptographic erasure; refused natively while any lease exists.
  Future<Map<String, Object?>> destroy({String? testNamespace});

  /// Opens [path] with SQLCipher using [passphrase] and the schema [options].
  Future<Database> openEncrypted(String path, String passphrase, OpenDatabaseOptions options);

  /// Whether [path] exists and starts with the plaintext SQLite header.
  /// Reads at most 16 bytes; never opens the file as a database. Throws
  /// [SecureStorageIoException] on a file-system error.
  Future<bool> hasPlaintextSqliteHeader(String path);
}

/// The database files could not be read (a file-system error). Carries no
/// path or native detail; platform-neutral so web builds never import dart:io.
class SecureStorageIoException implements Exception {
  const SecureStorageIoException();

  @override
  String toString() => 'SecureStorageIoException';
}

/// The implementation for the current platform.
SecureKeyPlatform createDefaultSecureKeyPlatform() => impl.createPlatform();
