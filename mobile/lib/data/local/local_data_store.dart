// SENSE local data foundation (Milestone A): opening the database and wiring
// the repositories (explicit dependency injection, no global instance).
//
// Pure Dart. The caller supplies the [DatabaseFactory] and path: on Android
// that will be the (future, SQLCipher-backed) plugin factory; tests use
// `sqflite_common_ffi` with a disposable file. Chrome has no SQLite plugin in
// this project and must keep data in memory only (ADR-009 Decision J).
//
// NOT ENCRYPTED, NOT USED BY THE APP. Real participant data must not be
// written until SQLCipher and Android Keystore-backed key management are
// implemented and verified, and consent gating (Milestone B) is in place.

import 'package:sqflite/sqlite_api.dart';

import 'repositories.dart';
import 'schema.dart';
import 'sqlite_repositories.dart';

export 'records.dart';
export 'repositories.dart';
export 'schema.dart' show kSchemaVersion;
export 'sqlite_repositories.dart' show UtcClock, IdGenerator;

/// Legacy file name kept so the v1 -> v2 migration finds a pre-existing
/// database. Despite the name, the file is NOT encrypted.
const String kLocalDatabaseFileName = 'mindpulse_secure.db';

class SenseDatabase {
  SenseDatabase._();

  /// Opens (creating or migrating) the database at [path].
  static Future<Database> open({
    required DatabaseFactory factory,
    required String path,
    UtcClock? clock,
  }) {
    final now = clock ?? () => DateTime.now().toUtc();
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => SenseSchema.create(db, now()),
        onUpgrade: (db, oldVersion, newVersion) => SenseSchema.upgrade(db, oldVersion, newVersion, now()),
      ),
    );
  }
}

/// The repositories bound to one database (or one transaction).
class LocalDataStore {
  final DatabaseExecutor executor;
  final LocalProfileRepository profiles;
  final CheckInRepository checkIns;
  final SleepRepository sleep;
  final WorkloadRepository workload;
  final ActivityRepository activity;
  final ConsentHistoryReader consentHistory;

  LocalDataStore(this.executor, {UtcClock? clock, IdGenerator? ids})
      : profiles = SqliteLocalProfileRepository(executor, clock: clock, ids: ids),
        checkIns = SqliteDailyRecordRepository(executor, CheckInCodec(), clock: clock, ids: ids),
        sleep = SqliteDailyRecordRepository(executor, SleepCodec(), clock: clock, ids: ids),
        workload = SqliteDailyRecordRepository(executor, WorkloadCodec(), clock: clock, ids: ids),
        activity = SqliteDailyRecordRepository(executor, ActivityCodec(), clock: clock, ids: ids),
        consentHistory = SqliteConsentHistoryReader(executor);

  /// Runs [action] with repositories bound to one transaction: everything in
  /// it is committed together or rolled back together.
  static Future<R> transaction<R>(
    Database db,
    Future<R> Function(LocalDataStore store) action, {
    UtcClock? clock,
    IdGenerator? ids,
  }) =>
      db.transaction((txn) => action(LocalDataStore(txn, clock: clock, ids: ids)));
}
