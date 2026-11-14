import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/sense_storage.dart';
import '../../domain/personal_insights.dart';

/// Where the Insights screen's personal baseline is (Milestone E).
enum InsightsPhase {
  /// Not started.
  idle,

  /// Storage is opening, or observations are being read. No results are shown.
  loading,

  /// Results for the current window are available.
  available,

  /// This build does not connect storage: the screen stays the labelled sample.
  notConnected,

  /// Storage should be available but is not. No results are shown.
  storageUnavailable,

  /// Reading the observations failed. No results are shown.
  failed,
}

/// One modality's state in the window.
sealed class ModalityInsights {
  /// The consent modality: M1 check-ins, M3 sleep, M4 workload.
  final String modality;
  const ModalityInsights(this.modality);
}

/// The modality's persisted consent is on: one result per variable.
final class ModalityAnalysed extends ModalityInsights {
  final List<VariableBaseline> variables;
  const ModalityAnalysed(super.modality, this.variables);
}

/// The modality's persisted consent is off: nothing was read or analysed.
final class ModalityNotAnalysed extends ModalityInsights {
  const ModalityNotAnalysed(super.modality);
}

/// Reads the person's committed Check-in, Sleep and Workload records for the
/// last [PersonalBaselineAnalyzer.windowDays] local days and applies the
/// existing personal baseline engine to each variable (Milestone E).
///
/// * Only committed records, through the read-only [InsightsAccess]: never
///   unsaved form values, never sample data.
/// * A modality is analysed only when its persisted consent is on; the access
///   reads the consent state in the same transaction as the records. No
///   in-memory preference is used.
/// * Every reload clears the previous results first, and any loss of storage
///   clears them too, so revoked or unavailable data never stays on screen.
/// * Sleep records count on their stored local date, which is the date of
///   wake-up. Sleep duration is analysed in hours (minutes / 60).
class InsightsController extends ChangeNotifier {
  final InsightsAccess? _access;
  final DateTime Function() _now;
  final PersonalBaselineAnalyzer analyzer;

  InsightsController({InsightsAccess? access, DateTime Function()? now, this.analyzer = const PersonalBaselineAnalyzer()})
      : _access = access,
        _now = now ?? DateTime.now {
    _access?.addListener(_onStorage);
  }

  InsightsPhase _phase = InsightsPhase.idle;
  List<ModalityInsights>? _modalities;
  List<String>? _window;
  int _generation = 0;
  bool _disposed = false;

  InsightsPhase get phase => _phase;

  /// The results by modality (M1, M3, M4), or null unless [phase] is available.
  List<ModalityInsights>? get modalities => _phase == InsightsPhase.available ? _modalities : null;

  /// The window's local dates, oldest first, once read.
  List<String>? get windowDates => _phase == InsightsPhase.available ? _window : null;

  bool get isDevelopment => _access?.isDevelopment ?? false;
  bool get persistenceConnected => _phase != InsightsPhase.notConnected;

  /// Reads the window if storage is open; otherwise reflects why not.
  Future<void> start() => refresh();

  void _onStorage() => unawaited(refresh());

  /// Reads the window again (for example when the screen is shown). Any
  /// previous results are cleared before reading. Never throws.
  Future<void> refresh() async {
    final access = _access;
    if (_disposed) return;
    final generation = ++_generation;
    _modalities = null;
    _window = null;
    if (access == null) return _set(InsightsPhase.notConnected);
    switch (access.status) {
      case InsightsStorageStatus.opening:
        return _set(InsightsPhase.loading);
      case InsightsStorageStatus.notConnected:
        return _set(InsightsPhase.notConnected);
      case InsightsStorageStatus.unavailable:
        return _set(InsightsPhase.storageUnavailable);
      case InsightsStorageStatus.open:
        break;
    }
    _set(InsightsPhase.loading);
    final dates = analyzer.windowDates(LocalDay.fromLocal(_now()).date);
    final outcome = await access.loadWindow(fromDate: dates.first, toDate: dates.last);
    if (_disposed || generation != _generation) return;
    switch (outcome) {
      case ObservationWindowLoaded(:final checkInRecords, :final sleepRecords, :final workloadRecords):
        _window = List.unmodifiable(dates);
        _modalities = List.unmodifiable([
          _analyse('M1', checkInRecords, dates, (e) => {
                InsightVariable.mood: e.moodRating.toDouble(),
                InsightVariable.motivationEnergy: e.motivationEnergyRating.toDouble(),
                InsightVariable.perceivedStress: e.perceivedStressRating.toDouble(),
              }),
          _analyse('M3', sleepRecords, dates, (e) => {
                InsightVariable.sleepDuration: e.durationMinutes / 60.0,
                InsightVariable.restQuality: e.restQuality.toDouble(),
              }),
          _analyse('M4', workloadRecords, dates, (e) => {
                InsightVariable.mentalDemand: e.mentalDemand.toDouble(),
                InsightVariable.effort: e.effort.toDouble(),
                InsightVariable.deadlines: e.deadlines48h.toDouble(),
              }),
        ]);
        _set(InsightsPhase.available);
      case ObservationWindowUnavailable():
        _set(InsightsPhase.storageUnavailable);
      case ObservationWindowFailed():
        _set(InsightsPhase.failed);
    }
  }

  /// One modality: its variables' observations by stored local date.
  ModalityInsights _analyse<T extends DailyEntry>(String modality, ModalityRecords<T> records, List<String> dates,
      Map<InsightVariable, double?> Function(T entry) fields) {
    switch (records) {
      case ModalityConsentOff():
        return ModalityNotAnalysed(modality);
      case ModalityRecordsAvailable(:final records):
        final variables = InsightVariable.values.where((v) => v.modality == modality).toList();
        final byVariable = {for (final v in variables) v: <String, double?>{}};
        for (final r in records) {
          final values = fields(r.entry);
          for (final v in variables) {
            byVariable[v]![r.entry.day.date] = values[v];
          }
        }
        return ModalityAnalysed(modality, [for (final v in variables) analyzer.analyze(v, dates, byVariable[v]!)]);
    }
  }

  void _set(InsightsPhase p) {
    if (_disposed) return;
    _phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _access?.removeListener(_onStorage);
    super.dispose();
  }
}
