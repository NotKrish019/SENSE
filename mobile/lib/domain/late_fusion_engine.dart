import 'dart:math' as math;

/// Prior weights and configuration for multimodal late decision fusion.
class FusionConfig {
  final Map<String, double> priorWeights;
  final Map<String, double> modalityDirections;
  final double uncertaintyThreshold;
  final double alertCompositeThreshold;

  const FusionConfig({
    this.priorWeights = const {
      'check_in': 0.30,
      'sleep': 0.25,
      'workload': 0.20,
      'journal': 0.10,
      'voice': 0.10,
      'activity': 0.05,
    },
    this.modalityDirections = const {
      'check_in': 1.0,
      'sleep': -1.0,
      'workload': 1.0,
      'journal': -1.0,
      'voice': -1.0,
      'activity': -1.0,
    },
    this.uncertaintyThreshold = 0.65,
    this.alertCompositeThreshold = 0.68,
  });
}

class FusionOutput {
  final double compositeStressScore;
  final bool isAlertTriggered;
  final double epistemicUncertainty;
  final List<String> observedModalities;
  final List<String> missingModalities;
  final Map<String, double> factorAttributions;
  final String primaryContributor;
  final String explanationNarrative;

  const FusionOutput({
    required this.compositeStressScore,
    required this.isAlertTriggered,
    required this.epistemicUncertainty,
    required this.observedModalities,
    required this.missingModalities,
    required this.factorAttributions,
    required this.primaryContributor,
    required this.explanationNarrative,
  });
}

class DynamicLateFusionEngine {
  final FusionConfig config;

  const DynamicLateFusionEngine({this.config = const FusionConfig()});

  static double sigmoid(double x) {
    final clamped = math.max(-10.0, math.min(10.0, x));
    return 1.0 / (1.0 + math.exp(-clamped));
  }

  FusionOutput fuseEpoch(
    Map<String, double?> modalityZScores, [
    Map<String, double>? modalityQualities,
  ]) {
    final qualities = modalityQualities ?? {};
    final priors = config.priorWeights;
    final directions = config.modalityDirections;

    final observedModalities = <String>[];
    final missingModalities = <String>[];
    double weightedScoresSum = 0.0;
    double weightNormalizer = 0.0;
    double observedPriorSum = 0.0;

    final modalityStressProbs = <String, double>{};

    for (final entry in priors.entries) {
      final mod = entry.key;
      final priorW = entry.value;
      final zVal = modalityZScores[mod];

      if (zVal != null) {
        observedModalities.add(mod);
        observedPriorSum += priorW;
        final rQual = math.max(0.1, math.min(1.0, qualities[mod] ?? 1.0));
        final effectiveWeight = priorW * rQual;

        final dirFactor = directions[mod] ?? 1.0;
        final directedZ = zVal * dirFactor;

        final prob = sigmoid(directedZ);
        modalityStressProbs[mod] = prob;

        weightedScoresSum += effectiveWeight * prob;
        weightNormalizer += effectiveWeight;
      } else {
        missingModalities.add(mod);
      }
    }

    if (weightNormalizer == 0.0) {
      return FusionOutput(
        compositeStressScore: 0.5,
        isAlertTriggered: false,
        epistemicUncertainty: 1.0,
        observedModalities: [],
        missingModalities: priors.keys.toList(),
        factorAttributions: {},
        primaryContributor: 'none',
        explanationNarrative: 'No observations recorded today. Baseline remains unchanged.',
      );
    }

    final compositeScore = weightedScoresSum / weightNormalizer;
    final epistemicUncertainty = 1.0 - observedPriorSum;

    final attributions = <String, double>{};
    for (final mod in observedModalities) {
      final prob = modalityStressProbs[mod]!;
      final rQual = qualities[mod] ?? 1.0;
      final normW = (priors[mod]! * rQual) / weightNormalizer;
      attributions[mod] = normW * (prob - 0.5);
    }

    String primaryMod = 'none';
    if (attributions.isNotEmpty) {
      final sorted = attributions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.first.value > 0.02) {
        primaryMod = sorted.first.key;
      }
    }

    final isAlert = compositeScore >= config.alertCompositeThreshold &&
        epistemicUncertainty <= config.uncertaintyThreshold;

    final narrative = generateNarrative(
      compositeScore: compositeScore,
      isAlert: isAlert,
      uncertainty: epistemicUncertainty,
      attributions: attributions,
      observed: observedModalities,
    );

    return FusionOutput(
      compositeStressScore: double.parse(compositeScore.toStringAsFixed(4)),
      isAlertTriggered: isAlert,
      epistemicUncertainty: double.parse(epistemicUncertainty.toStringAsFixed(4)),
      observedModalities: observedModalities,
      missingModalities: missingModalities,
      factorAttributions: attributions.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(4)))),
      primaryContributor: primaryMod,
      explanationNarrative: narrative,
    );
  }

  String generateNarrative({
    required double compositeScore,
    required bool isAlert,
    required double uncertainty,
    required Map<String, double> attributions,
    required List<String> observed,
  }) {
    if (uncertainty > config.uncertaintyThreshold) {
      return 'We observed limited data today (${observed.join(', ')}). '
          'Observations remain within your typical bounds, but more daily check-ins will increase confidence.';
    }

    const modalityHumanNames = {
      'check_in': 'subjective stress check-ins',
      'sleep': 'sleep duration and rest consistency',
      'workload': 'reported cognitive task demands',
      'journal': 'emotional tone in your journal reflections',
      'voice': 'speech pitch variability',
      'activity': 'daily physical movement',
    };

    if (isAlert) {
      final topFactors = attributions.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (topFactors.isNotEmpty) {
        final primary = modalityHumanNames[topFactors[0].key] ?? topFactors[0].key;
        String secondaryPhrase = '';
        if (topFactors.length > 1) {
          final secondary = modalityHumanNames[topFactors[1].key] ?? topFactors[1].key;
          secondaryPhrase = ', combined with shifts in your $secondary';
        }

        return 'Your recorded patterns indicate an elevated stress pattern relative to your personal baseline. '
            'The primary factor is a noticeable change in your $primary$secondaryPhrase. '
            'Consider scheduling intentional micro-breaks and prioritizing restorative rest this evening.';
      }
      return 'Your recorded well-being indicators show sustained deviation from your personal historical equilibrium.';
    }

    final topPositive = attributions.entries.where((e) => e.value > 0.04).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (topPositive.isNotEmpty) {
      final primaryName = modalityHumanNames[topPositive[0].key] ?? topPositive[0].key;
      return 'Your daily indicators remain mostly within your historical corridor, '
          'though we observed an isolated shift in your $primaryName.';
    }

    if (compositeScore < 0.40) {
      return 'Your recorded rest, mood, and daily indicators are comfortably aligned with or better than your personal baseline.';
    }

    return 'Your daily indicators remain within your normal historical equilibrium corridor.';
  }
}

