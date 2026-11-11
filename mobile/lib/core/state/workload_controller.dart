import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/sense_storage.dart';

/// Where the Workload form is in its load and save lifecycle (Milestone K2).
enum WorkloadPhase {
  /// Not started.
  idle,

  /// Storage is opening, or today's entry is being read. Save is disabled.
  loading,

  /// Editable; storage is open and today's entry (if any) is loaded.
  editing,

  /// A save is in progress. Save is disabled.
  saving,

  /// The last save created today's entry (the transaction committed).
  saved,

  /// The last save replaced today's existing entry (the transaction committed).
  updated,

  /// The last save was refused because Workload (M4) is off. Nothing was written.
  consentDenied,

  /// This build does not connect storage: the prototype "not saved"
  /// behaviour applies, and nothing is written.
  notConnected,

  /// Storage should be available but is not. Nothing can be written.
  storageUnavailable,

  /// The last read or write failed. Nothing was written by a failed save.
  failed,
}

/// What [WorkloadController.save] did.
enum WorkloadSaveResult {
  saved,
  updated,
  consentDenied,
  notConnected,
  storageUnavailable,
  failed,

  /// The local date changed since the form was loaded: nothing was written,
  /// and the form now shows the new day.
  dayChanged,

  /// Save is not possible right now (still loading).
  notReady,
}

/// Owns the Workload form state and its persistence (Milestone K2).
///
/// Values, ranges and defaults follow ADR-009 Decision D and [WorkloadEntry]:
/// mental demand 1 to 5 (default 3), effort 1 to 5 (default 3), deadlines in
/// the next 48 hours 0 to 20 (default 1).
///
/// Provenance (ADR-009 Decision B): a field counts as changed once the person
/// has adjusted it in this session, even if they move it back to its default
/// (an explicit choice, not an untouched default). When editing today's
/// existing entry, the fields it already records as changed stay changed.
///
/// Writes go only through [WorkloadAccess] (the existing repository, whose M4
/// consent check runs inside the write transaction). The controller never
/// opens a database, never checks consent itself, and shows success only
/// after the transaction committed. One controller per screen; not global.
class WorkloadController extends ChangeNotifier {
  static const int minRating = 1;
  static const int maxRating = 5;
  static const int minDeadlines = 0;
  static const int maxDeadlines = 20;

  static const String fieldMentalDemand = 'mental_demand';
  static const String fieldEffort = 'effort';
  static const String fieldDeadlines = 'deadlines_48h';

  final WorkloadAccess? _access;
  final DateTime Function() _now;

  /// [access] is null when no storage owner is present (the prototype
  /// "not saved" behaviour). [now] returns local time (injected for tests).
  WorkloadController({WorkloadAccess? access, DateTime Function()? now})
      : _access = access,
        _now = now ?? DateTime.now {
    _access?.addListener(_onStorage);
  }

  int _mentalDemand = WorkloadEntry.initialValues[fieldMentalDemand]! as int;
  int _effort = WorkloadEntry.initialValues[fieldEffort]! as int;
  int _deadlines = WorkloadEntry.initialValues[fieldDeadlines]! as int;

  /// Fields the person adjusted in this session.
  final Set<String> _touched = {};

  /// Today's stored entry, once read or written.
  StoredRecord<WorkloadEntry>? _existing;

  /// The local day the form represents (set when today's entry is read).
  LocalDay? _day;

  WorkloadPhase _phase = WorkloadPhase.idle;
  Future<WorkloadSaveResult>? _inFlight;
  int _generation = 0;
  bool _disposed = false;

  int get mentalDemand => _mentalDemand;
  int get effort => _effort;
  int get deadlines => _deadlines;
  WorkloadPhase get phase => _phase;

  /// True when an entry already exists for today (the next save updates it).
  bool get hasExistingEntry => _existing != null;

  /// Today's stored entry, if any (read-only; for status text and tests).
  StoredRecord<WorkloadEntry>? get existingEntry => _existing;

  /// True when saves go to development storage (never participant data).
  bool get isDevelopment => _access?.isDevelopment ?? false;

  /// True when this build writes to encrypted storage at all.
  bool get persistenceConnected => _phase != WorkloadPhase.notConnected;

  /// True once today's entry was read from the storage that is open now.
  bool get todayLoaded => _loaded;

  bool get isBusy => _phase == WorkloadPhase.loading || _phase == WorkloadPhase.saving;

  /// True while a save is in progress: the values are locked, so what is on
  /// screen is exactly what is being written.
  bool get isSaving => _phase == WorkloadPhase.saving;
  bool get canSave => !isBusy && _phase != WorkloadPhase.idle;
  bool get canIncrementDeadlines => !isSaving && _deadlines < maxDeadlines;
  bool get canDecrementDeadlines => !isSaving && _deadlines > minDeadlines;

  /// The fields that will be recorded as changed by the next save.
  Set<String> get changedFields {
    final changed = <String>{...?_existing?.entry.provenance.changedFields, ..._touched};
    // Invariant: a value that differs from its initial default can only have
    // been chosen, so it is never recorded as an untouched default.
    _values.forEach((f, v) {
      if (v != WorkloadEntry.initialValues[f]) changed.add(f);
    });
    return changed;
  }

  Map<String, int> get _values => {fieldMentalDemand: _mentalDemand, fieldEffort: _effort, fieldDeadlines: _deadlines};

  // ---- Lifecycle ---------------------------------------------------------------------------

  /// Reads today's entry if storage is open; otherwise reflects why not.
  /// Call once after creation. Never throws.
  Future<void> start() async {
    if (_access == null) {
      _setPhase(WorkloadPhase.notConnected);
      return;
    }
    await _sync();
  }

  void _onStorage() => unawaited(_sync());

  /// True once today's entry was read from the storage that is open now.
  bool _loaded = false;
  bool _loading = false;

  Future<void> _sync() async {
    final access = _access;
    if (access == null || _disposed) return;
    switch (access.status) {
      case WorkloadStorageStatus.opening:
        _invalidate();
        _setPhase(WorkloadPhase.loading);
      case WorkloadStorageStatus.notConnected:
        _invalidate();
        _setPhase(WorkloadPhase.notConnected);
      case WorkloadStorageStatus.unavailable:
        _invalidate();
        _setPhase(WorkloadPhase.storageUnavailable);
      case WorkloadStorageStatus.open:
        if (_loaded || _loading) return;
        await _load();
    }
  }

  /// Storage changed: anything read or in flight belongs to the old state.
  void _invalidate() {
    _generation++;
    _loaded = false;
  }

  Future<bool> _load() async {
    final access = _access!;
    final generation = ++_generation;
    final day = LocalDay.fromLocal(_now());
    _loading = true;
    _setPhase(WorkloadPhase.loading);
    final WorkloadLoadOutcome outcome;
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
      case WorkloadLoaded(:final record):
        _loaded = true;
        _day = day;
        _adopt(record);
        _setPhase(WorkloadPhase.editing);
        return true;
      case WorkloadLoadUnavailable():
        _setPhase(WorkloadPhase.storageUnavailable);
        return false;
      case WorkloadLoadFailed():
        _setPhase(WorkloadPhase.failed);
        return false;
    }
  }

  /// Takes [record] as today's entry: its values fill every field the person
  /// has not adjusted yet; adjusted fields keep the person's values.
  void _adopt(StoredRecord<WorkloadEntry>? record) {
    _existing = record;
    if (record == null) return;
    final e = record.entry;
    if (!_touched.contains(fieldMentalDemand)) _mentalDemand = e.mentalDemand;
    if (!_touched.contains(fieldEffort)) _effort = e.effort;
    if (!_touched.contains(fieldDeadlines)) _deadlines = e.deadlines48h;
  }

  // ---- Field changes -----------------------------------------------------------------------

  void setMentalDemand(int v) => _change(fieldMentalDemand, _clamp(v, minRating, maxRating));
  void setEffort(int v) => _change(fieldEffort, _clamp(v, minRating, maxRating));

  /// Adds one deadline; ignored at [maxDeadlines].
  void incrementDeadlines() {
    if (canIncrementDeadlines) _change(fieldDeadlines, _deadlines + 1);
  }

  /// Removes one deadline; ignored at [minDeadlines].
  void decrementDeadlines() {
    if (canDecrementDeadlines) _change(fieldDeadlines, _deadlines - 1);
  }

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  void _change(String field, int value) {
    // Locked while saving: the values being written are the ones on screen.
    if (_phase == WorkloadPhase.saving) return;
    if (_values[field] == value) return;
    switch (field) {
      case fieldMentalDemand:
        _mentalDemand = value;
      case fieldEffort:
        _effort = value;
      case fieldDeadlines:
        _deadlines = value;
    }
    _touched.add(field);
    // A finished result no longer describes what is on screen.
    if (_phase == WorkloadPhase.saved ||
        _phase == WorkloadPhase.updated ||
        _phase == WorkloadPhase.consentDenied ||
        (_phase == WorkloadPhase.failed && _loaded)) {
      _phase = WorkloadPhase.editing;
    }
    notifyListeners();
  }

  // ---- Save --------------------------------------------------------------------------------

  /// The entry the next save would write for [day] (the field mapping).
  WorkloadEntry entryFor(LocalDay day, DateTime submittedAtUtc) => WorkloadEntry(
        mentalDemand: _mentalDemand,
        effort: _effort,
        deadlines48h: _deadlines,
        day: day,
        provenance: Provenance.fromChanged(
          allFields: WorkloadEntry.allFields,
          changed: changedFields,
          submittedAtUtc: submittedAtUtc,
        ),
      );

  /// Saves the displayed values for today. While a save is in progress,
  /// further calls return that same save (no second write). Success is
  /// reported only after the transaction committed. The values on screen
  /// are kept whatever the outcome.
  Future<WorkloadSaveResult> save() => _inFlight ??= _save().whenComplete(() => _inFlight = null);

  Future<WorkloadSaveResult> _save() async {
    final access = _access;
    if (access == null || _phase == WorkloadPhase.notConnected) {
      _setPhase(WorkloadPhase.notConnected);
      return WorkloadSaveResult.notConnected;
    }
    if (_phase == WorkloadPhase.loading || _phase == WorkloadPhase.idle) return WorkloadSaveResult.notReady;
    if (access.status != WorkloadStorageStatus.open) {
      await _sync();
      return switch (_phase) {
        WorkloadPhase.notConnected => WorkloadSaveResult.notConnected,
        WorkloadPhase.storageUnavailable => WorkloadSaveResult.storageUnavailable,
        _ => WorkloadSaveResult.notReady,
      };
    }
    // A failed read leaves today's entry unknown: read it again first, so an
    // existing entry's provenance is never lost.
    if (!_loaded) {
      if (!await _load()) {
        return _phase == WorkloadPhase.storageUnavailable
            ? WorkloadSaveResult.storageUnavailable
            : WorkloadSaveResult.failed;
      }
    }

    final now = _now();
    final today = LocalDay.fromLocal(now);
    if (today.date != _day!.date) {
      // The form describes another day: do not write it under today's date.
      _touched.clear();
      _existing = null;
      _resetValues();
      await _load();
      return WorkloadSaveResult.dayChanged;
    }

    final generation = _generation;
    _setPhase(WorkloadPhase.saving);
    final outcome = await access.save(entryFor(_day!, now.toUtc()));
    if (_disposed) return _resultOf(outcome);
    if (generation != _generation) {
      // Storage changed while saving: the outcome no longer applies here.
      if (outcome is WorkloadSaved) _existing = outcome.record;
      return _resultOf(outcome);
    }
    switch (outcome) {
      case WorkloadSaved(:final record, :final updated):
        _existing = record;
        _setPhase(updated ? WorkloadPhase.updated : WorkloadPhase.saved);
      case WorkloadConsentDenied():
        _setPhase(WorkloadPhase.consentDenied);
      case WorkloadSaveUnavailable():
        _setPhase(WorkloadPhase.storageUnavailable);
      case WorkloadSaveInvalid() || WorkloadSaveFailed():
        _setPhase(WorkloadPhase.failed);
    }
    return _resultOf(outcome);
  }

  static WorkloadSaveResult _resultOf(WorkloadSaveOutcome o) => switch (o) {
        WorkloadSaved(:final updated) => updated ? WorkloadSaveResult.updated : WorkloadSaveResult.saved,
        WorkloadConsentDenied() => WorkloadSaveResult.consentDenied,
        WorkloadSaveUnavailable() => WorkloadSaveResult.storageUnavailable,
        WorkloadSaveInvalid() || WorkloadSaveFailed() => WorkloadSaveResult.failed,
      };

  void _resetValues() {
    _mentalDemand = WorkloadEntry.initialValues[fieldMentalDemand]! as int;
    _effort = WorkloadEntry.initialValues[fieldEffort]! as int;
    _deadlines = WorkloadEntry.initialValues[fieldDeadlines]! as int;
  }

  void _setPhase(WorkloadPhase p) {
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
