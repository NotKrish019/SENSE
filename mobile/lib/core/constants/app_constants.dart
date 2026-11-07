/// Core constants for the SENSE application (formerly "MindPulse").
class AppConstants {
  static const String appName = 'SENSE';
  static const String appSubtitle = 'Personalized Well-Being Research';
  static const String appVersion = '0.1.0';

  // Calibration and baseline hyperparameters
  static const int calibrationDaysRequired = 14;
  static const double defaultEwmaAlpha = 0.15;
  static const double cusumAllowanceK = 0.5;
  static const double cusumThresholdH = 3.5;

  // Helplines (India National Helplines)
  static const String teleManasPhone = '14416';
  static const String teleManasAltPhone = '1800-891-4416';
  static const String kiranHelplinePhone = '1800-599-0019';
  static const String vandrevalaPhone = '+919999666555';
  static const String aasraPhone = '+919820466726';

  // Disclaimer
  static const String nonClinicalDisclaimer =
      'SENSE is an experimental digital well-being research application. '
      'It does not provide clinical diagnoses, psychiatric treatment, or medical advice. '
      'If you are experiencing severe distress or crisis, please contact emergency support.';
}

