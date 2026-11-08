// SENSE local data foundation (Milestone A): SQLite repository implementations.
//
// Pure Dart (sqflite's platform-independent API). Every daily write runs in a
// transaction that first checks the matching modality preference (Milestone
// B). DEVELOPMENT / TEST FOUNDATION ONLY: not encrypted, not used by the app.

import 'package:sqflite/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import 'consent.dart';
import 'records.dart';
import 'repositories.dart';
import 'schema.dart';

typedef UtcClock = DateTime Function();
typedef IdGenerator = String Function();

DateTime _systemUtc() => DateTime.now().toUtc();
String _uuidV4() => const Uuid().v4();

/// Runs [action] in a transaction, reusing one if [db] already is one.
///
/// sqflite begins transactions with `BEGIN IMMEDIATE`, which takes SQLite's
/// write lock before the first statement, and queues every other operation on
/// the same connection until the transaction ends. A consent check and the
/// write that depends on it therefore see one consistent state: no consent
/// change can commit between them.
Future<R> _inTransaction<R>(DatabaseExecutor db, Future<R> Function(DatabaseExecutor txn) action) {
  if (db is Database) return db.transaction(action);
  return action(db);
}

class SqliteLocalProfileRepository implements LocalProfileRepository {
  final DatabaseExecutor _db;
  final UtcClock _now;
  final IdGenerator _newId;

  SqliteLocalProfileRepository(this._db, {UtcClock? clock, IdGenerator? ids})
      : _now = clock ?? _systemUtc,
        _newId = ids ?? _uuidV4;

  static LocalProfile _fromRow(Map<String, Object?> r) => LocalProfile(
        localPersonId: r['local_person_id'] as String,
        createdAtUtc: parseUtc(r['created_at_utc'] as String),
      );

  @override
  Future<LocalProfile?> active() async {
    final rows = await _db.query('local_profile', where: 'is_active = 1', limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<LocalProfile> ensureActive() => _inTransaction(_db, (txn) async {
        final rows = await txn.query('local_profile', where: 'is_active = 1', limit: 1);
        if (rows.isNotEmpty) return _fromRow(rows.first);
        final profile = LocalProfile(localPersonId: _newId(), createdAtUtc: _now());
        await txn.insert('local_profile', {
          'local_person_id': profile.localPersonId,
          'created_at_utc': utcIso(profile.createdAtUtc),
          'is_active': 1,
        });
        return profile;
      });

  @override
  Future<LocalProfile?> byId(String localPersonId) async {
    final rows = await _db.query('local_profile', where: 'local_person_id = ?', whereArgs: [localPersonId]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<bool> delete(String localPersonId) async =>
      await _db.delete('local_profile', where: 'local_person_id = ?', whereArgs: [localPersonId]) > 0;
}

/// Maps one daily record type to its table.
abstract class DailyTableCodec<T extends DailyEntry> {
  String get table;

  /// The modality preference that must be ON to write this table.
  String get modality => kRequiredModalityByTable[table]!;
  Map<String, Object> columns(T entry);
  T fromRow(Map<String, Object?> row, LocalDay day, Provenance provenance);
}

class SqliteDailyRecordRepository<T extends DailyEntry> implements DailyRecordRepository<T> {
  final DatabaseExecutor _db;
  final DailyTableCodec<T> _codec;
  final UtcClock _now;
  final IdGenerator _newId;

  SqliteDailyRecordRepository(this._db, this._codec, {UtcClock? clock, IdGenerator? ids})
      : _now = clock ?? _systemUtc,
        _newId = ids ?? _uuidV4;

  StoredRecord<T> _fromRow(Map<String, Object?> r) {
    final day = LocalDay(r['local_date'] as String, r['tz_offset_minutes'] as int);
    final provenance = Provenance(
      changedFields: Provenance.decode(r['changed_fields'] as String),
      defaultFields: Provenance.decode(r['default_fields'] as String),
      submittedAtUtc: parseUtc(r['submitted_at_utc'] as String),
      explicitlySubmitted: r['explicitly_submitted'] == 1,
    );
    return StoredRecord<T>(
      id: r['id'] as String,
      localPersonId: r['local_person_id'] as String,
      createdAtUtc: parseUtc(r['created_at_utc'] as String),
      updatedAtUtc: parseUtc(r['updated_at_utc'] as String),
      schemaVersion: r['schema_version'] as int,
      entry: _codec.fromRow(r, day, provenance),
    );
  }

  @override
  Future<StoredRecord<T>> upsert(String localPersonId, T entry) {
    entry.validate();
    return _inTransaction(_db, (txn) async {
      // Authorization first, in the same transaction as the write.
      await requireConsent(txn, localPersonId, _codec.modality);
      final now = _now();
      final existing = await txn.query(_codec.table,
          columns: ['id', 'created_at_utc'],
          where: 'local_person_id = ? AND local_date = ?',
          whereArgs: [localPersonId, entry.day.date]);
      final row = <String, Object>{
        'local_person_id': localPersonId,
        'local_date': entry.day.date,
        'tz_offset_minutes': entry.day.tzOffsetMinutes,
        'updated_at_utc': utcIso(now),
        'submitted_at_utc': utcIso(entry.provenance.submittedAtUtc),
        'schema_version': kSchemaVersion,
        'explicitly_submitted': entry.provenance.explicitlySubmitted ? 1 : 0,
        'changed_fields': Provenance.encode(entry.provenance.changedFields),
        'default_fields': Provenance.encode(entry.provenance.defaultFields),
        ..._codec.columns(entry),
      };
      final String id;
      final DateTime created;
      if (existing.isEmpty) {
        id = _newId();
        created = now;
        await txn.insert(_codec.table, {...row, 'id': id, 'created_at_utc': utcIso(created)},
            conflictAlgorithm: ConflictAlgorithm.abort);
      } else {
        id = existing.first['id'] as String;
        created = parseUtc(existing.first['created_at_utc'] as String);
        await txn.update(_codec.table, row, where: 'id = ?', whereArgs: [id]);
      }
      return StoredRecord<T>(
        id: id,
        localPersonId: localPersonId,
        createdAtUtc: created,
        updatedAtUtc: now,
        schemaVersion: kSchemaVersion,
        entry: entry,
      );
    });
  }

  @override
  Future<StoredRecord<T>?> byDate(String localPersonId, String localDate) async {
    final rows = await _db.query(_codec.table,
        where: 'local_person_id = ? AND local_date = ?', whereArgs: [localPersonId, localDate]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<StoredRecord<T>>> range(String localPersonId, {required String fromDate, required String toDate}) async {
    final rows = await _db.query(_codec.table,
        where: 'local_person_id = ? AND local_date BETWEEN ? AND ?',
        whereArgs: [localPersonId, fromDate, toDate],
        orderBy: 'local_date ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<bool> deleteByDate(String localPersonId, String localDate) => _inTransaction(
      _db,
      (txn) async =>
          await txn.delete(_codec.table,
              where: 'local_person_id = ? AND local_date = ?', whereArgs: [localPersonId, localDate]) >
          0);
}

// ---- Codecs ------------------------------------------------------------------------------------
class CheckInCodec extends DailyTableCodec<CheckInEntry> {
  @override
  String get table => 'check_ins';
  @override
  Map<String, Object> columns(CheckInEntry e) => {
        'mood_rating': e.moodRating,
        'motivation_energy_rating': e.motivationEnergyRating,
        'perceived_stress_rating': e.perceivedStressRating,
      };
  @override
  CheckInEntry fromRow(Map<String, Object?> r, LocalDay day, Provenance p) => CheckInEntry(
        moodRating: r['mood_rating'] as int,
        motivationEnergyRating: r['motivation_energy_rating'] as int,
        perceivedStressRating: r['perceived_stress_rating'] as int,
        day: day,
        provenance: p,
      );
}

class SleepCodec extends DailyTableCodec<SleepEntry> {
  @override
  String get table => 'sleep_records';
  @override
  Map<String, Object> columns(SleepEntry e) => {
        'duration_minutes': e.durationMinutes,
        'bedtime_local': e.bedtimeLocal,
        'wake_time_local': e.wakeTimeLocal,
        'rest_quality': e.restQuality,
        'source': 'MANUAL_LOG',
      };
  @override
  SleepEntry fromRow(Map<String, Object?> r, LocalDay day, Provenance p) {
    if (r['source'] != 'MANUAL_LOG') throw FormatException('Unknown sleep source ${r['source']}');
    return SleepEntry(
      durationMinutes: r['duration_minutes'] as int,
      bedtimeLocal: r['bedtime_local'] as String,
      wakeTimeLocal: r['wake_time_local'] as String,
      restQuality: r['rest_quality'] as int,
      day: day,
      provenance: p,
    );
  }
}

class WorkloadCodec extends DailyTableCodec<WorkloadEntry> {
  @override
  String get table => 'workload_records';
  @override
  Map<String, Object> columns(WorkloadEntry e) =>
      {'mental_demand': e.mentalDemand, 'effort': e.effort, 'deadlines_48h': e.deadlines48h};
  @override
  WorkloadEntry fromRow(Map<String, Object?> r, LocalDay day, Provenance p) => WorkloadEntry(
        mentalDemand: r['mental_demand'] as int,
        effort: r['effort'] as int,
        deadlines48h: r['deadlines_48h'] as int,
        day: day,
        provenance: p,
      );
}

class ActivityCodec extends DailyTableCodec<ActivityEntry> {
  @override
  String get table => 'activity_records';
  @override
  Map<String, Object> columns(ActivityEntry e) => {
        'steps': e.steps,
        'steps_is_initial_default': e.stepsIsInitialDefault ? 1 : 0,
        'active_minutes': e.activeMinutes,
        'source': 'MANUAL_LOG',
      };
  @override
  ActivityEntry fromRow(Map<String, Object?> r, LocalDay day, Provenance p) {
    if (r['source'] != 'MANUAL_LOG') throw FormatException('Unknown activity source ${r['source']}');
    return ActivityEntry(
      steps: r['steps'] as int,
      activeMinutes: r['active_minutes'] as int,
      day: day,
      provenance: p,
    );
  }
}

/// Throws [ConsentDeniedException] unless [localPersonId] exists and the
/// latest event for [modality] enables it. Read with [txn], the executor of
/// the write it guards. Any failure to read the state fails closed.
Future<void> requireConsent(DatabaseExecutor txn, String localPersonId, String modality) async {
  final ConsentEvent? latest = await _readLatestForAuthorization(txn, localPersonId, modality);
  if (latest == null) throw ConsentDeniedException(modality, ConsentDenialReason.notRecorded);
  if (!latest.enabled) throw ConsentDeniedException(modality, ConsentDenialReason.disabled);
}

Future<ConsentEvent?> _readLatestForAuthorization(DatabaseExecutor txn, String localPersonId, String modality) async {
  try {
    validateModality(modality);
    final profile = await txn.query('local_profile',
        columns: ['local_person_id'], where: 'local_person_id = ?', whereArgs: [localPersonId], limit: 1);
    if (profile.isEmpty) throw ConsentDeniedException(modality, ConsentDenialReason.noProfile);
    return await SqliteConsentRepository.latestEvent(txn, localPersonId, modality);
  } on ConsentDeniedException {
    rethrow;
  } catch (e) {
    throw ConsentDeniedException(modality, ConsentDenialReason.unavailable, cause: e);
  }
}

/// Append-only consent history over the `consent_events` table.
class SqliteConsentRepository implements ConsentRepository {
  final DatabaseExecutor _db;
  final UtcClock _now;

  SqliteConsentRepository(this._db, {UtcClock? clock}) : _now = clock ?? _systemUtc;

  static ConsentEvent _fromRow(Map<String, Object?> r) => ConsentEvent(
        id: r['id'] as int,
        localPersonId: r['local_person_id'] as String,
        modality: r['modality'] as String,
        enabled: r['enabled'] == 1,
        changedAtUtc: parseUtc(r['changed_at_utc'] as String),
      );

  /// The event with the highest id for this person and modality, or null.
  static Future<ConsentEvent?> latestEvent(DatabaseExecutor db, String localPersonId, String modality) async {
    final rows = await db.query('consent_events',
        where: 'local_person_id = ? AND modality = ?',
        whereArgs: [localPersonId, modality],
        orderBy: 'id DESC',
        limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<ConsentEvent> recordChange(String localPersonId, String modality, bool enabled) {
    validateModality(modality);
    return _inTransaction(_db, (txn) async {
      final profile = await txn.query('local_profile',
          columns: ['local_person_id'], where: 'local_person_id = ?', whereArgs: [localPersonId], limit: 1);
      if (profile.isEmpty) throw DataValidationException('local_person_id', 'no such local profile');
      final at = _now().toUtc();
      final id = await txn.insert('consent_events', {
        'local_person_id': localPersonId,
        'modality': modality,
        'enabled': enabled ? 1 : 0,
        'changed_at_utc': utcIso(at),
      });
      return ConsentEvent(id: id, localPersonId: localPersonId, modality: modality, enabled: enabled, changedAtUtc: at);
    });
  }

  @override
  Future<bool> isEnabled(String localPersonId, String modality) async {
    validateModality(modality);
    return (await latestEvent(_db, localPersonId, modality))?.enabled ?? false;
  }

  @override
  Future<ConsentSnapshot> snapshot(String localPersonId) async {
    final rows = await _db.rawQuery(
      'SELECT e.* FROM consent_events e '
      'JOIN (SELECT modality, MAX(id) AS last_id FROM consent_events WHERE local_person_id = ? GROUP BY modality) l '
      'ON e.id = l.last_id',
      [localPersonId],
    );
    return ConsentSnapshot(localPersonId, {for (final r in rows) r['modality'] as String: _fromRow(r)});
  }

  @override
  Future<Map<String, bool>> currentPreferences(String localPersonId) async =>
      (await snapshot(localPersonId)).preferences;

  @override
  Future<List<ConsentEvent>> history(String localPersonId, {String? modality}) async {
    if (modality != null) validateModality(modality);
    final rows = await _db.query('consent_events',
        where: modality == null ? 'local_person_id = ?' : 'local_person_id = ? AND modality = ?',
        whereArgs: modality == null ? [localPersonId] : [localPersonId, modality],
        orderBy: 'id ASC');
    return rows.map(_fromRow).toList();
  }
}
