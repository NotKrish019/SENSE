// Personal baseline insights (ADR-009 Decision L, Milestone E).
//
// Pure Dart. Turns a person's own committed daily observations into the
// day-indexed series the existing [PersonalBaselineEngine] expects, and reads
// back the engine's rolling median/MAD result (Model B) for each variable
// independently. Nothing statistical is re-implemented here.
//
// Rules (Decision L): descriptive within-person observations only. No
// composite score, no alert (the engine's CUSUM filter is NOT surfaced), no
// diagnosis, risk or prediction. Missing days and missing measurements are
// null (missing), never zero. A baseline is shown only when the engine has at
// least [BaselineConfig.minCalibrationPoints] valid observations in its
// [BaselineConfig.windowSize]-day window; reaching that minimum does not make
// the baseline reliable.

import 'baseline_engine.dart';

/// The variables analysed, each tied to its stored field and consent modality.
enum InsightVariable {
  mood('mood_rating', 'M1', 'Mood rating', '1 to 5'),
  motivationEnergy('motivation_energy_rating', 'M1', 'Motivation and energy', '1 to 5'),
  perceivedStress('perceived_stress_rating', 'M1', 'Perceived stress', '1 to 5'),
  sleepDuration('duration_minutes', 'M3', 'Sleep duration', 'hours'),
  restQuality('rest_quality', 'M3', 'Rest quality', '1 to 5'),
  mentalDemand('mental_demand', 'M4', 'Mental demand', '1 to 5'),
  effort('effort', 'M4', 'Effort', '1 to 5'),
  deadlines('deadlines_48h', 'M4', 'Deadlines in the next 48 hours', 'count');

  /// The stored field name (`CheckInEntry`, `SleepEntry`, `WorkloadEntry`).
  final String field;

  /// The consent modality that must be ON for this variable to be read.
  final String modality;
  final String label;
  final String unit;
  const InsightVariable(this.field, this.modality, this.label, this.unit);
}

/// How the latest observation sits against the person's own baseline.
enum BaselinePosition { within, above, below }

/// Whether the window has enough data, and enough variation, for a
/// directional comparison.
enum BaselineState {
  /// Fewer than the engine's minimum valid observations: no baseline.
  insufficientObservations,

  /// Enough observations, but the engine could not use its robust MAD scale:
  /// in [PersonalBaselineEngine.computeMad], `1.4826 × MAD` was not above the
  /// engine's own floor (1e-4), so it fell back to the plain standard
  /// deviation of the window (plus 1e-4), or to the floor itself when every
  /// value is identical. In that case most entries are identical and the
  /// z-score only says that the latest entry is the outlier: a one-point and
  /// a two-point change after a constant run get almost the same z (about
  /// 3.9 for 13 equal values). No direction is shown; the baseline median and
  /// the latest value are.
  degenerateDispersion,

  /// Enough observations and a robust (MAD-based) scale: the engine's
  /// z-score is a usable directional comparison.
  usable,
}

/// The engine's floor in [PersonalBaselineEngine.computeMad]
/// (`if (scale > 1e-4) return scale;`). Mirrored, not chosen: a test pins
/// that the engine's output agrees with it.
const double kEngineMadFloor = 1e-4;

/// EXPERIMENTAL DISPLAY CONVENTION, NOT A VALIDATED THRESHOLD: with a usable
/// (robust) scale, the latest observation is described as "within your usual
/// range" when the engine's z-score is smaller than this in magnitude, and
/// as above or below the personal baseline otherwise. It only chooses the
/// words on screen; no alert, score or decision is derived from it, and it
/// has not been validated in research.
const double kBaselineBandZ = 1.0;

/// One variable's baseline over the observation window.
class VariableBaseline {
  final InsightVariable variable;

  /// Valid (non-null) observations inside the window.
  final int observations;

  /// The engine's minimum ([BaselineConfig.minCalibrationPoints]).
  final int required;

  /// The window length in days ([BaselineConfig.windowSize]).
  final int windowDays;

  /// The engine's rolling median at the end of the window, or null when there
  /// are fewer than [required] observations.
  final double? baseline;

  /// The engine's MAD-based scale at the end of the window, or null.
  final double? scale;

  /// The most recent observation in the window and its local date.
  final double? latestValue;
  final String? latestDate;

  /// The engine's z-score for [latestValue], or null when insufficient.
  final double? latestZ;

  /// `1.4826 × MAD` of the window's valid observations around the engine's
  /// median (the robust scale before the engine's fallback), or null when
  /// insufficient.
  final double? robustScale;

  const VariableBaseline({
    required this.variable,
    required this.observations,
    required this.required,
    required this.windowDays,
    this.baseline,
    this.scale,
    this.latestValue,
    this.latestDate,
    this.latestZ,
    this.robustScale,
  });

  bool get sufficient => baseline != null;

  BaselineState get state {
    if (!sufficient) return BaselineState.insufficientObservations;
    final r = robustScale;
    return r != null && r > kEngineMadFloor ? BaselineState.usable : BaselineState.degenerateDispersion;
  }

  /// Within, above or below (see [kBaselineBandZ]) only when [state] is
  /// [BaselineState.usable]; null otherwise, so the engine's fallback scale
  /// is never read as a meaningful deviation.
  BaselinePosition? get position {
    final z = latestZ;
    if (state != BaselineState.usable || z == null) return null;
    if (z >= kBaselineBandZ) return BaselinePosition.above;
    if (z <= -kBaselineBandZ) return BaselinePosition.below;
    return BaselinePosition.within;
  }
}

/// Applies the existing engine to one variable's observations.
class PersonalBaselineAnalyzer {
  final PersonalBaselineEngine engine;
  const PersonalBaselineAnalyzer({this.engine = const PersonalBaselineEngine()});

  int get windowDays => engine.config.windowSize;
  int get required => engine.config.minCalibrationPoints;

  /// The [windowDays] local dates ending at [endDate] (`YYYY-MM-DD`), oldest
  /// first, by calendar arithmetic (month ends and DST do not matter).
  List<String> windowDates(String endDate) {
    final p = endDate.split('-').map(int.parse).toList();
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return [for (var i = windowDays - 1; i >= 0; i--) fmt(DateTime(p[0], p[1], p[2] - i))];
  }

  /// Analyses [values] (local date to value; absent or null means missing)
  /// over [dates] (the window, oldest first, as from [windowDates]).
  /// Values outside [dates] are ignored.
  VariableBaseline analyze(InsightVariable variable, List<String> dates, Map<String, double?> values) {
    if (dates.length != windowDays) {
      throw ArgumentError('expected $windowDays dates, got ${dates.length}');
    }
    final series = [for (final d in dates) values[d]];
    final count = series.whereType<double>().length;
    final latestIndex = series.lastIndexWhere((v) => v != null);
    final result = engine.computeRollingMadBaseline(series);
    final last = series.length - 1;
    // The robust scale the engine would have used before its fallback: the
    // MAD of the window's valid values around the engine's own median. (The
    // window covers every value, so it is the window the engine used for the
    // latest observation too.)
    double? robust;
    final median = result.locations[last];
    if (median != null) {
      final deviations = [for (final v in series.whereType<double>()) (v - median).abs()]..sort();
      final n = deviations.length;
      final mad = n.isOdd ? deviations[n ~/ 2] : (deviations[n ~/ 2 - 1] + deviations[n ~/ 2]) / 2;
      robust = 1.4826 * mad;
    }
    return VariableBaseline(
      variable: variable,
      observations: count,
      required: required,
      windowDays: windowDays,
      baseline: result.locations[last],
      scale: result.scales[last],
      latestValue: latestIndex < 0 ? null : series[latestIndex],
      latestDate: latestIndex < 0 ? null : dates[latestIndex],
      latestZ: latestIndex < 0 ? null : result.zScores[latestIndex],
      robustScale: robust,
    );
  }
}
