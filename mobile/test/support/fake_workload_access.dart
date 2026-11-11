// TEST-ONLY. A programmable WorkloadAccess for controller and widget tests
// (Milestone K2). It models the repository's observable contract: one record
// per local date, a second save keeps the id and creation time, and a save is
// reported only when it "commits". Repository-backed tests use the real
// SenseStorage with FakeSecureKeyPlatform instead.

import 'dart:async';

import 'package:mindpulse/data/local/sense_storage.dart';

class FakeWorkloadAccess implements WorkloadAccess {
  WorkloadStorageStatus _status;
  @override
  bool isDevelopment;

  FakeWorkloadAccess({WorkloadStorageStatus status = WorkloadStorageStatus.open, this.isDevelopment = true})
      : _status = status;

  /// Stored records by local date.
  final Map<String, StoredRecord<WorkloadEntry>> records = {};

  /// Every entry passed to [save], in order (including refused ones).
  final List<WorkloadEntry> saveCalls = [];
  final List<String> loadCalls = [];

  /// When set, the next saves return this instead of writing.
  WorkloadSaveOutcome? saveOutcome;

  /// When set, loads return this instead of reading.
  WorkloadLoadOutcome? loadOutcome;

  /// When set, save/load wait for it.
  Completer<void>? saveGate;
  Completer<void>? loadGate;

  DateTime clock = DateTime.utc(2026, 11, 11, 4);
  int _ids = 0;
  final List<void Function()> _listeners = [];

  @override
  WorkloadStorageStatus get status => _status;

  set status(WorkloadStorageStatus s) {
    _status = s;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  Future<WorkloadLoadOutcome> loadDay(String localDate) async {
    loadCalls.add(localDate);
    if (loadGate != null) await loadGate!.future;
    if (_status != WorkloadStorageStatus.open) return const WorkloadLoadUnavailable();
    return loadOutcome ?? WorkloadLoaded(records[localDate]);
  }

  @override
  Future<WorkloadSaveOutcome> save(WorkloadEntry entry) async {
    saveCalls.add(entry);
    if (saveGate != null) await saveGate!.future;
    if (saveOutcome != null) return saveOutcome!;
    if (_status != WorkloadStorageStatus.open) return const WorkloadSaveUnavailable();
    entry.validate();
    clock = clock.add(const Duration(minutes: 1));
    final previous = records[entry.day.date];
    final record = StoredRecord<WorkloadEntry>(
      id: previous?.id ?? 'workload-${++_ids}',
      localPersonId: 'person-1',
      createdAtUtc: previous?.createdAtUtc ?? clock,
      updatedAtUtc: clock,
      schemaVersion: 2,
      entry: entry,
    );
    records[entry.day.date] = record;
    return WorkloadSaved(record, updated: previous != null);
  }

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);

  int get listenerCount => _listeners.length;

  /// A stored record for [date] with the given values and changed fields.
  StoredRecord<WorkloadEntry> seed(String date, int tz,
      {required int demand, required int effort, required int deadlines, required Set<String> changed}) {
    final r = StoredRecord<WorkloadEntry>(
      id: 'existing-id',
      localPersonId: 'person-1',
      createdAtUtc: DateTime.utc(2026, 11, 11, 1),
      updatedAtUtc: DateTime.utc(2026, 11, 11, 1),
      schemaVersion: 2,
      entry: WorkloadEntry(
        mentalDemand: demand,
        effort: effort,
        deadlines48h: deadlines,
        day: LocalDay(date, tz),
        provenance: Provenance.fromChanged(
            allFields: WorkloadEntry.allFields, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11, 1)),
      ),
    );
    records[date] = r;
    return r;
  }
}
