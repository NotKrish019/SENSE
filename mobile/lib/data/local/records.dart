// SENSE local data foundation (Milestone A): typed, immutable daily records.
//
// Pure Dart: no Flutter imports. Values, ranges and defaults follow ADR-009
// (M0, 2026-11-08) and the production screens; they are NOT changed here.
//
// DEVELOPMENT / TEST FOUNDATION ONLY. Nothing in the app writes these
// records yet, the database is not encrypted, and journal text has no
// record type at all (ADR-009 Decision F).

import 'dart:convert';

/// Raised when a record does not satisfy its documented constraints.
class DataValidationException implements Exception {
  final String field;
  final String message;
  const DataValidationException(this.field, this.message);

  @override
  String toString() => 'DataValidationException($field): $message';
}

/// Formats a UTC timestamp for storage (ISO 8601 with a trailing Z).
String utcIso(DateTime t) => t.toUtc().toIso8601String();

/// Parses a stored UTC timestamp.
DateTime parseUtc(String s) => DateTime.parse(s).toUtc();

/// The local calendar day a record belongs to, with the device's UTC offset
/// at that moment (ADR-009 Decision H).
class LocalDay {
  /// `YYYY-MM-DD` in the person's local calendar.
  final String date;

  /// Local offset from UTC in minutes (e.g. +330 for India).
  final int tzOffsetMinutes;

  const LocalDay(this.date, this.tzOffsetMinutes);

  /// The local day of a local [DateTime] (not UTC).
  factory LocalDay.fromLocal(DateTime local) {
    if (local.isUtc) {
      throw const DataValidationException('local_date', 'expected a local DateTime, got UTC');
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return LocalDay('${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}',
        local.timeZoneOffset.inMinutes);
  }

  static final RegExp _dateShape = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// True for a real calendar date in `YYYY-MM-DD` form.
  static bool isValidDate(String s) {
    if (!_dateShape.hasMatch(s)) return false;
    final parts = s.split('-').map(int.parse).toList();
    final d = DateTime.utc(parts[0], parts[1], parts[2]);
    return d.year == parts[0] && d.month == parts[1] && d.day == parts[2];
  }

  void validate() {
    if (!isValidDate(date)) throw DataValidationException('local_date', 'not a YYYY-MM-DD date: $date');
    if (tzOffsetMinutes < -840 || tzOffsetMinutes > 840) {
      throw DataValidationException('tz_offset_minutes', 'out of range: $tzOffsetMinutes');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDay && other.date == date && other.tzOffsetMinutes == tzOffsetMinutes;

  @override
  int get hashCode => Object.hash(date, tzOffsetMinutes);
}

/// Where a submitted value came from (ADR-009 Decision B): which fields the
/// person changed, which were left at their initial defaults, and when the
/// explicit Save happened. Untouched defaults are kept as values, but are
/// never indistinguishable from adjusted ones.
class Provenance {
  final Set<String> changedFields;
  final Set<String> defaultFields;
  final bool explicitlySubmitted;
  final DateTime submittedAtUtc;

  Provenance({
    required Set<String> changedFields,
    required Set<String> defaultFields,
    required DateTime submittedAtUtc,
    this.explicitlySubmitted = true,
  })  : changedFields = Set.unmodifiable(changedFields),
        defaultFields = Set.unmodifiable(defaultFields),
        submittedAtUtc = submittedAtUtc.toUtc();

  /// Builds provenance from the fields the person changed; every other field
  /// of the record counts as an untouched default.
  factory Provenance.fromChanged({
    required Set<String> allFields,
    required Set<String> changed,
    required DateTime submittedAtUtc,
    bool explicitlySubmitted = true,
  }) =>
      Provenance(
        changedFields: changed,
        defaultFields: allFields.difference(changed),
        submittedAtUtc: submittedAtUtc,
        explicitlySubmitted: explicitlySubmitted,
      );

  void validateFor(Set<String> allFields) {
    final unknown = changedFields.union(defaultFields).difference(allFields);
    if (unknown.isNotEmpty) throw DataValidationException('changed_fields', 'unknown fields: $unknown');
    final overlap = changedFields.intersection(defaultFields);
    if (overlap.isNotEmpty) throw DataValidationException('changed_fields', 'both changed and default: $overlap');
    final missing = allFields.difference(changedFields.union(defaultFields));
    if (missing.isNotEmpty) throw DataValidationException('changed_fields', 'fields not accounted for: $missing');
  }

  static String encode(Set<String> fields) => jsonEncode(fields.toList()..sort());
  static Set<String> decode(String json) => (jsonDecode(json) as List).cast<String>().toSet();

  @override
  bool operator ==(Object other) =>
      other is Provenance &&
      _setEq(other.changedFields, changedFields) &&
      _setEq(other.defaultFields, defaultFields) &&
      other.explicitlySubmitted == explicitlySubmitted &&
      other.submittedAtUtc == submittedAtUtc;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(changedFields), Object.hashAllUnordered(defaultFields),
      explicitlySubmitted, submittedAtUtc);
}

bool _setEq(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

/// Common shape of the one-per-day records (M1, M3, M4, manual M6).
abstract class DailyEntry {
  LocalDay get day;
  Provenance get provenance;

  /// Field names covered by [provenance].
  Set<String> get fields;

  /// The screen's initial values, used to check untouched defaults.
  Map<String, Object> get defaults;

  /// Current values by field name.
  Map<String, Object> get values;

  /// Shared checks; subclasses add their own ranges.
  void validate() {
    day.validate();
    provenance.validateFor(fields);
    for (final f in provenance.defaultFields) {
      if (values[f] != defaults[f]) {
        throw DataValidationException(f, 'marked as an untouched default but is ${values[f]}, not ${defaults[f]}');
      }
    }
  }
}

void _range(String field, int v, int min, int max, {int step = 1, int origin = 0}) {
  if (v < min || v > max) throw DataValidationException(field, '$v is outside $min to $max');
  if ((v - origin) % step != 0) throw DataValidationException(field, '$v is not on the $step-step grid');
}

// ---- M1 structured check-in ---------------------------------------------------------------
/// M1 (ADR-009 Decision A): three distinct ordinal self-reports, 1 to 5.
/// Mood is NOT valence or arousal; motivation/energy is ONE combined item.
class CheckInEntry extends DailyEntry {
  static const Set<String> allFields = {'mood_rating', 'motivation_energy_rating', 'perceived_stress_rating'};

  /// Production screen defaults (CheckInScreen): mood 3, motivation 3, stress 2.
  static const Map<String, Object> initialValues = {
    'mood_rating': 3,
    'motivation_energy_rating': 3,
    'perceived_stress_rating': 2,
  };

  final int moodRating;
  final int motivationEnergyRating;
  final int perceivedStressRating;
  @override
  final LocalDay day;
  @override
  final Provenance provenance;

  CheckInEntry({
    required this.moodRating,
    required this.motivationEnergyRating,
    required this.perceivedStressRating,
    required this.day,
    required this.provenance,
  });

  @override
  Set<String> get fields => allFields;
  @override
  Map<String, Object> get defaults => initialValues;
  @override
  Map<String, Object> get values => {
        'mood_rating': moodRating,
        'motivation_energy_rating': motivationEnergyRating,
        'perceived_stress_rating': perceivedStressRating,
      };

  @override
  void validate() {
    _range('mood_rating', moodRating, 1, 5);
    _range('motivation_energy_rating', motivationEnergyRating, 1, 5);
    _range('perceived_stress_rating', perceivedStressRating, 1, 5);
    super.validate();
  }
}

// ---- M3 sleep ---------------------------------------------------------------------------------
enum SleepSource { manualLog }

/// M3 (ADR-009 Decision C). Duration is its own answer and is NEVER derived
/// from the two local wall-clock times.
class SleepEntry extends DailyEntry {
  static const Set<String> allFields = {'duration_minutes', 'bedtime_local', 'wake_time_local', 'rest_quality'};

  /// Production screen defaults (SleepScreen): 7.5 h, 23:30, 07:00, quality 4.
  static const Map<String, Object> initialValues = {
    'duration_minutes': 450,
    'bedtime_local': '23:30',
    'wake_time_local': '07:00',
    'rest_quality': 4,
  };

  static final RegExp _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  final int durationMinutes;
  final String bedtimeLocal;
  final String wakeTimeLocal;
  final int restQuality;
  final SleepSource source;
  @override
  final LocalDay day;
  @override
  final Provenance provenance;

  SleepEntry({
    required this.durationMinutes,
    required this.bedtimeLocal,
    required this.wakeTimeLocal,
    required this.restQuality,
    required this.day,
    required this.provenance,
    this.source = SleepSource.manualLog,
  });

  @override
  Set<String> get fields => allFields;
  @override
  Map<String, Object> get defaults => initialValues;
  @override
  Map<String, Object> get values => {
        'duration_minutes': durationMinutes,
        'bedtime_local': bedtimeLocal,
        'wake_time_local': wakeTimeLocal,
        'rest_quality': restQuality,
      };

  @override
  void validate() {
    _range('duration_minutes', durationMinutes, 240, 720, step: 30);
    if (!_hhmm.hasMatch(bedtimeLocal)) throw DataValidationException('bedtime_local', 'not HH:MM: $bedtimeLocal');
    if (!_hhmm.hasMatch(wakeTimeLocal)) throw DataValidationException('wake_time_local', 'not HH:MM: $wakeTimeLocal');
    _range('rest_quality', restQuality, 1, 5);
    super.validate();
  }
}

// ---- M4 workload ------------------------------------------------------------------------------
/// M4 (ADR-009 Decision D). Deadlines 0 to 20 (the data dictionary range is
/// authoritative; the screen's counter must be capped at 20 in Milestone D).
class WorkloadEntry extends DailyEntry {
  static const Set<String> allFields = {'mental_demand', 'effort', 'deadlines_48h'};

  /// Production screen defaults (WorkloadScreen): 3, 3, 1.
  static const Map<String, Object> initialValues = {'mental_demand': 3, 'effort': 3, 'deadlines_48h': 1};

  final int mentalDemand;
  final int effort;
  final int deadlines48h;
  @override
  final LocalDay day;
  @override
  final Provenance provenance;

  WorkloadEntry({
    required this.mentalDemand,
    required this.effort,
    required this.deadlines48h,
    required this.day,
    required this.provenance,
  });

  @override
  Set<String> get fields => allFields;
  @override
  Map<String, Object> get defaults => initialValues;
  @override
  Map<String, Object> get values => {'mental_demand': mentalDemand, 'effort': effort, 'deadlines_48h': deadlines48h};

  @override
  void validate() {
    _range('mental_demand', mentalDemand, 1, 5);
    _range('effort', effort, 1, 5);
    _range('deadlines_48h', deadlines48h, 0, 20);
    super.validate();
  }
}

// ---- M6 manual activity -------------------------------------------------------------------------
enum ActivitySource { manualLog }

/// M6 manual entry (ADR-009 Decision E). Steps 1,000 to 20,000 on a 500 grid,
/// with ONE exception: the untouched initial default 6,800, kept exactly.
/// Active minutes 0 to 120 in steps of 5. Health Connect is not available.
class ActivityEntry extends DailyEntry {
  static const Set<String> allFields = {'steps', 'active_minutes'};

  /// Production screen defaults (ActivityScreen): 6,800 steps, 35 minutes.
  static const int initialSteps = 6800;
  static const Map<String, Object> initialValues = {'steps': initialSteps, 'active_minutes': 35};

  final int steps;
  final int activeMinutes;
  final ActivitySource source;
  @override
  final LocalDay day;
  @override
  final Provenance provenance;

  ActivityEntry({
    required this.steps,
    required this.activeMinutes,
    required this.day,
    required this.provenance,
    this.source = ActivitySource.manualLog,
  });

  /// True when the steps value is the untouched initial 6,800.
  bool get stepsIsInitialDefault => !provenance.changedFields.contains('steps') && steps == initialSteps;

  @override
  Set<String> get fields => allFields;
  @override
  Map<String, Object> get defaults => initialValues;
  @override
  Map<String, Object> get values => {'steps': steps, 'active_minutes': activeMinutes};

  @override
  void validate() {
    if (steps < 1000 || steps > 20000) throw DataValidationException('steps', '$steps is outside 1000 to 20000');
    if (steps % 500 != 0 && !stepsIsInitialDefault) {
      throw DataValidationException(
          'steps', '$steps is not on the 500-step grid (only the untouched initial 6800 is exempt)');
    }
    _range('active_minutes', activeMinutes, 0, 120, step: 5);
    super.validate();
  }
}

// ---- Stored wrapper and identity ----------------------------------------------------------------
/// A daily entry as stored: its row identity and timestamps.
class StoredRecord<T extends DailyEntry> {
  final String id;
  final String localPersonId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int schemaVersion;
  final T entry;

  const StoredRecord({
    required this.id,
    required this.localPersonId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.schemaVersion,
    required this.entry,
  });
}

/// The device-local, PSEUDONYMOUS person identifier (ADR-009 Decision H): a
/// random UUID, no name, email or account. It is not anonymous.
class LocalProfile {
  final String localPersonId;
  final DateTime createdAtUtc;
  const LocalProfile({required this.localPersonId, required this.createdAtUtc});
}

/// The six modality preference identifiers (ADR-009 Decision G).
const List<String> kModalityCodes = ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
