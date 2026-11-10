import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/sense_storage.dart';

/// The six optional SENSE input categories (M1–M6).
enum InputModality { checkIn, journal, sleep, workload, voice, activity }

extension InputModalityLabel on InputModality {
  /// The persisted modality identifier (ADR-009 Decision G): M1 to M6.
  String get code => 'M${index + 1}';

  String get title {
    switch (this) {
      case InputModality.checkIn:
        return 'Structured check-ins';
      case InputModality.journal:
        return 'Journal';
      case InputModality.sleep:
        return 'Sleep';
      case InputModality.workload:
        return 'Workload';
      case InputModality.voice:
        return 'Voice';
      case InputModality.activity:
        return 'Physical activity';
    }
  }

  /// True when the prototype has a working (manual-entry) screen for this
  /// input. Voice is planned only: no audio is ever recorded.
  bool get isAvailableInPrototype => this != InputModality.voice;
}

/// Where the preferences currently live.
enum ConsentPersistence {
  /// Not connected to storage (the default, and whenever storage is
  /// disabled by policy). Choices last only while the app is open.
  memoryOnly,

  /// Storage is opening or the saved preferences are being read. Changes
  /// are not accepted until the saved state is known.
  loading,

  /// Read from the encrypted database; every change is saved (an appended
  /// consent event) before it is shown.
  persisted,

  /// Storage should be available but is not (an open or read failure).
  /// Choices are kept in memory only and are not saved.
  storageUnavailable,
}

/// The outcome of [ConsentPreferences.setEnabled].
enum ConsentChangeResult {
  /// The value was already set; nothing was recorded.
  unchanged,

  /// Changed in memory only (not saved).
  heldInMemory,

  /// Saved: one consent event was appended, then the value was shown.
  saved,

  /// Saving failed: nothing changed, and the previous value is still shown.
  failed,

  /// Saved preferences are still loading: nothing changed.
  notReady,
}

/// Consent *preferences* for the six inputs (ADR-009 Decision G).
///
/// * Every modality starts OFF and stays OFF until the person turns it on.
/// * By default nothing here is persisted: choices last only while the app is
///   open ([ConsentPersistence.memoryOnly]).
/// * While [attach]ed to a [SenseStorage] that is ready, the saved preferences
///   are loaded from the existing append-only `ConsentRepository` and replace
///   whatever was in memory. Each change appends ONE consent event and is
///   shown only after that write succeeded; a failed write changes nothing.
///   Turning a preference off appends an OFF event before it is shown as off.
///
/// These values never authorize a database write: the repositories check the
/// persisted consent events inside each write transaction, whatever this
/// object shows. They are not formal research-participation consent and not
/// operating-system permissions.
class ConsentPreferences extends ChangeNotifier {
  /// A separate instance (tests, or an explicitly injected model).
  ConsentPreferences();

  /// The app's shared instance, so onboarding, Consent and Settings show the
  /// same choices. It holds no database connection: [SenseStorage] does.
  static final ConsentPreferences instance = ConsentPreferences();

  // Everything starts OFF: consent must be an active choice, never pre-ticked.
  final Map<InputModality, bool> _enabled = {
    for (final m in InputModality.values) m: false,
  };
  final Set<InputModality> _pending = {};

  SenseStorage? _storage;
  StorageReady? _loadedFrom;
  int _generation = 0;
  ConsentPersistence _persistence = ConsentPersistence.memoryOnly;
  Future<void> _writes = Future<void>.value();

  bool isEnabled(InputModality m) => _enabled[m] ?? false;

  int get enabledCount => _enabled.values.where((v) => v).length;

  ConsentPersistence get persistence => _persistence;

  /// True while a change to [m] is being saved.
  bool isPending(InputModality m) => _pending.contains(m);

  /// True when the saved preferences live in development storage.
  bool get isDevelopmentStorage => _persistence == ConsentPersistence.persisted && (_loadedFrom?.isDevelopment ?? false);

  /// True when development storage is enabled for this build (even if it is
  /// not open yet).
  bool get developmentStorageEnabled => _storage?.developmentStorageEnabled ?? false;

  /// A short honest note for status text: where the choices are kept.
  String get savedStateNote => switch (_persistence) {
        ConsentPersistence.persisted =>
          isDevelopmentStorage ? 'saved to development storage' : 'saved on this device',
        ConsentPersistence.loading => 'loading saved choices',
        _ => 'not saved',
      };

  /// Changes one preference.
  ///
  /// In memory ([ConsentPersistence.memoryOnly] or
  /// [ConsentPersistence.storageUnavailable]) the value changes at once.
  /// When persisted, one consent event is appended first and the value
  /// changes only if that write succeeded. Changes are applied in order.
  Future<ConsentChangeResult> setEnabled(InputModality m, bool value) {
    switch (_persistence) {
      case ConsentPersistence.memoryOnly:
      case ConsentPersistence.storageUnavailable:
        if (_enabled[m] == value) return Future.value(ConsentChangeResult.unchanged);
        _enabled[m] = value;
        notifyListeners();
        return Future.value(ConsentChangeResult.heldInMemory);
      case ConsentPersistence.loading:
        return Future.value(ConsentChangeResult.notReady);
      case ConsentPersistence.persisted:
        final result = _writes.then((_) => _persist(m, value));
        _writes = result.then((_) {});
        return result;
    }
  }

  Future<ConsentChangeResult> _persist(InputModality m, bool value) async {
    final ready = _loadedFrom;
    final generation = _generation;
    if (_persistence != ConsentPersistence.persisted || ready == null) return ConsentChangeResult.failed;
    if (_enabled[m] == value) return ConsentChangeResult.unchanged;
    _pending.add(m);
    notifyListeners();
    try {
      final event = await ready.store.consent.recordChange(ready.profile.localPersonId, m.code, value);
      // Shown only if the storage this was loaded from is still current.
      if (generation != _generation) return ConsentChangeResult.failed;
      _enabled[m] = event.enabled;
      return ConsentChangeResult.saved;
    } catch (_) {
      // No detail is kept or shown: nothing was saved and nothing changed.
      return ConsentChangeResult.failed;
    } finally {
      _pending.remove(m);
      notifyListeners();
    }
  }

  /// Connects to [storage]. Whenever it is ready, the saved preferences are
  /// loaded and become authoritative; when it is not, choices are in memory.
  void attach(SenseStorage storage) {
    if (identical(_storage, storage)) return;
    detach();
    _storage = storage;
    storage.addListener(_onStorage);
    _onStorage();
  }

  /// Disconnects from storage. Persisted values are not kept in memory.
  void detach() {
    final s = _storage;
    if (s == null) return;
    s.removeListener(_onStorage);
    _storage = null;
    _becomeInMemory(ConsentPersistence.memoryOnly);
  }

  void _onStorage() {
    final s = _storage;
    if (s == null) return;
    switch (s.state) {
      case final StorageReady ready:
        if (identical(_loadedFrom, ready) && _persistence == ConsentPersistence.persisted) return;
        unawaited(_load(ready));
      case StorageOpening():
        _generation++;
        _loadedFrom = null;
        _persistence = ConsentPersistence.loading;
        notifyListeners();
      case StorageUnavailable(:final reason):
        _becomeInMemory(reason.isFailure ? ConsentPersistence.storageUnavailable : ConsentPersistence.memoryOnly);
      case StorageClosed():
        _becomeInMemory(ConsentPersistence.memoryOnly);
    }
  }

  Future<void> _load(StorageReady ready) async {
    final generation = ++_generation;
    _writes = Future<void>.value();
    _loadedFrom = null;
    _persistence = ConsentPersistence.loading;
    notifyListeners();
    try {
      final snapshot = await ready.store.consent.snapshot(ready.profile.localPersonId);
      if (generation != _generation) return;
      for (final m in InputModality.values) {
        _enabled[m] = snapshot.isEnabled(m.code);
      }
      _loadedFrom = ready;
      _persistence = ConsentPersistence.persisted;
    } catch (_) {
      if (generation != _generation) return;
      _resetValues();
      _persistence = ConsentPersistence.storageUnavailable;
    }
    notifyListeners();
  }

  void _becomeInMemory(ConsentPersistence p) {
    final wasPersisted = _loadedFrom != null || _persistence == ConsentPersistence.loading;
    _generation++;
    _writes = Future<void>.value();
    _loadedFrom = null;
    _pending.clear();
    // Saved values are not carried into memory, where they would look current.
    if (wasPersisted) _resetValues();
    if (_persistence == p && !wasPersisted) return;
    _persistence = p;
    notifyListeners();
  }

  void _resetValues() {
    for (final m in InputModality.values) {
      _enabled[m] = false;
    }
  }

  /// Restores the defaults (all off, in memory, not attached). Used by tests.
  @visibleForTesting
  void reset() {
    if (_storage != null) {
      _storage!.removeListener(_onStorage);
      _storage = null;
    }
    _generation++;
    _writes = Future<void>.value();
    _loadedFrom = null;
    _pending.clear();
    _persistence = ConsentPersistence.memoryOnly;
    _resetValues();
    notifyListeners();
  }
}
