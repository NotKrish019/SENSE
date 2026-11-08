// SENSE local data foundation (Milestone B): typed modality consent history
// and the authorization error raised when a write is not permitted.
//
// Pure Dart: no Flutter imports. These are per-modality data-collection
// PREFERENCES (ADR-009 Decision G). They are not formal research-participation
// consent, not operating-system permissions, and not evidence of ethics
// approval.
//
// TESTED WITH DISPOSABLE DATABASES ONLY. The shipped app does not use this:
// the production Consent screen keeps its in-memory `ConsentPreferences`
// until SQLCipher-encrypted storage with Android Keystore-backed keys is
// implemented and verified (ADR-009 Decision J). The database is NOT
// encrypted.

import 'records.dart';

/// Which preference each daily record repository requires (ADR-009 G,
/// Milestone B). M2 (journal) and M5 (voice) have no write repository.
const Map<String, String> kRequiredModalityByTable = {
  'check_ins': 'M1',
  'sleep_records': 'M3',
  'workload_records': 'M4',
  'activity_records': 'M6',
};

/// Throws unless [modality] is one of M1 to M6.
void validateModality(String modality) {
  if (!kModalityCodes.contains(modality)) {
    throw DataValidationException('modality', 'unknown modality: $modality (expected M1 to M6)');
  }
}

/// One append-only preference change. [id] comes from the
/// `consent_events.id` AUTOINCREMENT sequence: it strictly increases and is
/// never reused, so it orders events even when [changedAtUtc] is identical.
class ConsentEvent {
  final int id;
  final String localPersonId;
  final String modality;
  final bool enabled;
  final DateTime changedAtUtc;

  const ConsentEvent({
    required this.id,
    required this.localPersonId,
    required this.modality,
    required this.enabled,
    required this.changedAtUtc,
  });

  @override
  String toString() => 'ConsentEvent(#$id $modality ${enabled ? 'on' : 'off'} at ${utcIso(changedAtUtc)})';
}

/// The current preference for each of the six modalities, derived from the
/// latest event per modality. A modality with no event is OFF.
class ConsentSnapshot {
  final String localPersonId;

  /// Latest event per modality (all six keys present; null = never set).
  final Map<String, ConsentEvent?> latest;

  ConsentSnapshot(this.localPersonId, Map<String, ConsentEvent?> latest)
      : latest = Map.unmodifiable({for (final m in kModalityCodes) m: latest[m]});

  bool isEnabled(String modality) {
    validateModality(modality);
    return latest[modality]?.enabled ?? false;
  }

  /// All six current preferences, OFF unless the latest event enables them.
  Map<String, bool> get preferences => {for (final m in kModalityCodes) m: latest[m]?.enabled ?? false};
}

/// Why a write was refused. Every case fails closed.
enum ConsentDenialReason {
  /// The local person does not exist.
  noProfile,

  /// No preference has ever been recorded for this modality (default OFF).
  notRecorded,

  /// The latest recorded preference for this modality is OFF.
  disabled,

  /// The consent state could not be read, so permission cannot be shown.
  unavailable,
}

/// A daily-record write was refused because the matching modality preference
/// is not enabled (or could not be established). Nothing was written.
class ConsentDeniedException implements Exception {
  final String modality;
  final ConsentDenialReason reason;

  /// The underlying error when [reason] is [ConsentDenialReason.unavailable].
  final Object? cause;

  const ConsentDeniedException(this.modality, this.reason, {this.cause});

  /// A safe explanation: no record values or personal details.
  String get message {
    switch (reason) {
      case ConsentDenialReason.noProfile:
        return 'No local profile exists, so $modality data cannot be saved.';
      case ConsentDenialReason.notRecorded:
        return '$modality is off (no preference has been turned on), so nothing was saved.';
      case ConsentDenialReason.disabled:
        return '$modality is turned off, so nothing was saved.';
      case ConsentDenialReason.unavailable:
        return 'The $modality preference could not be read, so nothing was saved.';
    }
  }

  @override
  String toString() => 'ConsentDeniedException($modality, ${reason.name}): $message';
}
