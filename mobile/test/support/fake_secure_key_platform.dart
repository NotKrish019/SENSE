// TEST-ONLY. A fake native key/lifecycle side for host tests of the storage
// owner and persisted consent (Milestone K1).
//
// Host tests cannot reach the Android Keystore or SQLCipher. This fake answers
// the platform channel the way the native side does (status, lease, paths,
// security facts) and opens disposable PLAIN SQLite files with
// sqflite_common_ffi, reporting a SQLCipher version so the provider reaches its
// success path. It lives under test/ only: nothing in lib/ can use it, and the
// app has no plaintext storage path (see the static guards).

import 'dart:io';
import 'dart:math';

import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeSecureKeyPlatform implements SecureKeyPlatform {
  /// Root directory: each namespace gets its own sub-directory (as natively).
  final Directory root;
  final bool supported;

  /// If set, `openKey` answers with this failure code instead of a key.
  String? failWith;

  /// If set, `openKey` waits for it (to observe the opening state).
  Future<void>? openKeyGate;

  /// Overrides the reply's productionEligible flag (defence-in-depth tests).
  bool? productionEligibleOverride;

  /// The reported key facts.
  String securityLevel;
  bool emulator;

  final List<String> calls = [];

  /// The `testNamespace` of every `openKey` call (null = participant).
  final List<String?> openKeyNamespaces = [];
  final List<Database> openedDatabases = [];
  final _random = Random(7);

  FakeSecureKeyPlatform(
    this.root, {
    this.supported = true,
    this.failWith,
    this.securityLevel = 'software',
    this.emulator = true,
  });

  String _dir(String? ns) => '${root.path}/${ns ?? 'participant'}';
  String databasePath(String? ns) => '${_dir(ns)}/sense_encrypted_v1.db';

  String _hex(int bytes) =>
      List.generate(bytes, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  @override
  bool get isSupported => supported;

  @override
  Future<Map<String, Object?>> inspect({String? testNamespace}) async {
    calls.add('inspect');
    return {
      'databasePath': databasePath(testNamespace),
      'envelopePath': '${_dir(testNamespace)}/sense_db_key_v1.envelope',
      'legacyDatabasePath': '${_dir(testNamespace)}/legacy/mindpulse_secure.db',
      'lifecycle': 'idle',
      'databasePresent': File(databasePath(testNamespace)).existsSync(),
    };
  }

  @override
  Future<Map<String, Object?>> openKey({String? testNamespace}) async {
    calls.add('openKey');
    openKeyNamespaces.add(testNamespace);
    if (openKeyGate != null) await openKeyGate;
    final base = {
      'databasePath': databasePath(testNamespace),
      'legacyDatabase': 'absent',
      'securityLevel': securityLevel,
      'emulator': emulator,
      'hardwareBackedEvidence': securityLevel != 'software' && securityLevel != 'unknown' && !emulator,
    };
    final failure = failWith;
    if (failure != null) return {...base, 'status': 'failed', 'failure': failure};
    Directory(_dir(testNamespace)).createSync(recursive: true);
    return {
      ...base,
      'status': 'ready',
      'passphrase': _hex(32),
      'leaseId': _hex(16),
      'productionEligible': productionEligibleOverride ?? false,
      'firstInitialization': !File(databasePath(testNamespace)).existsSync(),
      'recoveredMissingDatabase': false,
    };
  }

  @override
  Future<Map<String, Object?>> commitOpen(String leaseId, {String? testNamespace}) async {
    calls.add('commitOpen');
    return {'committed': true};
  }

  @override
  Future<Map<String, Object?>> release(String leaseId, {String? testNamespace}) async {
    calls.add('release');
    return {'released': true};
  }

  @override
  Future<Map<String, Object?>> destroy({String? testNamespace}) async {
    calls.add('destroy');
    throw UnsupportedError('not used by these tests');
  }

  @override
  Future<Database> openEncrypted(String path, String passphrase, OpenDatabaseOptions options) async {
    calls.add('openEncrypted');
    final db = CipherReportingDatabase(await databaseFactoryFfi.openDatabase(path, options: options));
    openedDatabases.add(db);
    return db;
  }

  @override
  Future<bool> hasPlaintextSqliteHeader(String path) async {
    calls.add('header');
    // The fake's files ARE plain SQLite; report "not plaintext" so the
    // provider's success path can be exercised on the host.
    return false;
  }
}

/// A plain-SQLite database that answers `PRAGMA cipher_version` like
/// SQLCipher and delegates everything else. Host tests only.
class CipherReportingDatabase implements Database {
  final Database inner;
  CipherReportingDatabase(this.inner);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.trim() == 'PRAGMA cipher_version') {
      return [
        {'cipher_version': '4.20.0 community'}
      ];
    }
    return inner.rawQuery(sql, arguments);
  }

  @override
  Database get database => this;
  @override
  String get path => inner.path;
  @override
  bool get isOpen => inner.isOpen;
  @override
  Future<void> close() => inner.close();
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) =>
      inner.transaction(action, exclusive: exclusive);
  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) => inner.readTransaction(action);
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) => inner.execute(sql, arguments);
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) => inner.rawInsert(sql, arguments);
  @override
  Future<int> insert(String table, Map<String, Object?> values,
          {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) =>
      inner.insert(table, values, nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm);
  @override
  Future<List<Map<String, Object?>>> query(String table,
          {bool? distinct,
          List<String>? columns,
          String? where,
          List<Object?>? whereArgs,
          String? groupBy,
          String? having,
          String? orderBy,
          int? limit,
          int? offset}) =>
      inner.query(table,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset);
  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments, {int? bufferSize}) =>
      inner.rawQueryCursor(sql, arguments, bufferSize: bufferSize);
  @override
  Future<QueryCursor> queryCursor(String table,
          {bool? distinct,
          List<String>? columns,
          String? where,
          List<Object?>? whereArgs,
          String? groupBy,
          String? having,
          String? orderBy,
          int? limit,
          int? offset,
          int? bufferSize}) =>
      inner.queryCursor(table,
          distinct: distinct,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
          bufferSize: bufferSize);
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) => inner.rawUpdate(sql, arguments);
  @override
  Future<int> update(String table, Map<String, Object?> values,
          {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) =>
      inner.update(table, values, where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) => inner.rawDelete(sql, arguments);
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      inner.delete(table, where: where, whereArgs: whereArgs);
  @override
  Batch batch() => inner.batch();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}
