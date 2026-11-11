// TEST-ONLY. A programmable SleepAccess for controller and widget tests
// (Milestone K4), modelling the repository's observable contract: one record
// per local date, a second save keeps the id and creation time, and a save is
// reported only when it "commits". Repository-backed tests use the real
// SenseStorage with FakeSecureKeyPlatform instead.

import 'dart:async';

import 'package:mindpulse/data/local/sense_storage.dart';

class FakeSleepAccess implements SleepAccess {
  SleepStorageStatus _status;
  @override
  bool isDevelopment;

  FakeSleepAccess({SleepStorageStatus status = SleepStorageStatus.open, this.isDevelopment = true})
      : _status = status;

  /// Stored records by local date.
  final Map<String, StoredRecord<SleepEntry>> records = {};

  /// Every entry passed to [save], in order (including refused ones).
  final List<SleepEntry> saveCalls = [];
  final List<String> loadCalls = [];

  /// When set, saves return this instead of writing.
  SleepSaveOutcome? saveOutcome;

  /// When set, loads return this instead of reading.
  SleepLoadOutcome? loadOutcome;

  /// When set, range reads return this instead of reading.
  SleepRangeOutcome? rangeOutcome;
  final List<(String, String)> rangeCalls = [];

  /// When set, save/load wait for it.
  Completer<void>? saveGate;
  Completer<void>? loadGate;

  DateTime clock = DateTime.utc(2026, 11, 11, 4);
  int _ids = 0;
  final List<void Function()> _listeners = [];

  @override
  SleepStorageStatus get status => _status;

  set status(SleepStorageStatus s) {
    _status = s;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  Future<SleepLoadOutcome> loadDay(String localDate) async {
    loadCalls.add(localDate);
    if (loadGate != null) await loadGate!.future;
    if (_status != SleepStorageStatus.open) return const SleepLoadUnavailable();
    return loadOutcome ?? SleepLoaded(records[localDate]);
  }

  @override
  Future<SleepRangeOutcome> loadRange({required String fromDate, required String toDate}) async {
    rangeCalls.add((fromDate, toDate));
    if (_status != SleepStorageStatus.open) return const SleepRangeUnavailable();
    if (rangeOutcome != null) return rangeOutcome!;
    final keys = records.keys.where((d) => d.compareTo(fromDate) >= 0 && d.compareTo(toDate) <= 0).toList()..sort();
    return SleepRangeLoaded([for (final k in keys) records[k]!]);
  }

  @override
  Future<SleepSaveOutcome> save(SleepEntry entry) async {
    saveCalls.add(entry);
    if (saveGate != null) await saveGate!.future;
    if (saveOutcome != null) return saveOutcome!;
    if (_status != SleepStorageStatus.open) return const SleepSaveUnavailable();
    entry.validate();
    clock = clock.add(const Duration(minutes: 1));
    final previous = records[entry.day.date];
    final record = StoredRecord<SleepEntry>(
      id: previous?.id ?? 'sleep-${++_ids}',
      localPersonId: 'person-1',
      createdAtUtc: previous?.createdAtUtc ?? clock,
      updatedAtUtc: clock,
      schemaVersion: 2,
      entry: entry,
    );
    records[entry.day.date] = record;
    return SleepSaved(record, updated: previous != null);
  }

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);

  int get listenerCount => _listeners.length;

  /// A stored sleep record for [date] with the given values and changed fields.
  StoredRecord<SleepEntry> seed(String date, int tz,
      {required int minutes,
      required String bedtime,
      required String wake,
      required int quality,
      required Set<String> changed,
      String id = 'existing-sleep'}) {
    final r = StoredRecord<SleepEntry>(
      id: id,
      localPersonId: 'person-1',
      createdAtUtc: DateTime.utc(2026, 11, 11, 1),
      updatedAtUtc: DateTime.utc(2026, 11, 11, 1),
      schemaVersion: 2,
      entry: SleepEntry(
        durationMinutes: minutes,
        bedtimeLocal: bedtime,
        wakeTimeLocal: wake,
        restQuality: quality,
        day: LocalDay(date, tz),
        provenance: Provenance.fromChanged(
            allFields: SleepEntry.allFields, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11, 1)),
      ),
    );
    r.entry.validate(); // fixtures must be records the repository could have stored
    records[date] = r;
    return r;
  }
}
