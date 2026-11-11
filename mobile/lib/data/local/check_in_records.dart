// SENSE check-in persistence boundary (Milestone K3).
//
// Pure Dart: no Flutter imports. The narrow, typed surface through which the
// Check-in screen's controller reads and writes M1 records, following the
// Workload pattern (Milestone K2, workload_records.dart). It never hands out
// the database, the store or a repository: callers get only
// [CheckInAccess.loadDay] and [CheckInAccess.save], with typed outcomes and no
// raw exception detail.
//
// The write path is the existing [CheckInRepository] (`byDate` then `upsert`),
// run inside one `LocalDataStore.transaction`: the repository's M1 consent
// check executes in that same transaction as the write (ADR-009 Decision G,
// Milestone B). Nothing here checks consent itself, and no in-memory value can
// authorize a write.

import 'package:sqflite/sqlite_api.dart';

import 'consent.dart';
import 'local_data_store.dart' show LocalDataStore;
import 'records.dart';
import 'sqlite_repositories.dart' show UtcClock, IdGenerator;

/// Where check-ins can currently be kept.
enum CheckInStorageStatus {
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

/// The result of reading one local day's check-in.
sealed class CheckInLoadOutcome {
  const CheckInLoadOutcome();
}

/// The read succeeded. [record] is null when no check-in exists for the day.
final class CheckInLoaded extends CheckInLoadOutcome {
  final StoredRecord<CheckInEntry>? record;
  const CheckInLoaded(this.record);
}

/// Storage is not open (see [CheckInAccess.status]); nothing was read.
final class CheckInLoadUnavailable extends CheckInLoadOutcome {
  const CheckInLoadUnavailable();
}

/// The read failed. No detail is kept.
final class CheckInLoadFailed extends CheckInLoadOutcome {
  const CheckInLoadFailed();
}

/// The result of saving one check-in.
sealed class CheckInSaveOutcome {
  const CheckInSaveOutcome();
}

/// The transaction committed. [updated] is true when a check-in for the same
/// local day already existed (same id and creation time, new values).
final class CheckInSaved extends CheckInSaveOutcome {
  final StoredRecord<CheckInEntry> record;
  final bool updated;
  const CheckInSaved(this.record, {required this.updated});
}

/// M1 is off (or was never turned on): the repository refused the write
/// inside its transaction. Nothing was written.
final class CheckInConsentDenied extends CheckInSaveOutcome {
  final ConsentDenialReason reason;
  const CheckInConsentDenied(this.reason);
}

/// Storage is not open (see [CheckInAccess.status]); nothing was written.
final class CheckInSaveUnavailable extends CheckInSaveOutcome {
  const CheckInSaveUnavailable();
}

/// The entry failed validation; nothing was written.
final class CheckInSaveInvalid extends CheckInSaveOutcome {
  final String field;
  const CheckInSaveInvalid(this.field);
}

/// The write failed (database, engine or connection error). Nothing was
/// committed. No detail is kept.
final class CheckInSaveFailed extends CheckInSaveOutcome {
  const CheckInSaveFailed();
}

/// The narrow check-in operations a screen may use (Milestone K3).
///
/// Supplied by the app's storage owner; it follows the owner's state, and
/// listeners are told when [status] may have changed. Never throws.
abstract interface class CheckInAccess {
  CheckInStorageStatus get status;

  /// True when records are kept in the development namespace (never
  /// participant data).
  bool get isDevelopment;

  Future<CheckInLoadOutcome> loadDay(String localDate);

  Future<CheckInSaveOutcome> save(CheckInEntry entry);

  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

/// The check-in operations bound to one open database and the active local
/// profile. Used by the storage owner; not by screens.
class CheckInRecordService {
  final Database _database;
  final String _localPersonId;
  final UtcClock? _clock;
  final IdGenerator? _ids;

  CheckInRecordService(this._database, this._localPersonId, {UtcClock? clock, IdGenerator? ids})
      : _clock = clock,
        _ids = ids;

  Future<CheckInLoadOutcome> loadDay(String localDate) async {
    try {
      final record =
          await LocalDataStore(_database, clock: _clock, ids: _ids).checkIns.byDate(_localPersonId, localDate);
      return CheckInLoaded(record);
    } catch (_) {
      return const CheckInLoadFailed();
    }
  }

  /// Saves [entry] for its local day through the existing repository. The
  /// existence check, the M1 consent check and the write share one
  /// transaction, so `updated` is exact and consent cannot change in between.
  Future<CheckInSaveOutcome> save(CheckInEntry entry) async {
    try {
      entry.validate();
    } on DataValidationException catch (e) {
      return CheckInSaveInvalid(e.field);
    }
    try {
      return await LocalDataStore.transaction(_database, (s) async {
        final existing = await s.checkIns.byDate(_localPersonId, entry.day.date);
        final record = await s.checkIns.upsert(_localPersonId, entry);
        return CheckInSaved(record, updated: existing != null);
      }, clock: _clock, ids: _ids);
    } on ConsentDeniedException catch (e) {
      // A missing profile or an unreadable consent state is a storage
      // failure, not a preference the person can change.
      return switch (e.reason) {
        ConsentDenialReason.notRecorded || ConsentDenialReason.disabled => CheckInConsentDenied(e.reason),
        ConsentDenialReason.noProfile || ConsentDenialReason.unavailable => const CheckInSaveFailed(),
      };
    } on DataValidationException catch (e) {
      return CheckInSaveInvalid(e.field);
    } catch (_) {
      return const CheckInSaveFailed();
    }
  }
}
