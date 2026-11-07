import 'package:test/test.dart';
import '../lib/domain/baseline_engine.dart';

void main() {
  group('PersonalBaselineEngine Dart Tests', () {
    test('computeMad scales median absolute deviation', () {
      final values = [10.0, 10.2, 9.8, 10.1, 9.9, 100.0]; // Outlier 100.0
      final scale = PersonalBaselineEngine.computeMad(values);
      expect(scale, lessThan(1.0)); // Resistant to outlier
    });

    test('computeRollingMadBaseline enforces causal lookback', () {
      const engine = PersonalBaselineEngine(config: BaselineConfig(windowSize: 5, minCalibrationPoints: 3));
      final series = <double?>[2.0, 2.0, 2.0, 2.0, 10.0, 10.0, 10.0];
      final res = engine.computeRollingMadBaseline(series);

      expect(res.locations[2], equals(2.0));
      expect(res.locations[3], equals(2.0));
      expect(res.zScores[4]!, greaterThan(2.0)); // Acute step produces elevated z-score
    });

    test('applyCusumFilter suppresses 1-day acute transient spike', () {
      const engine = PersonalBaselineEngine(config: BaselineConfig(cusumThresholdH: 3.5, cusumAllowanceK: 0.5));
      final zTransient = <double?>[0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0];
      final resTransient = engine.applyCusumFilter(zTransient);

      expect(resTransient.alerts.any((a) => a), isFalse);

      final zSustained = <double?>[0.0, 0.0, 0.0, 2.0, 2.5, 2.5, 2.5, 3.0];
      final resSustained = engine.applyCusumFilter(zSustained);

      expect(resSustained.alerts.last, isTrue); // Sustained drift triggers alert
    });
  });
}
