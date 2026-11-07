import 'package:test/test.dart';
import '../lib/domain/late_fusion_engine.dart';

void main() {
  group('DynamicLateFusionEngine Dart Tests', () {
    test('neutral inputs yield 0.5 composite score and 0 uncertainty', () {
      const engine = DynamicLateFusionEngine();
      final zDict = {
        'check_in': 0.0,
        'sleep': 0.0,
        'workload': 0.0,
        'journal': 0.0,
        'voice': 0.0,
        'activity': 0.0,
      };

      final out = engine.fuseEpoch(zDict);
      expect(out.compositeStressScore, closeTo(0.50, 0.01));
      expect(out.epistemicUncertainty, equals(0.0));
      expect(out.isAlertTriggered, isFalse);
    });

    test('gracefully handles missing modalities without false alert', () {
      const engine = DynamicLateFusionEngine();
      // Only check-in and sleep observed (prior weights: 0.30 + 0.25 = 0.55 observed)
      final zDict = {
        'check_in': 1.0,
        'sleep': -1.0,
        'workload': null,
        'journal': null,
        'voice': null,
        'activity': null,
      };

      final out = engine.fuseEpoch(zDict);
      expect(out.observedModalities, contains('check_in'));
      expect(out.observedModalities, contains('sleep'));
      expect(out.missingModalities, contains('workload'));
      expect(out.epistemicUncertainty, closeTo(0.45, 0.01));
    });

    test('factor attribution detects top contributing modality', () {
      const engine = DynamicLateFusionEngine();
      final zDict = {
        'check_in': 0.0,
        'sleep': 0.0,
        'workload': 3.0,
        'journal': 0.0,
        'voice': 0.0,
        'activity': 0.0,
      };

      final out = engine.fuseEpoch(zDict);
      expect(out.primaryContributor, equals('workload'));
      expect(out.explanationNarrative, contains('cognitive task demands'));
    });
  });
}

