import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/check_in_record.dart';
import '../models/sleep_record.dart';
import '../models/workload_record.dart';
import '../models/journal_record.dart';
import '../models/user_baseline_record.dart';

/// Database Helper managing local SQLite relational tables.
/// Adheres strictly to the MindPulse Phase 0 Data Dictionary and DPDP Act 2023 data rights.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mindpulse_secure.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Check-ins Table (M1)
    await db.execute('''
      CREATE TABLE check_ins (
        check_in_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        timestamp_utc TEXT NOT NULL,
        session_type TEXT NOT NULL,
        perceived_stress INTEGER NOT NULL,
        mood_valence INTEGER NOT NULL,
        mood_arousal INTEGER NOT NULL,
        motivation_level INTEGER,
        completion_latency_sec REAL NOT NULL
      )
    ''');

    // 2. Sleep Table (M3)
    await db.execute('''
      CREATE TABLE sleep_records (
        sleep_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date_epoch TEXT NOT NULL,
        bedtime_utc TEXT NOT NULL,
        wake_time_utc TEXT NOT NULL,
        total_sleep_minutes INTEGER NOT NULL,
        sleep_quality_rating INTEGER,
        source_type TEXT NOT NULL
      )
    ''');

    // 3. Workload Table (M4)
    await db.execute('''
      CREATE TABLE workload_records (
        workload_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date_epoch TEXT NOT NULL,
        mental_demand_rating INTEGER NOT NULL,
        effort_rating INTEGER NOT NULL,
        tasks_completed_count INTEGER,
        impending_deadlines_count INTEGER
      )
    ''');

    // 4. Text Journal Table (M2 - Encrypted)
    await db.execute('''
      CREATE TABLE journal_entries (
        journal_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        timestamp_utc TEXT NOT NULL,
        raw_text_encrypted TEXT NOT NULL,
        word_count INTEGER NOT NULL,
        sentiment_polarity REAL NOT NULL,
        sentiment_subjectivity REAL NOT NULL
      )
    ''');

    // 5. User Baselines Table
    await db.execute('''
      CREATE TABLE user_baselines (
        baseline_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date_epoch TEXT NOT NULL,
        calibration_day_count INTEGER NOT NULL,
        is_calibrated INTEGER NOT NULL,
        sleep_mean_hours REAL,
        sleep_std_hours REAL,
        stress_mean_rating REAL,
        stress_std_rating REAL,
        workload_mean_rating REAL,
        workload_std_rating REAL
      )
    ''');

    // 6. Consent Settings Table
    await db.execute('''
      CREATE TABLE consent_settings (
        modality_key TEXT PRIMARY KEY,
        is_consented INTEGER NOT NULL,
        updated_timestamp_utc TEXT NOT NULL
      )
    ''');

    // Seed default consent
    final now = DateTime.now().toUtc().toIso8601String();
    for (final mod in ['check_in', 'sleep', 'workload', 'journal', 'voice', 'activity']) {
      await db.insert('consent_settings', {
        'modality_key': mod,
        'is_consented': (mod == 'voice' || mod == 'activity') ? 0 : 1,
        'updated_timestamp_utc': now,
      });
    }
  }

  // Insert Operations
  Future<void> insertCheckIn(CheckInRecord record) async {
    final db = await database;
    await db.insert('check_ins', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSleep(SleepRecord record) async {
    final db = await database;
    await db.insert('sleep_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertWorkload(WorkloadRecord record) async {
    final db = await database;
    await db.insert('workload_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertJournal(JournalRecord record) async {
    final db = await database;
    await db.insert('journal_entries', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertBaseline(UserBaselineRecord record) async {
    final db = await database;
    await db.insert('user_baselines', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Query Operations
  Future<List<CheckInRecord>> getRecentCheckIns(int limit) async {
    final db = await database;
    final maps = await db.query('check_ins', orderBy: 'timestamp_utc DESC', limit: limit);
    return maps.map((m) => CheckInRecord.fromMap(m)).toList();
  }

  Future<List<SleepRecord>> getRecentSleep(int limit) async {
    final db = await database;
    final maps = await db.query('sleep_records', orderBy: 'date_epoch DESC', limit: limit);
    return maps.map((m) => SleepRecord.fromMap(m)).toList();
  }

  Future<UserBaselineRecord?> getLatestBaseline() async {
    final db = await database;
    final maps = await db.query('user_baselines', orderBy: 'date_epoch DESC', limit: 1);
    if (maps.isEmpty) return null;
    return UserBaselineRecord.fromMap(maps.first);
  }

  // DPDP Act 2023 Compliance Operations
  Future<String> exportAllUserDataJson() async {
    final db = await database;
    final checkIns = await db.query('check_ins');
    final sleep = await db.query('sleep_records');
    final workload = await db.query('workload_records');
    final journal = await db.query('journal_entries');
    final baselines = await db.query('user_baselines');

    final exportMap = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'format_version': '1.0',
      'check_ins': checkIns,
      'sleep_records': sleep,
      'workload_records': workload,
      'journal_entries': journal,
      'user_baselines': baselines,
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  Future<void> purgeAllUserData() async {
    final db = await database;
    await db.delete('check_ins');
    await db.delete('sleep_records');
    await db.delete('workload_records');
    await db.delete('journal_entries');
    await db.delete('user_baselines');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

