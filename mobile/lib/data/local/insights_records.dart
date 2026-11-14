// SENSE observation read boundary for Insights (Milestone E: personal baseline).
//
// Pure Dart: no Flutter imports. The narrow, typed, READ-ONLY surface through
// which the Insights controller obtains the person's committed Check-in (M1),
// Sleep (M3) and Workload (M4) records for an observation window. It never
// hands out the database, the store or a repository, and it cannot write.
//
// Consent: the persisted consent snapshot and every range read run inside ONE
// `LocalDataStore.transaction`, so a modality is read only if its latest
// persisted consent event (the repository's `ConsentRepository.snapshot`) is
// ON at that moment. A modality that is off is reported as off and none of its
// records leave this layer. No in-memory preference is consulted.
//
// Records are returned exactly as stored (one per person per local date; a
// sleep record's date is the date of wake-up). Nothing is synthesised.

import 'package:sqflite/sqlite_api.dart';

import 'local_data_store.dart' show LocalDataStore;
import 'records.dart';
import 'sqlite_repositories.dart' show UtcClock, IdGenerator;

/// Where observations can currently be read.
enum InsightsStorageStatus {
  /// Storage is starting or opening.
  opening,

  /// Encrypted storage is open.
  open,

  /// This build does not connect storage (the default debug build, profile,
  /// and release in this milestone). Insights stay the labelled sample.
  notConnected,

  /// Storage should be available but is not (an open failure, or closed).
  unavailable,
}

/// One modality's records in the window, or why there are none.
sealed class ModalityRecords<T extends DailyEntry> {
  const ModalityRecords();
}

/// The modality's persisted consent is ON: its stored records, oldest first.
final class ModalityRecordsAvailable<T extends DailyEntry> extends ModalityRecords<T> {
  final List<StoredRecord<T>> records;
  const ModalityRecordsAvailable(this.records);
}

/// The modality's persisted consent is OFF (or was never turned on): its
/// records are not read.
final class ModalityConsentOff<T extends DailyEntry> extends ModalityRecords<T> {
  const ModalityConsentOff();
}

/// The result of reading an observation window.
sealed class ObservationWindowOutcome {
  const ObservationWindowOutcome();
}

final class ObservationWindowLoaded extends ObservationWindowOutcome {
  final ModalityRecords<CheckInEntry> checkInRecords;
  final ModalityRecords<SleepEntry> sleepRecords;
  final ModalityRecords<WorkloadEntry> workloadRecords;
  const ObservationWindowLoaded({required this.checkInRecords, required this.sleepRecords, required this.workloadRecords});
}

/// Storage is not open; nothing was read.
final class ObservationWindowUnavailable extends ObservationWindowOutcome {
  const ObservationWindowUnavailable();
}

/// The read failed; nothing is returned. No detail is kept.
final class ObservationWindowFailed extends ObservationWindowOutcome {
  const ObservationWindowFailed();
}

/// The narrow, read-only observation surface for the Insights screen.
abstract interface class InsightsAccess {
  InsightsStorageStatus get status;

  /// True when the records come from the development namespace.
  bool get isDevelopment;

  /// The committed records with `fromDate <= local_date <= toDate` for each
  /// consented modality (M1 check-ins, M3 sleep, M4 workload).
  Future<ObservationWindowOutcome> loadWindow({required String fromDate, required String toDate});

  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

/// Reads an observation window from one open database for the active local
/// profile. Used by the storage owner; not by screens.
class ObservationRecordService {
  final Database _database;
  final String _localPersonId;
  final UtcClock? _clock;
  final IdGenerator? _ids;

  ObservationRecordService(this._database, this._localPersonId, {UtcClock? clock, IdGenerator? ids})
      : _clock = clock,
        _ids = ids;

  Future<ObservationWindowOutcome> loadWindow({required String fromDate, required String toDate}) async {
    try {
      return await LocalDataStore.transaction(_database, (s) async {
        // The persisted consent state, read in the same transaction as the
        // records it governs.
        final consent = await s.consent.snapshot(_localPersonId);
        Future<ModalityRecords<T>> read<T extends DailyEntry>(
                String modality, Future<List<StoredRecord<T>>> Function() range) async =>
            consent.isEnabled(modality) ? ModalityRecordsAvailable<T>(await range()) : ModalityConsentOff<T>();
        return ObservationWindowLoaded(
          checkInRecords: await read('M1', () => s.checkIns.range(_localPersonId, fromDate: fromDate, toDate: toDate)),
          sleepRecords: await read('M3', () => s.sleep.range(_localPersonId, fromDate: fromDate, toDate: toDate)),
          workloadRecords: await read('M4', () => s.workload.range(_localPersonId, fromDate: fromDate, toDate: toDate)),
        );
      }, clock: _clock, ids: _ids);
    } catch (_) {
      return const ObservationWindowFailed();
    }
  }
}
