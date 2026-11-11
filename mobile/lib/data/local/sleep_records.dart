// SENSE sleep persistence boundary (Milestone K4).
//
// Pure Dart: no Flutter imports. The narrow, typed surface through which the
// Sleep screen's controller reads and writes M3 records, following the
// Workload and Check-in pattern (Milestones K2 and K3). It never hands out the
// database, the store or a repository: callers get only [SleepAccess.loadDay],
// [SleepAccess.loadRange] and [SleepAccess.save], with typed outcomes and no
// raw exception detail.
//
// A sleep record belongs to the local calendar date of WAKE-UP (the data
// dictionary's `date_epoch`, stored as `local_date`): bedtime 23:30 on
// 10 November and wake time 07:00 on 11 November is the 11 November record.
//
// The write path is the existing [SleepRepository] (`byDate` then `upsert`),
// run inside one `LocalDataStore.transaction`: the repository's M3 consent
// check executes in that same transaction as the write (ADR-009 Decision G,
// Milestone B). Reads use the repository's existing `byDate` and `range`.
// Nothing here checks consent itself, and no in-memory value can authorize a
// write.

import 'package:sqflite/sqlite_api.dart';

import 'consent.dart';
import 'local_data_store.dart' show LocalDataStore;
import 'records.dart';
import 'sqlite_repositories.dart' show UtcClock, IdGenerator;

/// Where sleep records can currently be kept.
enum SleepStorageStatus {
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

/// The result of reading one wake-up day's sleep record.
sealed class SleepLoadOutcome {
  const SleepLoadOutcome();
}

/// The read succeeded. [record] is null when no sleep record exists for the day.
final class SleepLoaded extends SleepLoadOutcome {
  final StoredRecord<SleepEntry>? record;
  const SleepLoaded(this.record);
}

/// Storage is not open (see [SleepAccess.status]); nothing was read.
final class SleepLoadUnavailable extends SleepLoadOutcome {
  const SleepLoadUnavailable();
}

/// The read failed. No detail is kept.
final class SleepLoadFailed extends SleepLoadOutcome {
  const SleepLoadFailed();
}

/// The result of reading the sleep records of a range of wake-up days.
sealed class SleepRangeOutcome {
  const SleepRangeOutcome();
}

/// The read succeeded: the stored records, oldest first (possibly none).
final class SleepRangeLoaded extends SleepRangeOutcome {
  final List<StoredRecord<SleepEntry>> records;
  const SleepRangeLoaded(this.records);
}

/// Storage is not open, or the read failed; nothing is shown as history.
final class SleepRangeUnavailable extends SleepRangeOutcome {
  const SleepRangeUnavailable();
}

/// The result of saving one sleep record.
sealed class SleepSaveOutcome {
  const SleepSaveOutcome();
}

/// The transaction committed. [updated] is true when a sleep record for the same
/// wake-up day already existed (same id and creation time, new values).
final class SleepSaved extends SleepSaveOutcome {
  final StoredRecord<SleepEntry> record;
  final bool updated;
  const SleepSaved(this.record, {required this.updated});
}

/// M3 is off (or was never turned on): the repository refused the write
/// inside its transaction. Nothing was written.
final class SleepConsentDenied extends SleepSaveOutcome {
  final ConsentDenialReason reason;
  const SleepConsentDenied(this.reason);
}

/// Storage is not open (see [SleepAccess.status]); nothing was written.
final class SleepSaveUnavailable extends SleepSaveOutcome {
  const SleepSaveUnavailable();
}

/// The entry failed validation; nothing was written.
final class SleepSaveInvalid extends SleepSaveOutcome {
  final String field;
  const SleepSaveInvalid(this.field);
}

/// The write failed (database, engine or connection error). Nothing was
/// committed. No detail is kept.
final class SleepSaveFailed extends SleepSaveOutcome {
  const SleepSaveFailed();
}

/// The narrow sleep operations a screen may use (Milestone K4).
///
/// Supplied by the app's storage owner; it follows the owner's state, and
/// listeners are told when [status] may have changed. Never throws.
abstract interface class SleepAccess {
  SleepStorageStatus get status;

  /// True when records are kept in the development namespace (never
  /// participant data).
  bool get isDevelopment;

  /// The record for one wake-up date (`YYYY-MM-DD`).
  Future<SleepLoadOutcome> loadDay(String localDate);

  /// The stored records with `fromDate <= wake-up date <= toDate`, oldest
  /// first (the repository's existing `range`).
  Future<SleepRangeOutcome> loadRange({required String fromDate, required String toDate});

  Future<SleepSaveOutcome> save(SleepEntry entry);

  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

/// The sleep operations bound to one open database and the active local
/// profile. Used by the storage owner; not by screens.
class SleepRecordService {
  final Database _database;
  final String _localPersonId;
  final UtcClock? _clock;
  final IdGenerator? _ids;

  SleepRecordService(this._database, this._localPersonId, {UtcClock? clock, IdGenerator? ids})
      : _clock = clock,
        _ids = ids;

  Future<SleepLoadOutcome> loadDay(String localDate) async {
    try {
      final record =
          await LocalDataStore(_database, clock: _clock, ids: _ids).sleep.byDate(_localPersonId, localDate);
      return SleepLoaded(record);
    } catch (_) {
      return const SleepLoadFailed();
    }
  }

  Future<SleepRangeOutcome> loadRange({required String fromDate, required String toDate}) async {
    try {
      return SleepRangeLoaded(await LocalDataStore(_database, clock: _clock, ids: _ids)
          .sleep
          .range(_localPersonId, fromDate: fromDate, toDate: toDate));
    } catch (_) {
      return const SleepRangeUnavailable();
    }
  }

  /// Saves [entry] for its wake-up day through the existing repository. The
  /// existence check, the M3 consent check and the write share one
  /// transaction, so `updated` is exact and consent cannot change in between.
  Future<SleepSaveOutcome> save(SleepEntry entry) async {
    try {
      entry.validate();
    } on DataValidationException catch (e) {
      return SleepSaveInvalid(e.field);
    }
    try {
      return await LocalDataStore.transaction(_database, (s) async {
        final existing = await s.sleep.byDate(_localPersonId, entry.day.date);
        final record = await s.sleep.upsert(_localPersonId, entry);
        return SleepSaved(record, updated: existing != null);
      }, clock: _clock, ids: _ids);
    } on ConsentDeniedException catch (e) {
      // A missing profile or an unreadable consent state is a storage
      // failure, not a preference the person can change.
      return switch (e.reason) {
        ConsentDenialReason.notRecorded || ConsentDenialReason.disabled => SleepConsentDenied(e.reason),
        ConsentDenialReason.noProfile || ConsentDenialReason.unavailable => const SleepSaveFailed(),
      };
    } on DataValidationException catch (e) {
      return SleepSaveInvalid(e.field);
    } catch (_) {
      return const SleepSaveFailed();
    }
  }
}
