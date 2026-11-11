import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/sense_storage.dart';

/// Where the Check-in form is in its load and save lifecycle (Milestone K3).
enum CheckInPhase {
  /// Not started.
  idle,

  /// Storage is opening, or today's check-in is being read. Finish is disabled.
  loading,

  /// Editable; storage is open and today's check-in (if any) is loaded.
  editing,

  /// A save is in progress. Finish is disabled.
  saving,

  /// The last save created today's check-in (the transaction committed).
  saved,

  /// The last save replaced today's existing check-in (the transaction committed).
  updated,

  /// The last save was refused because Structured check-ins (M1) is off.
  consentDenied,

  /// This build does not connect storage: the prototype "not saved"
  /// behaviour applies, and nothing is written.
  notConnected,

  /// Storage should be available but is not. Nothing can be written.
  storageUnavailable,

  /// The last read or write failed. Nothing was written by a failed save.
  failed,
}

/// What [CheckInController.save] did.
enum CheckInSaveResult {
  saved,
  updated,
  consentDenied,
  notConnected,
  storageUnavailable,
  failed,

  /// The local date changed since the form was loaded: nothing was written.
  /// The new day was read: the form now belongs to it. Answers the person
  /// adjusted are kept; the others show the new day's saved check-in or the
  /// starting values. Another Finish confirms them for the new day.
  dayChanged,

  /// The local date changed since the form was loaded: nothing was written,
  /// and the new day could not be read. The answers on screen are unchanged;
  /// the next Finish reads the new day first.
  dayChangedNotReloaded,

  /// Save is not possible right now (still loading).
  notReady,
}

/// Owns the Check-in answers and their persistence (Milestone K3).
///
/// Values, ranges and defaults follow ADR-009 Decision A and [CheckInEntry]:
/// mood 1 to 5 (default 3), motivation/energy 1 to 5 (default 3), perceived
/// stress 1 to 5 (default 2). The screen's two steps are presentation only;
/// the answers and which of them the person adjusted live here, so moving
/// between the steps never loses them.
///
/// Provenance (ADR-009 Decision B): a field counts as changed once the person
/// has adjusted it, even if they move it back to its default. When editing
/// today's existing check-in, the fields it already records as changed stay
/// changed.
///
/// Writes go only through [CheckInAccess] (the existing repository, whose M1
/// consent check runs inside the write transaction). The controller never
/// opens a database, never checks consent itself, and reports success only
/// after the transaction committed. One controller per screen; not global.
class CheckInController extends ChangeNotifier {
  static const int minRating = 1;
  static const int maxRating = 5;

  static const String fieldMood = 'mood_rating';
  static const String fieldMotivation = 'motivation_energy_rating';
  static const String fieldStress = 'perceived_stress_rating';

  final CheckInAccess? _access;
  final DateTime Function() _now;

  /// [access] is null when no storage owner is present (the prototype
  /// "not saved" behaviour). [now] returns local time (injected for tests).
  CheckInController({CheckInAccess? access, DateTime Function()? now})
      : _access = access,
        _now = now ?? DateTime.now {
    _access?.addListener(_onStorage);
  }

  int _mood = _initial(fieldMood);
  int _motivation = _initial(fieldMotivation);
  int _stress = _initial(fieldStress);

  static int _initial(String field) => CheckInEntry.initialValues[field]! as int;

  /// Fields the person adjusted.
  final Set<String> _touched = {};

  /// Today's stored check-in, once read or written.
  StoredRecord<CheckInEntry>? _existing;

  /// The local day the form belongs to (set when its check-in is read).
  LocalDay? _day;

  CheckInPhase _phase = CheckInPhase.idle;
  Future<CheckInSaveResult>? _inFlight;
  int _generation = 0;
  bool _loaded = false;
  bool _loading = false;
  bool _disposed = false;

  int get mood => _mood;
  int get motivation => _motivation;
  int get stress => _stress;
  CheckInPhase get phase => _phase;

  /// True when a check-in already exists for the form's day (the next save updates it).
  bool get hasExistingEntry => _existing != null;

  /// The form's stored check-in, if any (read-only; for status text and tests).
  StoredRecord<CheckInEntry>? get existingEntry => _existing;

  /// The local day the form belongs to, once known.
  LocalDay? get day => _day;

  /// True when saves go to development storage (never participant data).
  bool get isDevelopment => _access?.isDevelopment ?? false;

  /// True when this build writes to encrypted storage at all.
  bool get persistenceConnected => _phase != CheckInPhase.notConnected;

  /// True once the form's day was read from the storage that is open now.
  bool get dayLoaded => _loaded;

  bool get isBusy => _phase == CheckInPhase.loading || _phase == CheckInPhase.saving;

  /// True while a save is in progress: the answers are locked, so what is on
  /// screen is exactly what is being written.
  bool get isSaving => _phase == CheckInPhase.saving;
  bool get canSave => !isBusy && _phase != CheckInPhase.idle;

  /// The fields that will be recorded as changed by the next save.
  Set<String> get changedFields {
    final changed = <String>{...?_existing?.entry.provenance.changedFields, ..._touched};
    // Invariant: a value that differs from its initial default can only have
    // been chosen, so it is never recorded as an untouched default.
    _values.forEach((f, v) {
      if (v != CheckInEntry.initialValues[f]) changed.add(f);
    });
    return changed;
  }

  Map<String, int> get _values => {fieldMood: _mood, fieldMotivation: _motivation, fieldStress: _stress};

  // ---- Lifecycle ---------------------------------------------------------------------------

  /// Reads today's check-in if storage is open; otherwise reflects why not.
  /// Call once after creation. Never throws.
  Future<void> start() async {
    if (_access == null) {
      _setPhase(CheckInPhase.notConnected);
      return;
    }
    await _sync();
  }

  void _onStorage() => unawaited(_sync());

  Future<void> _sync() async {
    final access = _access;
    if (access == null || _disposed) return;
    switch (access.status) {
      case CheckInStorageStatus.opening:
        _invalidate();
        _setPhase(CheckInPhase.loading);
      case CheckInStorageStatus.notConnected:
        _invalidate();
        _setPhase(CheckInPhase.notConnected);
      case CheckInStorageStatus.unavailable:
        _invalidate();
        _setPhase(CheckInPhase.storageUnavailable);
      case CheckInStorageStatus.open:
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
    _setPhase(CheckInPhase.loading);
    final CheckInLoadOutcome outcome;
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
      case CheckInLoaded(:final record):
        _loaded = true;
        _day = day;
        _adopt(record);
        _setPhase(CheckInPhase.editing);
        return true;
      case CheckInLoadUnavailable():
        _loaded = false;
        _setPhase(CheckInPhase.storageUnavailable);
        return false;
      case CheckInLoadFailed():
        _loaded = false;
        _setPhase(CheckInPhase.failed);
        return false;
    }
  }

  /// Takes [record] as the day's check-in: its values fill every field the
  /// person has not adjusted; adjusted fields keep the person's answers.
  void _adopt(StoredRecord<CheckInEntry>? record) {
    _existing = record;
    final e = record?.entry;
    if (!_touched.contains(fieldMood)) _mood = e?.moodRating ?? _initial(fieldMood);
    if (!_touched.contains(fieldMotivation)) _motivation = e?.motivationEnergyRating ?? _initial(fieldMotivation);
    if (!_touched.contains(fieldStress)) _stress = e?.perceivedStressRating ?? _initial(fieldStress);
  }

  // ---- Field changes -----------------------------------------------------------------------

  void setMood(int v) => _change(fieldMood, _clamp(v));
  void setMotivation(int v) => _change(fieldMotivation, _clamp(v));
  void setStress(int v) => _change(fieldStress, _clamp(v));

  static int _clamp(int v) => v < minRating ? minRating : (v > maxRating ? maxRating : v);

  void _change(String field, int value) {
    // Locked while saving: the answers being written are the ones on screen.
    if (_phase == CheckInPhase.saving) return;
    if (_values[field] == value) return;
    switch (field) {
      case fieldMood:
        _mood = value;
      case fieldMotivation:
        _motivation = value;
      case fieldStress:
        _stress = value;
    }
    _touched.add(field);
    // A finished result no longer describes what is on screen.
    if (_phase == CheckInPhase.saved ||
        _phase == CheckInPhase.updated ||
        _phase == CheckInPhase.consentDenied ||
        (_phase == CheckInPhase.failed && _loaded)) {
      _phase = CheckInPhase.editing;
    }
    notifyListeners();
  }

  // ---- Save --------------------------------------------------------------------------------

  /// The entry the next save would write for [day] (the field mapping).
  CheckInEntry entryFor(LocalDay day, DateTime submittedAtUtc) => CheckInEntry(
        moodRating: _mood,
        motivationEnergyRating: _motivation,
        perceivedStressRating: _stress,
        day: day,
        provenance: Provenance.fromChanged(
          allFields: CheckInEntry.allFields,
          changed: changedFields,
          submittedAtUtc: submittedAtUtc,
        ),
      );

  /// Saves the displayed answers for the form's day. While a save is in
  /// progress, further calls return that same save (no second write).
  /// Success is reported only after the transaction committed. The answers
  /// on screen are kept whatever the outcome.
  Future<CheckInSaveResult> save() => _inFlight ??= _save().whenComplete(() => _inFlight = null);

  Future<CheckInSaveResult> _save() async {
    final access = _access;
    if (access == null || _phase == CheckInPhase.notConnected) {
      _setPhase(CheckInPhase.notConnected);
      return CheckInSaveResult.notConnected;
    }
    if (_phase == CheckInPhase.loading || _phase == CheckInPhase.idle) return CheckInSaveResult.notReady;
    if (access.status != CheckInStorageStatus.open) {
      await _sync();
      return switch (_phase) {
        CheckInPhase.notConnected => CheckInSaveResult.notConnected,
        CheckInPhase.storageUnavailable => CheckInSaveResult.storageUnavailable,
        _ => CheckInSaveResult.notReady,
      };
    }
    // A failed read leaves the day's check-in unknown: read it again first,
    // so an existing check-in's provenance is never lost.
    if (!_loaded) {
      final shownDay = _day;
      if (!await _load()) {
        return _phase == CheckInPhase.storageUnavailable ? CheckInSaveResult.storageUnavailable : CheckInSaveResult.failed;
      }
      // The re-read landed on another date than the form showed (midnight
      // passed): untouched answers may now show that day's values, so the
      // person reviews them before anything is written.
      if (shownDay != null && shownDay.date != _day!.date) return CheckInSaveResult.dayChanged;
    }

    final now = _now();
    if (LocalDay.fromLocal(now).date != _day!.date) {
      // Midnight passed: never write these answers under a day they were not
      // given for without the person confirming. Read the new day; the
      // person's adjusted answers stay on screen, untouched fields take the
      // new day's values (or the defaults).
      final reloaded = await _load();
      return reloaded ? CheckInSaveResult.dayChanged : CheckInSaveResult.dayChangedNotReloaded;
    }

    final generation = _generation;
    _setPhase(CheckInPhase.saving);
    final outcome = await access.save(entryFor(_day!, now.toUtc()));
    if (_disposed) return _resultOf(outcome);
    if (generation != _generation) {
      // Storage changed while saving: the outcome no longer applies here.
      if (outcome is CheckInSaved) _existing = outcome.record;
      return _resultOf(outcome);
    }
    switch (outcome) {
      case CheckInSaved(:final record, :final updated):
        _existing = record;
        _setPhase(updated ? CheckInPhase.updated : CheckInPhase.saved);
      case CheckInConsentDenied():
        _setPhase(CheckInPhase.consentDenied);
      case CheckInSaveUnavailable():
        _setPhase(CheckInPhase.storageUnavailable);
      case CheckInSaveInvalid() || CheckInSaveFailed():
        _setPhase(CheckInPhase.failed);
    }
    return _resultOf(outcome);
  }

  static CheckInSaveResult _resultOf(CheckInSaveOutcome o) => switch (o) {
        CheckInSaved(:final updated) => updated ? CheckInSaveResult.updated : CheckInSaveResult.saved,
        CheckInConsentDenied() => CheckInSaveResult.consentDenied,
        CheckInSaveUnavailable() => CheckInSaveResult.storageUnavailable,
        CheckInSaveInvalid() || CheckInSaveFailed() => CheckInSaveResult.failed,
      };

  void _setPhase(CheckInPhase p) {
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
