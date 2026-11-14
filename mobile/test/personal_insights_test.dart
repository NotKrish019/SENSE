// Milestone E: the pure mapping from a person's observations to the existing
// PersonalBaselineEngine (14-day window, 7 required observations, rolling
// median/MAD). Results are compared with the engine's own output; nothing is
// re-derived here.

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/domain/baseline_engine.dart';
import 'package:mindpulse/domain/personal_insights.dart';

void main() {
  const analyzer = PersonalBaselineAnalyzer();
  final dates = analyzer.windowDates('2026-11-11');

  Map<String, double?> on(Map<int, double?> byIndex) => {for (final e in byIndex.entries) dates[e.key]: e.value};

  test('the engine configuration is used as is: 14-day window, 7 required', () {
    const config = BaselineConfig();
    expect([config.windowSize, config.minCalibrationPoints], [14, 7]);
    expect([analyzer.windowDays, analyzer.required], [14, 7]);
  });

  test('window dates: 14 local days ending today, oldest first, across a month boundary', () {
    expect(dates.first, '2026-10-29');
    expect(dates.last, '2026-11-11');
    expect(dates, hasLength(14));
    final dec = analyzer.windowDates('2026-12-02');
    expect([dec.first, dec.last], ['2026-11-19', '2026-12-02']);
    expect(analyzer.windowDates('2026-03-01').first, '2026-02-16');
  });

  test('no observations: insufficient, nothing invented', () {
    final r = analyzer.analyze(InsightVariable.mood, dates, {});
    expect(r.observations, 0);
    expect(r.sufficient, isFalse);
    expect([r.baseline, r.scale, r.latestValue, r.latestDate, r.latestZ, r.position], everyElement(isNull));
  });

  test('fewer than 7 valid observations: insufficient; the count is reported', () {
    final r = analyzer.analyze(InsightVariable.mood, dates, on({0: 3, 3: 4, 5: 2, 8: 3, 10: 3, 13: 4}));
    expect(r.observations, 6);
    expect(r.required, 7);
    expect(r.sufficient, isFalse);
    expect(r.baseline, isNull);
    expect(r.position, isNull);
    expect([r.latestValue, r.latestDate], [4.0, '2026-11-11'], reason: 'the latest entry is still known');
  });

  test('exactly 7 valid observations: the engine baseline appears and matches the engine output', () {
    final values = on({1: 3, 3: 3, 5: 4, 7: 3, 9: 2, 11: 3, 12: 5});
    final r = analyzer.analyze(InsightVariable.perceivedStress, dates, values);
    expect(r.observations, 7);
    expect(r.sufficient, isTrue);
    final engine = const PersonalBaselineEngine().computeRollingMadBaseline([for (final d in dates) values[d]]);
    expect(r.baseline, engine.locations.last);
    expect(r.scale, engine.scales.last);
    expect(r.baseline, 3.0, reason: 'median of 2,3,3,3,3,4,5');
    expect([r.latestValue, r.latestDate], [5.0, '2026-11-10']);
    expect(r.latestZ, engine.zScores[12]);
    // Five of the seven are 3: MAD is zero, so the engine fell back and the
    // z-score (about 1.9) is not a usable direction.
    expect(r.robustScale, 0.0);
    expect(r.state, BaselineState.degenerateDispersion);
    expect(r.position, isNull);
  });

  test('missing days and missing measurements are missing (null), never zero', () {
    // Seven real 3s plus explicit nulls: a zero would pull the median down.
    final r = analyzer.analyze(
        InsightVariable.deadlines, dates, on({0: 3, 1: null, 2: 3, 4: 3, 6: null, 7: 3, 9: 3, 11: 3, 13: 3}));
    expect(r.observations, 7);
    expect(r.baseline, 3.0);
    expect(r.state, BaselineState.degenerateDispersion, reason: 'all seven identical');
    expect(r.position, isNull);
  });

  test('zero is a real value (deadlines) and is counted', () {
    final r = analyzer.analyze(InsightVariable.deadlines, dates, on({for (var i = 0; i < 7; i++) i * 2: 0.0}));
    expect(r.observations, 7);
    expect(r.baseline, 0.0);
  });

  test('values outside the window are ignored', () {
    final values = <String, double?>{
      '2026-10-28': 1, '2026-10-01': 1, '2026-11-12': 1, // outside
      for (var i = 0; i < 6; i++) dates[i * 2]: 4,
    };
    final r = analyzer.analyze(InsightVariable.mood, dates, values);
    expect(r.observations, 6);
    expect(r.sufficient, isFalse);
  });

  test('with a robust (MAD) scale, within, above and below follow the engine z-score and the display band', () {
    VariableBaseline of(double latest) => analyzer.analyze(
        InsightVariable.restQuality, dates, on({0: 2, 2: 4, 4: 3, 6: 1, 8: 3, 10: 5, 12: 2, 13: latest}));
    for (final latest in [3.0, 5.0, 1.0]) {
      expect(of(latest).state, BaselineState.usable, reason: '$latest');
      expect(of(latest).robustScale, greaterThan(kEngineMadFloor));
    }
    expect(of(3).position, BaselinePosition.within);
    expect(of(5).position, BaselinePosition.above);
    expect(of(1).position, BaselinePosition.below);
    expect(kBaselineBandZ, 1.0);
  });

  group('Degenerate dispersion (zero MAD)', () {
    List<double?> padded(List<double> tail) => [...List<double?>.filled(14 - tail.length, null), ...tail];
    VariableBaseline series(List<double?> s) =>
        analyzer.analyze(InsightVariable.mood, dates, {for (var i = 0; i < 14; i++) dates[i]: s[i]});

    test("the engine's own representation: identical values give exactly its 1e-4 floor; a MAD scale is 1.4826 x MAD",
        () {
      expect(PersonalBaselineEngine.computeMad(List.filled(7, 3.0)), kEngineMadFloor);
      expect(PersonalBaselineEngine.computeMad([2, 3, 4, 3, 2, 4, 5]), closeTo(1.4826 * 1.0, 1e-12));
      // Zero MAD with some variation: the engine falls back to the standard deviation (+1e-4), not to MAD.
      final fallback = PersonalBaselineEngine.computeMad([3, 3, 3, 3, 3, 1, 5]);
      expect(fallback, greaterThan(1.0));
      expect(fallback, isNot(closeTo(0.0, 1e-9)));
    });

    test('all observations identical: baseline and latest shown, no direction', () {
      final r = series(padded(List.filled(8, 3.0)));
      expect(r.state, BaselineState.degenerateDispersion);
      expect([r.baseline, r.scale, r.robustScale, r.latestValue, r.latestZ], [3.0, kEngineMadFloor, 0.0, 3.0, 0.0]);
      expect(r.position, isNull, reason: 'not "within" a range of zero width');
    });

    test('MAD exactly zero but some variation (engine fallback scale): no direction from the fallback z', () {
      final r = series(padded([3, 3, 3, 3, 3, 1, 5]));
      expect(r.robustScale, 0.0);
      expect(r.scale, greaterThan(1.0), reason: "the engine's fallback standard deviation");
      expect(r.latestZ, greaterThan(kBaselineBandZ), reason: 'the fallback z alone would have said "above"');
      expect(r.state, BaselineState.degenerateDispersion);
      expect(r.position, isNull);
    });

    test('a one-point change after a constant run: no false "above" (and no false "below")', () {
      final up1 = series([...List.filled(13, 3.0), 4.0]);
      final up2 = series([...List.filled(13, 3.0), 5.0]);
      final down = series([...List.filled(13, 3.0), 2.0]);
      // The fallback z barely depends on the size of the change: it only says the latest is the outlier.
      expect(up1.latestZ, closeTo(3.88, 0.01));
      expect(up2.latestZ, closeTo(3.88, 0.01));
      expect(down.latestZ, closeTo(-3.88, 0.01));
      for (final r in [up1, up2, down]) {
        expect(r.state, BaselineState.degenerateDispersion);
        expect(r.position, isNull);
        expect(r.baseline, 3.0);
      }
      expect([up1.latestValue, up2.latestValue, down.latestValue], [4.0, 5.0, 2.0]);
    });

    test('sleep hours: a constant 7.5 then 8.0 is degenerate too (0.5 h steps)', () {
      final r = analyzer.analyze(InsightVariable.sleepDuration, dates,
          {for (var i = 0; i < 14; i++) dates[i]: i == 13 ? 8.0 : 7.5});
      expect(r.state, BaselineState.degenerateDispersion);
      expect(r.position, isNull);
    });

    test('non-zero dispersion: a valid directional comparison', () {
      final r = series(padded([2, 3, 4, 3, 2, 4, 5]));
      expect(r.state, BaselineState.usable);
      expect(r.robustScale, closeTo(1.4826, 1e-12));
      expect(r.scale, r.robustScale, reason: 'the engine used its MAD scale');
      expect(r.latestZ, closeTo((5 - 3) / 1.4826, 1e-12));
      expect(r.position, BaselinePosition.above);
    });

    test('insufficient observations stay distinct from degenerate dispersion', () {
      final few = series(padded(List.filled(6, 3.0)));
      expect(few.state, BaselineState.insufficientObservations);
      expect([few.baseline, few.robustScale, few.position], [null, null, null]);
      final enough = series(padded(List.filled(7, 3.0)));
      expect(enough.state, BaselineState.degenerateDispersion);
    });
  });

  test('each variable is tied to its stored field and consent modality', () {
    expect({for (final v in InsightVariable.values) v.field: v.modality}, {
      'mood_rating': 'M1',
      'motivation_energy_rating': 'M1',
      'perceived_stress_rating': 'M1',
      'duration_minutes': 'M3',
      'rest_quality': 'M3',
      'mental_demand': 'M4',
      'effort': 'M4',
      'deadlines_48h': 'M4',
    });
  });

  test('the window must be the engine window', () {
    expect(() => analyzer.analyze(InsightVariable.mood, dates.sublist(1), {}), throwsArgumentError);
  });
}
