// SENSE encrypted local database (Milestone J): platforms without dart:io
// (Chrome / Flutter web). Encrypted storage is unavailable and nothing falls
// back to plaintext; the provider reports `unsupportedPlatform`.

import 'package:sqflite/sqlite_api.dart';

import 'secure_key_platform.dart';

SecureKeyPlatform createPlatform() => const UnsupportedSecureKeyPlatform();

class UnsupportedSecureKeyPlatform implements SecureKeyPlatform {
  const UnsupportedSecureKeyPlatform();

  @override
  bool get isSupported => false;

  Never _unsupported() => throw UnsupportedError('Encrypted local storage is not available on this platform.');

  @override
  Future<Map<String, Object?>> inspect({String? testNamespace}) async => _unsupported();

  @override
  Future<Map<String, Object?>> openKey({String? testNamespace}) async => _unsupported();

  @override
  Future<Map<String, Object?>> commitOpen(String leaseId, {String? testNamespace}) async => _unsupported();

  @override
  Future<Map<String, Object?>> release(String leaseId, {String? testNamespace}) async => _unsupported();

  @override
  Future<Map<String, Object?>> destroy({String? testNamespace}) async => _unsupported();

  @override
  Future<Database> openEncrypted(String path, String passphrase, OpenDatabaseOptions options) async =>
      _unsupported();

  @override
  Future<bool> hasPlaintextSqliteHeader(String path) async => _unsupported();
}
