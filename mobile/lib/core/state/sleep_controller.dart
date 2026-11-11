import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/sense_storage.dart';

/// Where the Sleep form is in its load and save lifecycle (Milestone K4).
enum SleepPhase {
  /// Not started.
  idle,

  /// Storage is opening, or the wake-up day's record is being read. Save is disabled.
  loading,

  /// Editable; storage is open and the wake-up day's record (if any) is loaded.
  editing,

  /// A save is in progress. Every input and Save are locked.
  saving,

  /// The last save created the wake-up day's record (the transaction committed).
  saved,

  /// The last save replaced the wake-up day's existing record (the transaction committed).
  updated,

  /// The last save was refused because Sleep (M3) is off. Nothing was written.
  consentDenied,

  /// The local date changed before Save: nothing was written, the new
  /// wake-up day was read, and the values wait for review and another Save.
  dateChanged,

  /// This build does not connect storage: the prototype "not saved"
  /// behaviour applies, and nothing is written.
  notConnected,

  /// Storage should be available but is not. Nothing can be written.
  storageUnavailable,

  /// The last read or write failed. Nothing was written by a failed save.
  failed,
}

/// What [SleepController.save] did.
enum SleepSaveResult {
  saved,
  updated,
  consentDenied,
  notConnected,
  storageUnavailable,
  failed,

  /// The local date changed since the form was loaded: nothing was written.
  /// The new wake-up day was read; adjusted values are kept, the others show
  /// that day's record or the starting values. Another Save confirms them.
  dayChanged,

  /// The local date changed since the form was loaded: nothing was written,
  /// and the new wake-up day could not be read. The values on screen are
  /// unchanged; the next Save reads the new day first (and still asks for
  /// review before writing).
  dayChangedNotReloaded,

  /// Save is not possible right now (still loading).
  notReady,
}

/// Owns the Sleep answers and their persistence (Milestone K4).
///
/// Values, ranges and defaults follow ADR-009 Decision C and [SleepEntry]:
/// duration 240 to 720 minutes in 30-minute steps (the screen shows 4 to 12
/// hours in half-hour steps; default 450 = 7.5 hours), bedtime and wake time
/// as local wall-clock `HH:MM` strings (defaults 23:30 and 07:00), rest
/// quality 1 to 5 (default 4). Duration is its own answer and is never
/// calculated from the two times.
///
/// The record belongs to the local date of WAKE-UP: the form is "last night's
/// sleep, woke today", so it is read and saved under today's [LocalDay]
/// (bedtime 23:30 yesterday, wake 07:00 today: today's record).
///
/// Provenance (ADR-009 Decision B): a field counts as changed once the person
/// has adjusted it, even if they move it back to its default. When editing
/// the day's existing record, the fields it already records as changed stay
/// changed.
///
/// Writes go only through [SleepAccess] (the existing repository, whose M3
/// consent check runs inside the write transaction). The controller never
/// opens a database, never checks consent itself, and reports success only
/// after the transaction committed. While a save is in progress the values
/// are locked. One controller per screen; not global.
class SleepController extends ChangeNotifier {
  static const int minDurationMinutes = 240;
  static const int maxDurationMinutes = 720;
  static const int durationStepMinutes = 30;
  static const int minQuality = 1;
  static const int maxQuality = 5;

  /// How many wake-up days the recent history covers (including today).
  static const int historyDays = 7;

  static const String fieldDuration = 'duration_minutes';
  static const String fieldBedtime = 'bedtime_local';
  static const String fieldWakeTime = 'wake_time_local';
  static const String fieldQuality = 'rest_quality';

  final SleepAccess? _access;
  final DateTime Function() _now;

  /// [access] is null when no storage owner is present (the prototype
  /// "not saved" behaviour). [now] returns local time (injected for tests).
  SleepController({SleepAccess? access, DateTime Function()? now})
      : _access = access,
        _now = now ?? DateTime.now {
    _access?.addListener(_onStorage);
  }

  // ---- Conversions (pure; no locale) ----------------------------------------------------------

  /// `HH:MM`, zero-padded, 24-hour: (0, 5) is "00:05", (23, 59) is "23:59".
  static String hhmm(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('not a wall-clock time: $hour:$minute');
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static final RegExp _hhmmShape = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// Parses a stored `HH:MM` back into (hour, minute). Throws on any other shape.
  static (int, int) parseHhmm(String s) {
    final m = _hhmmShape.firstMatch(s);
    if (m == null) throw FormatException('not HH:MM: $s');
    return (int.parse(m[1]!), int.parse(m[2]!));
  }

  /// Hours (the slider) to whole minutes on the 30-minute grid, within range:
  /// 4.0 is 240, 7.5 is 450, 12.0 is 720.
  static int minutesFromHours(double hours) {
    final raw = (hours * 60).round();
    final snapped = (raw / durationStepMinutes).round() * durationStepMinutes;
    return snapped.clamp(minDurationMinutes, maxDurationMinutes);
  }

  static double hoursFromMinutes(int minutes) => minutes / 60.0;

  // ---- State ---------------------------------------------------------------------------------

  int _duration = _initialInt(fieldDuration);
  String _bedtime = _initialString(fieldBedtime);
  String _wakeTime = _initialString(fieldWakeTime);
  int _quality = _initialInt(fieldQuality);

  static int _initialInt(String f) => SleepEntry.initialValues[f]! as int;
  static String _initialString(String f) => SleepEntry.initialValues[f]! as String;

  /// Fields the person adjusted.
  final Set<String> _touched = {};

  /// The wake-up day's stored record, once read or written.
  StoredRecord<SleepEntry>? _existing;

  /// The wake-up day the form belongs to (set when its record is read).
  LocalDay? _day;

  /// Recent stored records (oldest first), or null when not available.
  List<StoredRecord<SleepEntry>>? _history;

  SleepPhase _phase = SleepPhase.idle;
  Future<SleepSaveResult>? _inFlight;
  int _generation = 0;
  bool _loaded = false;
  bool _loading = false;
  bool _disposed = false;

  int get durationMinutes => _duration;
  double get durationHours => hoursFromMinutes(_duration);
  String get bedtime => _bedtime;
  String get wakeTime => _wakeTime;
  int get quality => _quality;
  SleepPhase get phase => _phase;

  /// True when a record already exists for the wake-up day (the next save updates it).
  bool get hasExistingEntry => _existing != null;

  /// The wake-up day's stored record, if any (read-only; for status text and tests).
  StoredRecord<SleepEntry>? get existingEntry => _existing;

  /// The wake-up day the form belongs to, once known.
  LocalDay? get wakeDay => _day;

  /// The stored records of the last [historyDays] wake-up days, oldest first;
  /// null when storage is not open or they could not be read.
  List<StoredRecord<SleepEntry>>? get history => _history;

  /// True when saves go to development storage (never participant data).
  bool get isDevelopment => _access?.isDevelopment ?? false;

  /// True when this build writes to encrypted storage at all.
  bool get persistenceConnected => _phase != SleepPhase.notConnected;

  /// True once the wake-up day was read from the storage that is open now.
  bool get dayLoaded => _loaded;

  bool get isBusy => _phase == SleepPhase.loading || _phase == SleepPhase.saving;

  /// True while a save is in progress: the values are locked, so what is on
  /// screen is exactly what is being written.
  bool get isSaving => _phase == SleepPhase.saving;
  bool get canSave => !isBusy && _phase != SleepPhase.idle;

  /// The fields that will be recorded as changed by the next save.
  Set<String> get changedFields {
    final changed = <String>{...?_existing?.entry.provenance.changedFields, ..._touched};
    // Invariant: a value that differs from its initial default can only have
    // been chosen, so it is never recorded as an untouched default.
    _values.forEach((f, v) {
      if (v != SleepEntry.initialValues[f]) changed.add(f);
    });
    return changed;
  }

  Map<String, Object> get _values =>
      {fieldDuration: _duration, fieldBedtime: _bedtime, fieldWakeTime: _wakeTime, fieldQuality: _quality};

  // ---- Lifecycle ---------------------------------------------------------------------------

  /// Reads today's wake-up record (and recent history) if storage is open;
  /// otherwise reflects why not. Call once after creation. Never throws.
  Future<void> start() async {
    if (_access == null) {
      _setPhase(SleepPhase.notConnected);
      return;
    }
    await _sync();
  }

  void _onStorage() => unawaited(_sync());

  Future<void> _sync() async {
    final access = _access;
    if (access == null || _disposed) return;
    switch (access.status) {
      case SleepStorageStatus.opening:
        _invalidate();
        _setPhase(SleepPhase.loading);
      case SleepStorageStatus.notConnected:
        _invalidate();
        _setPhase(SleepPhase.notConnected);
      case SleepStorageStatus.unavailable:
        _invalidate();
        _setPhase(SleepPhase.storageUnavailable);
      case SleepStorageStatus.open:
        if (_loaded || _loading) return;
        await _load();
    }
  }

  /// Storage changed: anything read or in flight belongs to the old state.
  void _invalidate() {
    _generation++;
    _loaded = false;
    _history = null;
  }

  Future<bool> _load() async {
    final access = _access!;
    final generation = ++_generation;
    final day = LocalDay.fromLocal(_now());
    _loading = true;
    _setPhase(SleepPhase.loading);
    final SleepLoadOutcome outcome;
    try {
      outcome = await access.loadDay(day.date);
    } finally {
      _loading = false;
    }
    if (_disposed) return false;
    if (generation != _generation) {
      // Storage changed during the read: follow its current state instead.
      unawaited(_sync());
      return false;
    }
    switch (outcome) {
      case SleepLoaded(:final record):
        _loaded = true;
        _day = day;
        _adopt(record);
        _setPhase(SleepPhase.editing);
        unawaited(_loadHistory());
        return true;
      case SleepLoadUnavailable():
        _loaded = false;
        _setPhase(SleepPhase.storageUnavailable);
        return false;
      case SleepLoadFailed():
        _loaded = false;
        _setPhase(SleepPhase.failed);
        return false;
    }
  }

  /// Reads the stored records of the last [historyDays] wake-up days.
  Future<void> _loadHistory() async {
    final access = _access;
    final day = _day;
    if (access == null || day == null) return;
    final generation = _generation;
    final parts = day.date.split('-').map(int.parse).toList();
    // Calendar arithmetic on the local date (DateTime normalises month ends).
    final from = LocalDay.fromLocal(DateTime(parts[0], parts[1], parts[2] - (historyDays - 1))).date;
    final outcome = await access.loadRange(fromDate: from, toDate: day.date);
    if (_disposed || generation != _generation) return;
    _history = switch (outcome) {
      SleepRangeLoaded(:final records) => List.unmodifiable(records),
      SleepRangeUnavailable() => null,
    };
    notifyListeners();
  }

  /// Takes [record] as the wake-up day's record: its values fill every field
  /// the person has not adjusted; adjusted fields keep the person's values.
  void _adopt(StoredRecord<SleepEntry>? record) {
    _existing = record;
    final e = record?.entry;
    if (!_touched.contains(fieldDuration)) _duration = e?.durationMinutes ?? _initialInt(fieldDuration);
    if (!_touched.contains(fieldBedtime)) _bedtime = e?.bedtimeLocal ?? _initialString(fieldBedtime);
    if (!_touched.contains(fieldWakeTime)) _wakeTime = e?.wakeTimeLocal ?? _initialString(fieldWakeTime);
    if (!_touched.contains(fieldQuality)) _quality = e?.restQuality ?? _initialInt(fieldQuality);
  }

  // ---- Field changes -----------------------------------------------------------------------

  /// The slider's hours, stored as minutes on the 30-minute grid.
  void setDurationHours(double hours) => _change(fieldDuration, minutesFromHours(hours));
  void setBedtime(int hour, int minute) => _change(fieldBedtime, hhmm(hour, minute));
  void setWakeTime(int hour, int minute) => _change(fieldWakeTime, hhmm(hour, minute));
  void setQuality(int v) => _change(fieldQuality, v < minQuality ? minQuality : (v > maxQuality ? maxQuality : v));

  void _change(String field, Object value) {
    // Locked while saving: the values being written are the ones on screen.
    if (_phase == SleepPhase.saving) return;
    if (_values[field] == value) return;
    switch (field) {
      case fieldDuration:
        _duration = value as int;
      case fieldBedtime:
        _bedtime = value as String;
      case fieldWakeTime:
        _wakeTime = value as String;
      case fieldQuality:
        _quality = value as int;
    }
    _touched.add(field);
    // A finished result no longer describes what is on screen.
    if (_phase == SleepPhase.saved ||
        _phase == SleepPhase.updated ||
        _phase == SleepPhase.consentDenied ||
        _phase == SleepPhase.dateChanged ||
        (_phase == SleepPhase.failed && _loaded)) {
      _phase = SleepPhase.editing;
    }
    notifyListeners();
  }

  // ---- Save --------------------------------------------------------------------------------

  /// The entry the next save would write for [day] (the field mapping).
  SleepEntry entryFor(LocalDay day, DateTime submittedAtUtc) => SleepEntry(
        durationMinutes: _duration,
        bedtimeLocal: _bedtime,
        wakeTimeLocal: _wakeTime,
        restQuality: _quality,
        day: day,
        provenance: Provenance.fromChanged(
          allFields: SleepEntry.allFields,
          changed: changedFields,
          submittedAtUtc: submittedAtUtc,
        ),
      );

  /// Saves the displayed values for the form's wake-up day. While a save is
  /// in progress, further calls return that same save (no second write) and
  /// the values are locked. Success is reported only after the transaction
  /// committed. The values on screen are kept whatever the outcome.
  Future<SleepSaveResult> save() => _inFlight ??= _save().whenComplete(() => _inFlight = null);

  Future<SleepSaveResult> _save() async {
    final access = _access;
    if (access == null || _phase == SleepPhase.notConnected) {
      _setPhase(SleepPhase.notConnected);
      return SleepSaveResult.notConnected;
    }
    if (_phase == SleepPhase.loading || _phase == SleepPhase.idle) return SleepSaveResult.notReady;
    if (access.status != SleepStorageStatus.open) {
      await _sync();
      return switch (_phase) {
        SleepPhase.notConnected => SleepSaveResult.notConnected,
        SleepPhase.storageUnavailable => SleepSaveResult.storageUnavailable,
        _ => SleepSaveResult.notReady,
      };
    }
    // An unknown wake-up day (a failed read): read it again first, so an
    // existing record's provenance is never lost.
    if (!_loaded) {
      final shownDay = _day;
      if (!await _load()) {
        return _phase == SleepPhase.storageUnavailable ? SleepSaveResult.storageUnavailable : SleepSaveResult.failed;
      }
      // The re-read landed on another date than the form showed: untouched
      // values may now show that day's record, so the person reviews them
      // before anything is written.
      if (shownDay != null && shownDay.date != _day!.date) {
        _setPhase(SleepPhase.dateChanged);
        return SleepSaveResult.dayChanged;
      }
    }

    final now = _now();
    if (LocalDay.fromLocal(now).date != _day!.date) {
      // Midnight passed: never write these values under a wake-up day they
      // were not given for. Read the new day; adjusted values stay, untouched
      // ones take the new day's record (or the starting values). The person
      // reviews them and saves again.
      if (await _load()) {
        _setPhase(SleepPhase.dateChanged);
        return SleepSaveResult.dayChanged;
      }
      return SleepSaveResult.dayChangedNotReloaded;
    }

    final generation = _generation;
    _setPhase(SleepPhase.saving);
    final outcome = await access.save(entryFor(_day!, now.toUtc()));
    if (_disposed) return _resultOf(outcome);
    if (generation != _generation) {
      // Storage changed while saving: the outcome no longer applies here.
      if (outcome is SleepSaved) _existing = outcome.record;
      return _resultOf(outcome);
    }
    switch (outcome) {
      case SleepSaved(:final record, :final updated):
        _existing = record;
        _setPhase(updated ? SleepPhase.updated : SleepPhase.saved);
        unawaited(_loadHistory());
      case SleepConsentDenied():
        _setPhase(SleepPhase.consentDenied);
      case SleepSaveUnavailable():
        _setPhase(SleepPhase.storageUnavailable);
      case SleepSaveInvalid() || SleepSaveFailed():
        _setPhase(SleepPhase.failed);
    }
    return _resultOf(outcome);
  }

  static SleepSaveResult _resultOf(SleepSaveOutcome o) => switch (o) {
        SleepSaved(:final updated) => updated ? SleepSaveResult.updated : SleepSaveResult.saved,
        SleepConsentDenied() => SleepSaveResult.consentDenied,
        SleepSaveUnavailable() => SleepSaveResult.storageUnavailable,
        SleepSaveInvalid() || SleepSaveFailed() => SleepSaveResult.failed,
      };

  void _setPhase(SleepPhase p) {
    if (_disposed) return;
    _phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _access?.removeListener(_onStorage);
    super.dispose();
  }
}
