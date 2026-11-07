import '../lib/core/safety/crisis_service.dart';
import '../lib/domain/baseline_engine.dart';
import '../lib/domain/late_fusion_engine.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void assertTrue(bool condition, String name) {
    if (condition) {
      print('  [PASS] $name');
      passed++;
    } else {
      print('  [FAIL] $name');
      failed++;
    }
  }

  print('=== Running MindPulse Dart Unit Tests ===\n');

  // 1. Crisis Service Tests
  print('[1/3] Testing CrisisService...');
  assertTrue(
    CrisisService.containsCrisisMarkers('I want to kill myself tonight'),
    'Detects explicit self-harm statement',
  );
  assertTrue(
    CrisisService.containsCrisisMarkers('I want to die, nothing matters anymore'),
    'Detects suicide ideation phrase',
  );
  assertTrue(
    !CrisisService.containsCrisisMarkers('I had an exhausting day at work'),
    'Does not false alarm on benign work stress',
  );
  assertTrue(
    CrisisService.helplines.any((h) => h.phoneNumber == '14416'),
    'Includes Tele-MANAS (14416)',
  );
  assertTrue(
    CrisisService.helplines.any((h) => h.phoneNumber == '1800-599-0019'),
    'Includes KIRAN (1800-599-0019)',
  );

  // 2. Personal Baseline Engine Tests
  print('\n[2/3] Testing PersonalBaselineEngine...');
  final madScale = PersonalBaselineEngine.computeMad([10.0, 10.2, 9.8, 10.1, 9.9, 100.0]);
  assertTrue(madScale < 1.0, 'MAD is robust against extreme outlier');

  const baselineEngine = PersonalBaselineEngine(config: BaselineConfig(windowSize: 5, minCalibrationPoints: 3));
  final series = <double?>[2.0, 2.0, 2.0, 2.0, 10.0, 10.0, 10.0];
  final baselineRes = baselineEngine.computeRollingMadBaseline(series);
  assertTrue(baselineRes.locations[2] == 2.0, 'Rolling median at day 3 is 2.0 (causal lookback)');
  assertTrue(baselineRes.zScores[4]! > 2.0, 'Sudden step produces elevated z-score');

  // CUSUM Transient vs Sustained
  const cusumEngine = PersonalBaselineEngine(config: BaselineConfig(cusumThresholdH: 3.5, cusumAllowanceK: 0.5));
  final transientZ = <double?>[0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0];
  final cusumTransientRes = cusumEngine.applyCusumFilter(transientZ);
  assertTrue(!cusumTransientRes.alerts.any((a) => a), 'CUSUM completely suppresses 1-day acute transient spike');

  final sustainedZ = <double?>[0.0, 0.0, 0.0, 2.0, 2.5, 2.5, 2.5, 3.0];
  final cusumSustainedRes = cusumEngine.applyCusumFilter(sustainedZ);
  assertTrue(cusumSustainedRes.alerts.last, 'CUSUM triggers alert on sustained multi-day drift');

  // 3. Late Decision Fusion Engine Tests
  print('\n[3/3] Testing DynamicLateFusionEngine...');
  const fusionEngine = DynamicLateFusionEngine();
  final neutralZ = {
    'check_in': 0.0,
    'sleep': 0.0,
    'workload': 0.0,
    'journal': 0.0,
    'voice': 0.0,
    'activity': 0.0,
  };
  final neutralOut = fusionEngine.fuseEpoch(neutralZ);
  assertTrue(
    (neutralOut.compositeStressScore - 0.50).abs() < 0.02,
    'Neutral inputs produce ~0.50 composite score',
  );
  assertTrue(neutralOut.epistemicUncertainty == 0.0, 'Zero uncertainty when all modalities observed');

  // Missing Modality Handling
  final partialZ = {
    'check_in': 1.0,
    'sleep': -1.0,
    'workload': null,
    'journal': null,
    'voice': null,
    'activity': null,
  };
  final partialOut = fusionEngine.fuseEpoch(partialZ);
  assertTrue(partialOut.observedModalities.contains('check_in'), 'Records check_in as observed');
  assertTrue(partialOut.missingModalities.contains('workload'), 'Records workload as missing');
  assertTrue(
    (partialOut.epistemicUncertainty - 0.45).abs() < 0.02,
    'Epistemic uncertainty reflects missing weight fraction',
  );

  // Factor Attribution
  final workloadZ = {
    'check_in': 0.0,
    'sleep': 0.0,
    'workload': 3.0,
    'journal': 0.0,
    'voice': 0.0,
    'activity': 0.0,
  };
  final workloadOut = fusionEngine.fuseEpoch(workloadZ);
  assertTrue(workloadOut.primaryContributor == 'workload', 'Identifies workload as primary contributor');
  assertTrue(
    workloadOut.explanationNarrative.contains('cognitive task demands'),
    'Narrative explains workload contribution',
  );

  print('\n=================================================');
  print('Test Summary: $passed passed, $failed failed.');
  if (failed > 0) {
    throw StateError('$failed tests failed!');
  }
}
