// SENSE local data foundation (Milestone A): repository interfaces.
//
// Pure Dart. The app does NOT use these yet: no screen's Save handler is
// connected (that is Milestone D, after consent gating in Milestone B and
// encrypted storage per ADR-009 Decision J).
//
// There is intentionally no journal repository: raw journal text must not be
// persisted until encryption, key management, consent, retention and erase
// are in place (ADR-009 Decision F).

import 'records.dart';

/// The single device-local pseudonymous identity.
abstract class LocalProfileRepository {
  /// The active profile, or null if none has been created.
  Future<LocalProfile?> active();

  /// The active profile, creating a new random one if needed.
  Future<LocalProfile> ensureActive();

  Future<LocalProfile?> byId(String localPersonId);

  /// Deletes the profile and, through foreign keys, its records. This is NOT
  /// the user-facing Erase (Milestone C), which must also clear legacy tables
  /// and run as one verified transaction with the rest of the data lifecycle.
  Future<bool> delete(String localPersonId);
}

/// One record per local person per local date for a modality.
abstract class DailyRecordRepository<T extends DailyEntry> {
  /// Validates and stores [entry]. A second submission for the same person and
  /// date updates the same logical record: its id and creation time are kept,
  /// its values, provenance and update time are replaced.
  Future<StoredRecord<T>> upsert(String localPersonId, T entry);

  Future<StoredRecord<T>?> byDate(String localPersonId, String localDate);

  /// Records with `fromDate <= local_date <= toDate`, oldest first.
  Future<List<StoredRecord<T>>> range(String localPersonId, {required String fromDate, required String toDate});

  Future<bool> deleteByDate(String localPersonId, String localDate);
}

typedef CheckInRepository = DailyRecordRepository<CheckInEntry>;
typedef SleepRepository = DailyRecordRepository<SleepEntry>;
typedef WorkloadRepository = DailyRecordRepository<WorkloadEntry>;
typedef ActivityRepository = DailyRecordRepository<ActivityEntry>;

/// Read-only view of the (future) preference history. With no events every
/// modality is OFF (ADR-009 Decision G). Writing events is Milestone B.
abstract class ConsentHistoryReader {
  Future<Map<String, bool>> currentPreferences(String localPersonId);
}
