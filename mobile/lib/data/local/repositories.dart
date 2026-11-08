// SENSE local data foundation (Milestone A): repository interfaces.
//
// Pure Dart. The app does NOT use these yet: no screen's Save handler is
// connected (that is Milestone D, after consent gating in Milestone B and
// encrypted storage per ADR-009 Decision J).
//
// There is intentionally no journal repository: raw journal text must not be
// persisted until encryption, key management, consent, retention and erase
// are in place (ADR-009 Decision F).

import 'consent.dart';
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
  ///
  /// Requires the matching modality preference (M1, M3, M4 or M6) to be ON,
  /// checked in the same transaction as the write. Otherwise throws
  /// [ConsentDeniedException] and writes nothing (fail closed).
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

/// Append-only modality preference history (ADR-009 Decision G, Milestone B).
///
/// There is deliberately no update or delete operation: every change adds an
/// event, and earlier events stay intact. (Deleting the local profile removes
/// its history through the foreign key; the user-facing Erase is Milestone C.)
/// With no events every modality is OFF.
///
/// Not used by the shipped app: the production Consent screen remains
/// in-memory until encrypted native storage is verified (ADR-009 Decision J).
abstract class ConsentRepository {
  /// Appends one event for [modality] (M1 to M6). Throws
  /// [DataValidationException] for an unknown modality or local person.
  Future<ConsentEvent> recordChange(String localPersonId, String modality, bool enabled);

  /// The current preference for one modality (OFF when never set).
  Future<bool> isEnabled(String localPersonId, String modality);

  /// All six current preferences.
  Future<Map<String, bool>> currentPreferences(String localPersonId);

  /// The latest event per modality, with the derived preferences.
  Future<ConsentSnapshot> snapshot(String localPersonId);

  /// Events oldest first (by event id), optionally for one modality.
  Future<List<ConsentEvent>> history(String localPersonId, {String? modality});
}
