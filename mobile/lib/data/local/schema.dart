// SENSE local data foundation (Milestone A): SQLite schema and migrations.
//
// Pure Dart (sqflite's platform-independent API only).
//
// Version history
//   1  Legacy `DatabaseHelper` schema (never called by the app): check_ins,
//      sleep_records, workload_records, journal_entries, user_baselines,
//      consent_settings (seeded with four inputs ON).
//   2  ADR-009 (M0) schema: local_profile, daily M1/M3/M4/M6 tables with
//      provenance, consent_events (empty = all OFF), baselines, observations,
//      migration_log. No journal table.
//
// Migrations are forward-only and never drop data. 1 -> 2 renames every
// legacy table to `legacy_v1_<name>` (rows untouched) and creates the v2
// tables beside them. Legacy rows are NOT converted: their meaning differs
// (mood valence/arousal is not the M1 mood rating, sleep times were UTC, not
// local wall-clock, no provenance or local person), and reinterpreting them
// is not authorised. `legacy_v1_journal_entries.raw_text_encrypted` is
// preserved verbatim and must be treated as possibly PLAINTEXT, never as
// ciphertext. Milestone C's erase must also clear the legacy tables.
//
// NOT ENCRYPTED. This schema is a development / test foundation; real data
// writes stay blocked until SQLCipher and secure key management are verified
// (ADR-009 Decision J).

import 'package:sqflite/sqlite_api.dart';

import 'records.dart';

/// Current schema version (`PRAGMA user_version`).
const int kSchemaVersion = 2;

/// Legacy table name -> a column that only the legacy definition has, so a
/// re-run never renames a v2 table by mistake.
const Map<String, String> kLegacyV1Tables = {
  'check_ins': 'mood_valence',
  'sleep_records': 'total_sleep_minutes',
  'workload_records': 'mental_demand_rating',
  'journal_entries': 'raw_text_encrypted',
  'user_baselines': 'calibration_day_count',
  'consent_settings': 'is_consented',
};

/// Columns shared by the one-per-day tables.
const String _dailyColumns = '''
  id TEXT PRIMARY KEY CHECK (length(id) = 36),
  local_person_id TEXT NOT NULL REFERENCES local_profile(local_person_id) ON DELETE CASCADE,
  local_date TEXT NOT NULL CHECK (local_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  tz_offset_minutes INTEGER NOT NULL CHECK (tz_offset_minutes BETWEEN -840 AND 840),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  submitted_at_utc TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  explicitly_submitted INTEGER NOT NULL CHECK (explicitly_submitted IN (0, 1)),
  changed_fields TEXT NOT NULL,
  default_fields TEXT NOT NULL,
''';

/// Local wall-clock `HH:MM`, the same rule as the Dart validator
/// (`^([01]\d|2[0-3]):[0-5]\d$`): exactly five characters, ASCII digits,
/// hours 00 to 23, a colon at position 3, minutes 00 to 59. GLOB matches the
/// whole value; the explicit length check documents the intent.
const String _bedtimeCheck = "length(bedtime_local) = 5 AND "
    "(bedtime_local GLOB '[01][0-9]:[0-5][0-9]' OR bedtime_local GLOB '2[0-3]:[0-5][0-9]')";
const String _wakeTimeCheck = "length(wake_time_local) = 5 AND "
    "(wake_time_local GLOB '[01][0-9]:[0-5][0-9]' OR wake_time_local GLOB '2[0-3]:[0-5][0-9]')";

/// The v2 tables, in dependency order. `IF NOT EXISTS` keeps a re-run safe.
const List<String> kV2Statements = [
  '''
CREATE TABLE IF NOT EXISTS migration_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_version INTEGER NOT NULL,
  to_version INTEGER NOT NULL,
  applied_at_utc TEXT NOT NULL,
  notes TEXT NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS local_profile (
  local_person_id TEXT PRIMARY KEY CHECK (length(local_person_id) = 36),
  created_at_utc TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
)''',
  'CREATE UNIQUE INDEX IF NOT EXISTS ux_local_profile_one_active ON local_profile(is_active) WHERE is_active = 1',
  '''
CREATE TABLE IF NOT EXISTS check_ins (
$_dailyColumns
  mood_rating INTEGER NOT NULL CHECK (mood_rating BETWEEN 1 AND 5),
  motivation_energy_rating INTEGER NOT NULL CHECK (motivation_energy_rating BETWEEN 1 AND 5),
  perceived_stress_rating INTEGER NOT NULL CHECK (perceived_stress_rating BETWEEN 1 AND 5),
  UNIQUE (local_person_id, local_date)
)''',
  '''
CREATE TABLE IF NOT EXISTS sleep_records (
$_dailyColumns
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes BETWEEN 240 AND 720 AND duration_minutes % 30 = 0),
  bedtime_local TEXT NOT NULL CHECK ($_bedtimeCheck),
  wake_time_local TEXT NOT NULL CHECK ($_wakeTimeCheck),
  rest_quality INTEGER NOT NULL CHECK (rest_quality BETWEEN 1 AND 5),
  source TEXT NOT NULL CHECK (source = 'MANUAL_LOG'),
  UNIQUE (local_person_id, local_date)
)''',
  '''
CREATE TABLE IF NOT EXISTS workload_records (
$_dailyColumns
  mental_demand INTEGER NOT NULL CHECK (mental_demand BETWEEN 1 AND 5),
  effort INTEGER NOT NULL CHECK (effort BETWEEN 1 AND 5),
  deadlines_48h INTEGER NOT NULL CHECK (deadlines_48h BETWEEN 0 AND 20),
  UNIQUE (local_person_id, local_date)
)''',
  '''
CREATE TABLE IF NOT EXISTS activity_records (
$_dailyColumns
  steps INTEGER NOT NULL CHECK (steps BETWEEN 1000 AND 20000),
  steps_is_initial_default INTEGER NOT NULL CHECK (steps_is_initial_default IN (0, 1)),
  active_minutes INTEGER NOT NULL CHECK (active_minutes BETWEEN 0 AND 120 AND active_minutes % 5 = 0),
  source TEXT NOT NULL CHECK (source = 'MANUAL_LOG'),
  CHECK (steps % 500 = 0 OR (steps = 6800 AND steps_is_initial_default = 1)),
  CHECK (steps_is_initial_default = 0 OR steps = 6800),
  UNIQUE (local_person_id, local_date)
)''',
  // Future Milestone B: append-only preference history. No rows = all OFF.
  '''
CREATE TABLE IF NOT EXISTS consent_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  local_person_id TEXT NOT NULL REFERENCES local_profile(local_person_id) ON DELETE CASCADE,
  modality TEXT NOT NULL CHECK (modality IN ('M1', 'M2', 'M3', 'M4', 'M5', 'M6')),
  enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
  changed_at_utc TEXT NOT NULL
)''',
  'CREATE INDEX IF NOT EXISTS ix_consent_events_person_modality ON consent_events(local_person_id, modality, id)',
  // Future Milestone E: descriptive within-person baselines per variable.
  '''
CREATE TABLE IF NOT EXISTS baselines (
  id TEXT PRIMARY KEY CHECK (length(id) = 36),
  local_person_id TEXT NOT NULL REFERENCES local_profile(local_person_id) ON DELETE CASCADE,
  variable TEXT NOT NULL,
  local_date TEXT NOT NULL CHECK (local_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  window_days INTEGER NOT NULL CHECK (window_days > 0),
  n_points INTEGER NOT NULL CHECK (n_points >= 0),
  location REAL,
  scale REAL,
  calibrated INTEGER NOT NULL CHECK (calibrated IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  UNIQUE (local_person_id, variable, local_date)
)''',
  // Future Milestone E/G: descriptive per-variable observations only. There is
  // deliberately no composite score or alert column (ADR-009 Decisions L, M).
  '''
CREATE TABLE IF NOT EXISTS observations (
  id TEXT PRIMARY KEY CHECK (length(id) = 36),
  local_person_id TEXT NOT NULL REFERENCES local_profile(local_person_id) ON DELETE CASCADE,
  variable TEXT NOT NULL,
  local_date TEXT NOT NULL CHECK (local_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  z_score REAL,
  n_points INTEGER NOT NULL CHECK (n_points >= 0),
  created_at_utc TEXT NOT NULL,
  UNIQUE (local_person_id, variable, local_date)
)''',
];

/// Creates and upgrades the schema.
class SenseSchema {
  SenseSchema._();

  /// A brand-new database: create v2 directly.
  static Future<void> create(DatabaseExecutor db, DateTime nowUtc) async {
    for (final s in kV2Statements) {
      await db.execute(s);
    }
    await _log(db, 0, kSchemaVersion, nowUtc, 'Created schema v$kSchemaVersion.');
  }

  /// Runs every forward migration from [oldVersion] to [newVersion]. sqflite
  /// calls this inside one transaction, so a failure rolls back everything.
  static Future<void> upgrade(DatabaseExecutor db, int oldVersion, int newVersion, DateTime nowUtc) async {
    for (var v = oldVersion; v < newVersion; v++) {
      final step = _migrations[v];
      if (step == null) throw StateError('No migration from schema v$v to v${v + 1}');
      await step(db, nowUtc);
    }
  }

  static final Map<int, Future<void> Function(DatabaseExecutor, DateTime)> _migrations = {
    1: migrateV1ToV2,
  };

  /// 1 -> 2: preserve legacy tables under `legacy_v1_*`, then create v2.
  /// Safe to run more than once.
  static Future<void> migrateV1ToV2(DatabaseExecutor db, DateTime nowUtc) async {
    final preserved = <String>[];
    for (final entry in kLegacyV1Tables.entries) {
      final table = entry.key;
      if (!await _tableHasColumn(db, table, entry.value)) continue; // absent, or already v2
      final target = 'legacy_v1_$table';
      if (await _tableExists(db, target)) {
        throw StateError('Cannot preserve legacy $table: $target already exists');
      }
      final count = (await db.rawQuery('SELECT COUNT(*) AS n FROM "$table"')).first['n'] as int;
      await db.execute('ALTER TABLE "$table" RENAME TO "$target"');
      preserved.add('$table -> $target ($count rows)');
    }
    for (final s in kV2Statements) {
      await db.execute(s);
    }
    await _log(
      db,
      1,
      2,
      nowUtc,
      preserved.isEmpty
          ? 'No legacy v1 tables found; created schema v2.'
          : 'Preserved legacy tables unchanged (not converted): ${preserved.join('; ')}. '
              'legacy_v1_journal_entries.raw_text_encrypted may contain plaintext and is not ciphertext. '
              'legacy_v1_consent_settings is never read; preferences start OFF.',
    );
  }

  static Future<void> _log(DatabaseExecutor db, int from, int to, DateTime nowUtc, String notes) =>
      db.insert('migration_log', {
        'from_version': from,
        'to_version': to,
        'applied_at_utc': utcIso(nowUtc),
        'notes': notes,
      });

  static Future<bool> _tableExists(DatabaseExecutor db, String table) async =>
      (await db.rawQuery("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [table])).isNotEmpty;

  static Future<bool> _tableHasColumn(DatabaseExecutor db, String table, String column) async {
    if (!await _tableExists(db, table)) return false;
    final cols = await db.rawQuery('PRAGMA table_info("$table")');
    return cols.any((c) => c['name'] == column);
  }
}
