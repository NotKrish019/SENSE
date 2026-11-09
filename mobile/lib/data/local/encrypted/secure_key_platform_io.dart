// SENSE encrypted local database (Milestone J): dart:io platforms.
//
// Supported on Android only. The key comes from the native Keystore key
// manager over a platform channel; the database is opened by the
// sqflite_sqlcipher driver, whose Android engine is the official SQLCipher
// for Android 4.20.0 (see docs/architecture/encrypted_local_storage.md).
// Other dart:io platforms (desktop, the Dart VM in host tests) report
// unsupported. Nothing here logs.
//
// This is the ONLY file in lib/ that may import sqflite_sqlcipher (enforced
// by test/encrypted_database_provider_test.dart): every connection goes
// through the lifecycle owner in encrypted_database.dart.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import 'secure_key_platform.dart';

SecureKeyPlatform createPlatform() => const AndroidSecureKeyPlatform();

/// The plaintext SQLite file header ("SQLite format 3" and a NUL byte).
const List<int> kPlaintextSqliteHeader = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, //
];

/// The channel returned no reply map. Carries no native detail.
class SecureKeyChannelException implements Exception {
  final String method;
  const SecureKeyChannelException(this.method);

  @override
  String toString() => 'SecureKeyChannelException($method: empty reply)';
}

class AndroidSecureKeyPlatform implements SecureKeyPlatform {
  const AndroidSecureKeyPlatform();

  static const MethodChannel _channel = MethodChannel('org.sense.mindpulse/secure_database');

  @override
  bool get isSupported => Platform.isAndroid;

  Future<Map<String, Object?>> _call(String method, String? testNamespace, [String? leaseId]) async {
    final reply = await _channel.invokeMapMethod<String, Object?>(
      method,
      {
        if (testNamespace != null) 'testNamespace': testNamespace,
        if (leaseId != null) 'leaseId': leaseId,
      },
    );
    if (reply == null) throw SecureKeyChannelException(method);
    return reply;
  }

  @override
  Future<Map<String, Object?>> inspect({String? testNamespace}) => _call('inspect', testNamespace);

  @override
  Future<Map<String, Object?>> openKey({String? testNamespace}) => _call('openKey', testNamespace);

  @override
  Future<Map<String, Object?>> commitOpen(String leaseId, {String? testNamespace}) =>
      _call('commitOpen', testNamespace, leaseId);

  @override
  Future<Map<String, Object?>> release(String leaseId, {String? testNamespace}) =>
      _call('release', testNamespace, leaseId);

  @override
  Future<Map<String, Object?>> destroy({String? testNamespace}) => _call('destroy', testNamespace);

  /// `singleInstance` is deliberately TRUE. The driver keeps native
  /// connections in a process-wide static map that outlives a Flutter engine;
  /// with `singleInstance: false` a connection left by a detached engine could
  /// never be found again and would stay open unowned. The lifecycle owner
  /// guarantees what makes the shared instance safe: one owner per database,
  /// the native policy and key gate before every open (so a cached connection
  /// is never handed out without the gate), and no key change or destruction
  /// while any lease exists.
  @override
  Future<Database> openEncrypted(String path, String passphrase, OpenDatabaseOptions options) => sqlcipher.openDatabase(
        path,
        password: passphrase,
        version: options.version,
        onConfigure: options.onConfigure,
        onCreate: options.onCreate,
        onUpgrade: options.onUpgrade,
        onDowngrade: options.onDowngrade,
        onOpen: options.onOpen,
        readOnly: options.readOnly,
        singleInstance: true,
      );

  @override
  Future<bool> hasPlaintextSqliteHeader(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final raf = await file.open(mode: FileMode.read);
      try {
        final head = await raf.read(kPlaintextSqliteHeader.length);
        if (head.length < kPlaintextSqliteHeader.length) return false;
        for (var i = 0; i < kPlaintextSqliteHeader.length; i++) {
          if (head[i] != kPlaintextSqliteHeader[i]) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } on FileSystemException {
      throw const SecureStorageIoException();
    }
  }
}
