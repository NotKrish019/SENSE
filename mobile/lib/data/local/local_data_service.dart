// SENSE local data foundation (Milestone C): complete local export and
// transactional erasure.
//
// Pure Dart: no Flutter imports, no file system, no network. The export is
// returned in memory; saving or sharing it is future work. Nothing here logs
// or prints record contents.
//
// TESTED WITH DISPOSABLE DATABASES ONLY. The shipped app does not use this:
// Settings still shows Export and Erase as unavailable, and no production
// code opens the database.
//
// NOT ENCRYPTED, AND ERASE IS LOGICAL ONLY. Erase deletes rows inside one
// SQLite transaction. That is logical database erasure: it does not prove
// that earlier bytes are physically overwritten in database pages, the free
// list, journal or WAL files, backups or the storage medium. It is not
// cryptographic erasure. Secure deletion depends on the future SQLCipher and
// Android Keystore work (key destruction, WAL handling, file lifecycle;
// ADR-009 Decision J).

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqlite_api.dart';

import 'local_data_store.dart';

/// The export document format and its version.
const String kExportFormat = 'sense-local-export';
const int kExportFormatVersion = 1;

/// Current-schema user-data tables, each with its deterministic export order.
/// `local_profile` is the pseudonymous identity; the rest are its records.
const Map<String, String> kUserDataTables = {
  'local_profile': 'created_at_utc ASC, local_person_id ASC',
  'check_ins': 'local_person_id ASC, local_date ASC, id ASC',
  'sleep_records': 'local_person_id ASC, local_date ASC, id ASC',
  'workload_records': 'local_person_id ASC, local_date ASC, id ASC',
  'activity_records': 'local_person_id ASC, local_date ASC, id ASC',
  'consent_events': 'id ASC',
  'baselines': 'local_person_id ASC, variable ASC, local_date ASC, id ASC',
  'observations': 'local_person_id ASC, variable ASC, local_date ASC, id ASC',
};

/// System metadata kept by Erase. `migration_log` holds schema versions,
/// timestamps and legacy table row counts, not record contents or identity.
const Map<String, String> kSystemTables = {'migration_log': 'id ASC'};

/// Tables managed by SQLite or the platform, never exported or erased.
/// (`sqlite_sequence` keeps AUTOINCREMENT counters, so consent event ids keep
/// increasing after an erase.)
bool _isPlatformTable(String name) => name.startsWith('sqlite_') || name == 'android_metadata';

/// Retained legacy tables (ADR-009 Milestone A): strict prefix, plain names.
final RegExp _legacyTableName = RegExp(r'^legacy_v1_[a-z0-9_]+$');

const String _legacyJournalTable = 'legacy_v1_journal_entries';

/// Quotes an SQLite identifier that has already been checked against the
/// schema.
String _quoteIdent(String name) => '"${name.replaceAll('"', '""')}"';

/// Thrown when the database holds a table this service does not recognise.
/// Export and Erase both refuse to run rather than skip possible user data or
/// delete an unknown table.
class UnrecognizedTableException implements Exception {
  final List<String> tables;
  const UnrecognizedTableException(this.tables);
  @override
  String toString() => 'UnrecognizedTableException: unrecognised tables $tables; export/erase refused';
}

/// Thrown when a table has a column the export cannot represent safely (for
/// example a hidden virtual-table column). The export refuses to run rather
/// than silently leave the column out.
class UnsupportedColumnException implements Exception {
  final String table;
  final String column;
  final int hidden;
  const UnsupportedColumnException(this.table, this.column, this.hidden);
  @override
  String toString() =>
      'UnsupportedColumnException: $table.$column has unsupported hidden kind $hidden; export refused';
}

/// One table column from `PRAGMA table_xinfo`, in declared order.
class _Column {
  final String name;

  /// null for an ordinary column, otherwise 'virtual' or 'stored'.
  final String? generated;
  const _Column(this.name, this.generated);
}

/// The outcome of a successful erase. Counts only, never record contents.
class EraseResult {
  final List<String> previousLocalPersonIds;
  final String newLocalPersonId;
  final Map<String, int> deletedRows;
  final DateTime erasedAtUtc;

  const EraseResult({
    required this.previousLocalPersonIds,
    required this.newLocalPersonId,
    required this.deletedRows,
    required this.erasedAtUtc,
  });
}

class _Schema {
  final List<String> legacyTables;
  final Set<String> withoutRowid;
  const _Schema(this.legacyTables, this.withoutRowid);
}

/// Export and erase over one database (Milestone C). No global instance: the
/// caller supplies an already opened [Database].
class LocalDataService {
  final Database _db;
  final UtcClock _now;
  final IdGenerator? _ids;

  /// Optional app version for export metadata. The app has no runtime source
  /// for it without a new dependency, so it is null unless supplied.
  final String? appVersion;

  LocalDataService(this._db, {UtcClock? clock, IdGenerator? ids, this.appVersion})
      : _now = clock ?? (() => DateTime.now().toUtc()),
        _ids = ids;

  // ---- Schema inspection --------------------------------------------------------------------
  static Future<_Schema> _inspect(DatabaseExecutor txn) async {
    final rows = await txn.rawQuery("SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name");
    final legacy = <String>[];
    final withoutRowid = <String>{};
    final unknown = <String>[];
    final present = <String>{};
    for (final r in rows) {
      final name = r['name'] as String;
      present.add(name);
      if ((r['sql'] as String? ?? '').toUpperCase().contains('WITHOUT ROWID')) withoutRowid.add(name);
      if (_isPlatformTable(name) || kUserDataTables.containsKey(name) || kSystemTables.containsKey(name)) continue;
      if (_legacyTableName.hasMatch(name)) {
        legacy.add(name);
      } else {
        unknown.add(name);
      }
    }
    if (unknown.isNotEmpty) throw UnrecognizedTableException(unknown);
    final missing = [...kUserDataTables.keys, ...kSystemTables.keys].where((t) => !present.contains(t)).toList();
    if (missing.isNotEmpty) throw StateError('Expected tables are missing: $missing');
    return _Schema(legacy, withoutRowid);
  }

  /// Every column, generated ones included. `table_info` hides generated
  /// columns, so `table_xinfo` is used. Its `hidden` value is 0 for an
  /// ordinary column, 2 for a VIRTUAL and 3 for a STORED generated column;
  /// anything else (1 = hidden virtual-table column, or an unknown kind) is
  /// refused rather than silently omitted.
  static Future<List<_Column>> _columns(DatabaseExecutor txn, String table) async {
    final info = await txn.rawQuery('PRAGMA table_xinfo(${_quoteIdent(table)})');
    return [
      for (final c in info)
        switch (c['hidden'] as int) {
          0 => _Column(c['name'] as String, null),
          2 => _Column(c['name'] as String, 'virtual'),
          3 => _Column(c['name'] as String, 'stored'),
          final other => throw UnsupportedColumnException(table, c['name'] as String, other),
        },
    ];
  }

  /// JSON-safe value: binary as Base64 and non-finite doubles as text, each
  /// with an explicit type marker; everything else unchanged.
  static Object? _jsonValue(Object? v) {
    if (v is Uint8List) return {r'$type': 'blob', 'encoding': 'base64', 'data': base64Encode(v)};
    if (v is double && !v.isFinite) return {r'$type': 'double', 'value': v.toString()};
    return v;
  }

  static Future<Map<String, Object?>> _dumpTable(DatabaseExecutor txn, String table, String orderBy) async {
    final columns = await _columns(txn, table);
    final names = [for (final c in columns) c.name];
    // Select the columns by name so generated values are read explicitly.
    final rows = await txn
        .rawQuery('SELECT ${names.map(_quoteIdent).join(', ')} FROM ${_quoteIdent(table)} ORDER BY $orderBy');
    final generated = {for (final c in columns) if (c.generated != null) c.name: c.generated};
    return {
      'columns': names,
      if (generated.isNotEmpty) 'generated_columns': generated,
      'row_count': rows.length,
      'rows': [
        for (final r in rows) {for (final c in names) c: _jsonValue(r[c])}
      ],
    };
  }

  static String _legacyOrder(String table, List<_Column> columns, Set<String> withoutRowid) =>
      withoutRowid.contains(table) ? columns.map((c) => _quoteIdent(c.name)).join(', ') : 'rowid ASC';

  // ---- Export --------------------------------------------------------------------------------
  /// Every row of every user-data, legacy and system table, read in one
  /// transaction (a consistent snapshot). Fails with the underlying error if
  /// any query fails; never returns a partial export.
  Future<Map<String, Object?>> exportAllUserData() => _db.transaction((txn) async {
        final schema = await _inspect(txn);
        final version = (await txn.rawQuery('PRAGMA user_version')).first.values.first as int;
        final active = await txn.query('local_profile', where: 'is_active = 1', limit: 1);

        final tables = <String, Object?>{};
        for (final e in kUserDataTables.entries) {
          tables[e.key] = await _dumpTable(txn, e.key, e.value);
        }
        final legacy = <String, Object?>{};
        for (final t in schema.legacyTables) {
          final cols = await _columns(txn, t);
          legacy[t] = await _dumpTable(txn, t, _legacyOrder(t, cols, schema.withoutRowid));
        }
        final system = <String, Object?>{};
        for (final e in kSystemTables.entries) {
          system[e.key] = await _dumpTable(txn, e.key, e.value);
        }

        final warnings = <String>[
          'This export is not encrypted. Store it as sensitive personal data.',
          'Legacy v1 tables are exported exactly as stored and are not converted into current records.',
          if (schema.legacyTables.contains(_legacyJournalTable))
            '$_legacyJournalTable.raw_text_encrypted may contain PLAINTEXT journal text. The column name does not '
                'mean the content is encrypted, and it has not been verified as ciphertext.',
        ];

        return {
          'format': kExportFormat,
          'format_version': kExportFormatVersion,
          'exported_at_utc': utcIso(_now()),
          'schema_version': version,
          'app_version': appVersion,
          'local_profile': active.isEmpty
              ? null
              : {
                  'local_person_id': active.first['local_person_id'],
                  'created_at_utc': active.first['created_at_utc'],
                },
          'warnings': warnings,
          'tables': tables,
          'legacy_v1_tables': legacy,
          'system_metadata': system,
        };
      });

  /// [exportAllUserData] as a JSON string, in memory only.
  Future<String> exportAllUserDataJson() async => jsonEncode(await exportAllUserData());

  // ---- Erase ---------------------------------------------------------------------------------
  /// Deletes every user-data row (all current tables, all `legacy_v1_*`
  /// tables, every local identity) and creates a fresh local identity with
  /// all preferences OFF, in ONE transaction. Any failure rolls back
  /// everything and is rethrown; there is no partial success. Table
  /// structures, `migration_log` and SQLite's own tables are kept.
  Future<EraseResult> eraseAllUserData() => _db.transaction((txn) async {
        final schema = await _inspect(txn);
        final previous = (await txn.query('local_profile', columns: ['local_person_id'], orderBy: 'local_person_id'))
            .map((r) => r['local_person_id'] as String)
            .toList();

        // Children first, then legacy tables, then the identities.
        final order = [
          'consent_events',
          'observations',
          'baselines',
          'check_ins',
          'sleep_records',
          'workload_records',
          'activity_records',
          ...schema.legacyTables,
          'local_profile',
        ];
        final deleted = <String, int>{};
        for (final t in order) {
          deleted[t] = await txn.rawDelete('DELETE FROM ${_quoteIdent(t)}');
        }

        for (final t in order) {
          final n = (await txn.rawQuery('SELECT COUNT(*) AS n FROM ${_quoteIdent(t)}')).first['n'] as int;
          if (n != 0) throw StateError('Erase incomplete: $t still has $n rows');
        }

        final store = LocalDataStore(txn, clock: _now, ids: _ids);
        final fresh = await store.profiles.ensureActive();
        if (previous.contains(fresh.localPersonId)) {
          throw StateError('Erase must start a new local identity');
        }
        final prefs = await store.consent.currentPreferences(fresh.localPersonId);
        if (prefs.length != kModalityCodes.length || prefs.values.any((on) => on)) {
          throw StateError('Erase must leave every preference OFF');
        }

        return EraseResult(
          previousLocalPersonIds: previous,
          newLocalPersonId: fresh.localPersonId,
          deletedRows: Map.unmodifiable(deleted),
          erasedAtUtc: _now(),
        );
      });
}
