import 'package:flutter/foundation.dart';

/// The six optional SENSE input categories (M1–M6).
enum InputModality { checkIn, journal, sleep, workload, voice, activity }

extension InputModalityLabel on InputModality {
  String get code => 'M${index + 1}';

  String get title {
    switch (this) {
      case InputModality.checkIn:
        return 'Structured check-ins';
      case InputModality.journal:
        return 'Journal';
      case InputModality.sleep:
        return 'Sleep';
      case InputModality.workload:
        return 'Workload';
      case InputModality.voice:
        return 'Voice';
      case InputModality.activity:
        return 'Physical activity';
    }
  }

  /// True when the prototype has a working (manual-entry) screen for this
  /// input. Voice is planned only: no audio is ever recorded.
  bool get isAvailableInPrototype => this != InputModality.voice;
}

/// In-memory consent *preferences* for the prototype.
///
/// IMPORTANT: nothing here is persisted. Choices last only while the app is
/// open and are lost on refresh or restart. They do not start or stop any
/// data collection, and no operating-system permission is ever requested.
/// This is a demonstration of consent choices, not a consent record.
class ConsentPreferences extends ChangeNotifier {
  ConsentPreferences._();

  /// Single shared instance so onboarding and Settings show the same choices.
  static final ConsentPreferences instance = ConsentPreferences._();

  // Everything starts OFF: consent must be an active choice, never pre-ticked.
  final Map<InputModality, bool> _enabled = {
    for (final m in InputModality.values) m: false,
  };

  bool isEnabled(InputModality m) => _enabled[m] ?? false;

  int get enabledCount => _enabled.values.where((v) => v).length;

  void setEnabled(InputModality m, bool value) {
    if (_enabled[m] == value) return;
    _enabled[m] = value;
    notifyListeners();
  }

  /// Restores the defaults (all off). Used by tests.
  @visibleForTesting
  void reset() {
    for (final m in InputModality.values) {
      _enabled[m] = false;
    }
    notifyListeners();
  }
}
