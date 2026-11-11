// SENSE workload persistence boundary (Milestone K2).
//
// Pure Dart: no Flutter imports. This is the narrow, typed surface through
// which the Workload screen's controller reads and writes M4 records. It never
// hands out the database, the store or a repository: callers get only
// [WorkloadAccess.loadDay] and [WorkloadAccess.save], with typed outcomes and
// no raw exception detail.
//
// The write path is the existing [WorkloadRepository] (`byDate` then `upsert`),
// run inside one `LocalDataStore.transaction`: the repository's M4 consent check
// executes in that same transaction as the write (ADR-009 Decision G,
// Milestone B). Nothing here checks consent itself, and no in-memory value can
// authorize a write.

import 'package:sqflite/sqlite_api.dart';

import 'consent.dart';
import 'local_data_store.dart' show LocalDataStore;
import 'records.dart';
import 'sqlite_repositories.dart' show UtcClock, IdGenerator;

/// Where workload records can currently be kept.
enum WorkloadStorageStatus {
  /// Storage is starting or opening; reads and writes are not possible yet.
  opening,

  /// Encrypted storage is open: reads and writes go to the database.
  open,

  /// This build does not connect storage (the default debug build, profile,
  /// and release in this milestone). The screen keeps its prototype "not
  /// saved" behaviour.
  notConnected,

  /// Storage should be available but is not (an open failure, or closed).
  unavailable,
}

/// The result of reading one local day's workload record.
sealed class WorkloadLoadOutcome {
  const WorkloadLoadOutcome();
}

/// The read succeeded. [record] is null when no entry exists for the day.
final class WorkloadLoaded extends WorkloadLoadOutcome {
  final StoredRecord<WorkloadEntry>? record;
  const WorkloadLoaded(this.record);
}

/// Storage is not open (see [WorkloadAccess.status]); nothing was read.
final class WorkloadLoadUnavailable extends WorkloadLoadOutcome {
  const WorkloadLoadUnavailable();
}

/// The read failed. No detail is kept.
final class WorkloadLoadFailed extends WorkloadLoadOutcome {
  const WorkloadLoadFailed();
}

/// The result of saving one workload entry.
sealed class WorkloadSaveOutcome {
  const WorkloadSaveOutcome();
}

/// The transaction committed. [updated] is true when an entry for the same
/// local day already existed (same id and creation time, new values).
final class WorkloadSaved extends WorkloadSaveOutcome {
  final StoredRecord<WorkloadEntry> record;
  final bool updated;
  const WorkloadSaved(this.record, {required this.updated});
}

/// M4 is off (or was never turned on): the repository refused the write
/// inside its transaction. Nothing was written.
final class WorkloadConsentDenied extends WorkloadSaveOutcome {
  final ConsentDenialReason reason;
  const WorkloadConsentDenied(this.reason);
}

/// Storage is not open (see [WorkloadAccess.status]); nothing was written.
final class WorkloadSaveUnavailable extends WorkloadSaveOutcome {
  const WorkloadSaveUnavailable();
}

/// The entry failed validation; nothing was written.
final class WorkloadSaveInvalid extends WorkloadSaveOutcome {
  final String field;
  const WorkloadSaveInvalid(this.field);
}

/// The write failed (database, engine or connection error). Nothing was
/// committed. No detail is kept.
final class WorkloadSaveFailed extends WorkloadSaveOutcome {
  const WorkloadSaveFailed();
}

/// The narrow workload operations a screen may use (Milestone K2).
///
/// Supplied by the app's storage owner; it follows the owner's state, and
/// listeners are told when [status] may have changed. Never throws.
abstract interface class WorkloadAccess {
  WorkloadStorageStatus get status;

  /// True when records are kept in the development namespace (never
  /// participant data).
  bool get isDevelopment;

  Future<WorkloadLoadOutcome> loadDay(String localDate);

  Future<WorkloadSaveOutcome> save(WorkloadEntry entry);

  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

/// The workload operations bound to one open database and the active local
/// profile. Used by the storage owner; not by screens.
class WorkloadRecordService {
  final Database _database;
  final String _localPersonId;
  final UtcClock? _clock;
  final IdGenerator? _ids;

  WorkloadRecordService(this._database, this._localPersonId, {UtcClock? clock, IdGenerator? ids})
      : _clock = clock,
        _ids = ids;

  Future<WorkloadLoadOutcome> loadDay(String localDate) async {
    try {
      final record = await LocalDataStore(_database, clock: _clock, ids: _ids).workload.byDate(_localPersonId, localDate);
      return WorkloadLoaded(record);
    } catch (_) {
      return const WorkloadLoadFailed();
    }
  }

  /// Saves [entry] for its local day through the existing repository. The
  /// existence check, the M4 consent check and the write share one
  /// transaction, so `updated` is exact and consent cannot change in between.
  Future<WorkloadSaveOutcome> save(WorkloadEntry entry) async {
    try {
      entry.validate();
    } on DataValidationException catch (e) {
      return WorkloadSaveInvalid(e.field);
    }
    try {
      return await LocalDataStore.transaction(_database, (s) async {
        final existing = await s.workload.byDate(_localPersonId, entry.day.date);
        final record = await s.workload.upsert(_localPersonId, entry);
        return WorkloadSaved(record, updated: existing != null);
      }, clock: _clock, ids: _ids);
    } on ConsentDeniedException catch (e) {
      // A missing profile or an unreadable consent state is a storage
      // failure, not a preference the person can change.
      return switch (e.reason) {
        ConsentDenialReason.notRecorded || ConsentDenialReason.disabled => WorkloadConsentDenied(e.reason),
        ConsentDenialReason.noProfile || ConsentDenialReason.unavailable => const WorkloadSaveFailed(),
      };
    } on DataValidationException catch (e) {
      return WorkloadSaveInvalid(e.field);
    } catch (_) {
      return const WorkloadSaveFailed();
    }
  }
}
