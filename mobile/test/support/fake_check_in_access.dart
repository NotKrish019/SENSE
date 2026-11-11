// TEST-ONLY. A programmable CheckInAccess for controller and widget tests
// (Milestone K3), modelling the repository's observable contract: one record
// per local date, a second save keeps the id and creation time, and a save is
// reported only when it "commits". Repository-backed tests use the real
// SenseStorage with FakeSecureKeyPlatform instead.

import 'dart:async';

import 'package:mindpulse/data/local/sense_storage.dart';

class FakeCheckInAccess implements CheckInAccess {
  CheckInStorageStatus _status;
  @override
  bool isDevelopment;

  FakeCheckInAccess({CheckInStorageStatus status = CheckInStorageStatus.open, this.isDevelopment = true})
      : _status = status;

  /// Stored records by local date.
  final Map<String, StoredRecord<CheckInEntry>> records = {};

  /// Every entry passed to [save], in order (including refused ones).
  final List<CheckInEntry> saveCalls = [];
  final List<String> loadCalls = [];

  /// When set, saves return this instead of writing.
  CheckInSaveOutcome? saveOutcome;

  /// When set, loads return this instead of reading.
  CheckInLoadOutcome? loadOutcome;

  /// When set, save/load wait for it.
  Completer<void>? saveGate;
  Completer<void>? loadGate;

  DateTime clock = DateTime.utc(2026, 11, 11, 4);
  int _ids = 0;
  final List<void Function()> _listeners = [];

  @override
  CheckInStorageStatus get status => _status;

  set status(CheckInStorageStatus s) {
    _status = s;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  Future<CheckInLoadOutcome> loadDay(String localDate) async {
    loadCalls.add(localDate);
    if (loadGate != null) await loadGate!.future;
    if (_status != CheckInStorageStatus.open) return const CheckInLoadUnavailable();
    return loadOutcome ?? CheckInLoaded(records[localDate]);
  }

  @override
  Future<CheckInSaveOutcome> save(CheckInEntry entry) async {
    saveCalls.add(entry);
    if (saveGate != null) await saveGate!.future;
    if (saveOutcome != null) return saveOutcome!;
    if (_status != CheckInStorageStatus.open) return const CheckInSaveUnavailable();
    entry.validate();
    clock = clock.add(const Duration(minutes: 1));
    final previous = records[entry.day.date];
    final record = StoredRecord<CheckInEntry>(
      id: previous?.id ?? 'check-in-${++_ids}',
      localPersonId: 'person-1',
      createdAtUtc: previous?.createdAtUtc ?? clock,
      updatedAtUtc: clock,
      schemaVersion: 2,
      entry: entry,
    );
    records[entry.day.date] = record;
    return CheckInSaved(record, updated: previous != null);
  }

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);

  int get listenerCount => _listeners.length;

  /// A stored check-in for [date] with the given values and changed fields.
  StoredRecord<CheckInEntry> seed(String date, int tz,
      {required int mood, required int motivation, required int stress, required Set<String> changed}) {
    final r = StoredRecord<CheckInEntry>(
      id: 'existing-check-in',
      localPersonId: 'person-1',
      createdAtUtc: DateTime.utc(2026, 11, 11, 1),
      updatedAtUtc: DateTime.utc(2026, 11, 11, 1),
      schemaVersion: 2,
      entry: CheckInEntry(
        moodRating: mood,
        motivationEnergyRating: motivation,
        perceivedStressRating: stress,
        day: LocalDay(date, tz),
        provenance: Provenance.fromChanged(
            allFields: CheckInEntry.allFields, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11, 1)),
      ),
    );
    r.entry.validate(); // fixtures must be records the repository could have stored
    records[date] = r;
    return r;
  }
}
