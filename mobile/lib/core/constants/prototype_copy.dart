/// Central, honest wording for SENSE prototype states.
///
/// The current Flutter app is a UI prototype: screens do not save, encrypt,
/// export, delete or analyse personal data yet. Keep every user-facing
/// statement about storage, processing and sample values in this file so the
/// app never claims a capability that has not been implemented and verified.
/// When a capability is genuinely implemented, update the wording here.
class PrototypeCopy {
  PrototypeCopy._();

  // ---- Sample / illustrative data -------------------------------------------
  static const String sampleDataLabel = 'Sample data';
  static const String sampleDataTitle = 'Sample data, not your information';
  static const String sampleDataDescription =
      'Illustrative information for demonstration. This is not your recorded '
      'personal data or a clinically validated assessment.';

  // ---- Saving (no persistence is connected yet) -----------------------------
  /// Shown after a "save" action. Nothing is written to storage.
  static String notSaved(String what) =>
      'Prototype: your $what was not saved. Saving is not connected yet, so '
      'it will be lost when you leave this screen.';

  static const String notStoredYet =
      'Not saved: this prototype keeps what you enter only while this screen '
      'is open. Nothing is stored or shared.';

  // ---- Baseline -------------------------------------------------------------
  static const String noBaselineTitle = 'No pattern yet';
  static const String noBaselineDescription =
      'A personal baseline needs about 14 days of saved check-ins. Saving is '
      'not connected in this prototype yet, so no stress pattern has been '
      'calculated for you.';

  // ---- Data rights (not implemented yet) ------------------------------------
  static const String exportUnavailable =
      'Export is not available yet. This prototype does not store your '
      'entries, so there is nothing to export. Data export is planned before '
      'any real data is collected.';
  static const String eraseUnavailable =
      'Erase is not available yet. This prototype does not store your '
      'entries, so there is no saved data to delete. Data deletion is planned '
      'before any real data is collected.';

  // ---- Relationships between indicators -------------------------------------
  static const String noCausalClaim =
      'Indicators that change during the same period are not evidence that '
      'one caused the other. This is not a diagnosis or clinical assessment.';
}
