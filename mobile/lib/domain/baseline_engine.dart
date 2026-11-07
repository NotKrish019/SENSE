import 'dart:math' as math;

/// Dart implementation of the Personal Baseline and Change Detection Engine.
/// Ports the Phase 1 verified Python engine to Dart for on-device execution.
class BaselineConfig {
  final int windowSize;
  final double ewmaAlpha;
  final int minCalibrationPoints;
  final double cusumAllowanceK;
  final double cusumThresholdH;
  final double epsilon;

  const BaselineConfig({
    this.windowSize = 14,
    this.ewmaAlpha = 0.15,
    this.minCalibrationPoints = 7,
    this.cusumAllowanceK = 0.5,
    this.cusumThresholdH = 3.5,
    this.epsilon = 1e-4,
  });
}

class BaselineResult {
  final List<double?> locations;
  final List<double?> scales;
  final List<double?> zScores;

  const BaselineResult({
    required this.locations,
    required this.scales,
    required this.zScores,
  });
}

class CusumResult {
  final List<double> cusumValues;
  final List<bool> alerts;

  const CusumResult({
    required this.cusumValues,
    required this.alerts,
  });
}

class PersonalBaselineEngine {
  final BaselineConfig config;

  const PersonalBaselineEngine({this.config = const BaselineConfig()});

  /// Computes Median Absolute Deviation (MAD) scaled to standard deviation
  static double computeMad(List<double> values) {
    if (values.length < 2) return 1.0;
    final sorted = List<double>.from(values)..sort();
    final med = _getMedian(sorted);

    final deviations = sorted.map((x) => (x - med).abs()).toList()..sort();
    final mad = _getMedian(deviations);
    final scale = 1.4826 * mad;
    if (scale > 1e-4) return scale;

    // Fallback standard deviation
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance) + 1e-4;
  }

  static double _getMedian(List<double> sorted) {
    final n = sorted.length;
    if (n % 2 == 1) return sorted[n ~/ 2];
    return (sorted[(n ~/ 2) - 1] + sorted[n ~/ 2]) / 2.0;
  }

  /// Model B: Rolling Median & MAD Baseline
  BaselineResult computeRollingMadBaseline(List<double?> series) {
    final n = series.length;
    final w = config.windowSize;
    final locations = List<double?>.filled(n, null);
    final scales = List<double?>.filled(n, null);
    final zScores = List<double?>.filled(n, null);

    for (int i = 0; i < n; i++) {
      final startIdx = math.max(0, i - w + 1);
      final window = series.sublist(startIdx, i + 1).whereType<double>().toList();

      if (window.length >= config.minCalibrationPoints) {
        final sorted = List<double>.from(window)..sort();
        final med = _getMedian(sorted);
        final scale = computeMad(window);

        locations[i] = med;
        scales[i] = scale;

        final currVal = series[i];
        if (currVal != null) {
          zScores[i] = (currVal - med) / math.max(scale, config.epsilon);
        }
      }
    }

    return BaselineResult(locations: locations, scales: scales, zScores: zScores);
  }

  /// Model C: Exponentially Weighted Moving Average (EWMA) with adaptive variance
  BaselineResult computeEwmaBaseline(List<double?> series) {
    final n = series.length;
    final alpha = config.ewmaAlpha;
    final locations = List<double?>.filled(n, null);
    final scales = List<double?>.filled(n, null);
    final zScores = List<double?>.filled(n, null);

    double? currMean;
    double? currVar;
    int observedCount = 0;

    for (int i = 0; i < n; i++) {
      final val = series[i];
      if (val != null) {
        observedCount++;
        if (currMean == null) {
          currMean = val;
          currVar = 1.0;
        } else {
          final diff = val - currMean;
          currMean = alpha * val + (1.0 - alpha) * currMean;
          currVar = (1.0 - alpha) * (currVar! + alpha * math.pow(diff, 2));
        }

        if (observedCount >= config.minCalibrationPoints) {
          locations[i] = currMean;
          final std = math.sqrt(math.max(currVar!, config.epsilon));
          scales[i] = std;
          zScores[i] = (val - currMean) / math.max(std, config.epsilon);
        }
      } else {
        if (currMean != null && observedCount >= config.minCalibrationPoints) {
          locations[i] = currMean;
          scales[i] = math.sqrt(math.max(currVar!, config.epsilon));
        }
      }
    }

    return BaselineResult(locations: locations, scales: scales, zScores: zScores);
  }

  /// Sequential CUSUM Temporal Persistence Filter
  CusumResult applyCusumFilter(List<double?> zSeries) {
    final n = zSeries.length;
    final k = config.cusumAllowanceK;
    final h = config.cusumThresholdH;

    final cusum = List<double>.filled(n, 0.0);
    final alerts = List<bool>.filled(n, false);

    for (int i = 0; i < n; i++) {
      final z = zSeries[i];
      if (z == null) {
        cusum[i] = (i > 0) ? math.max(0.0, cusum[i - 1] * 0.8) : 0.0;
      } else {
        final prevC = (i > 0) ? cusum[i - 1] : 0.0;
        cusum[i] = math.max(0.0, prevC + z - k);
      }

      if (cusum[i] >= h) {
        if (i >= 2 && zSeries[i - 1] != null && z != null) {
          final prevZ = zSeries[i - 2] ?? zSeries[i - 1]!;
          final trend = z - prevZ;
          if (trend >= -0.5) {
            alerts[i] = true;
          }
        } else {
          alerts[i] = true;
        }
      }
    }

    return CusumResult(cusumValues: cusum, alerts: alerts);
  }
}

