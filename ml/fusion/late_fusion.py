"""
Dynamic Reliability-Weighted Late Decision Fusion & Explainability Engine.
Integrates asynchronous multimodal signals, calculates epistemic uncertainty,
and generates factor-attributed natural language explanations.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
import numpy as np


@dataclass
class FusionConfig:
    """Prior weights and settings for late decision fusion."""
    # Prior modality weights summing to 1.0
    prior_weights: Dict[str, float] = field(default_factory=lambda: {
        "check_in": 0.30,   # M1: Structured Check-ins
        "sleep": 0.25,      # M3: Sleep Metrics
        "workload": 0.20,   # M4: Cognitive Workload
        "journal": 0.10,    # M2: Reflective Text
        "voice": 0.10,      # M5: Acoustic Prosody
        "activity": 0.05,   # M6: Physical Steps
    })
    # Directions: +1 if higher feature value means higher stress; -1 if lower value means higher stress
    modality_directions: Dict[str, float] = field(default_factory=lambda: {
        "check_in": +1.0,   # High stress rating -> higher stress
        "sleep": -1.0,      # Low sleep hours -> higher stress
        "workload": +1.0,   # High workload -> higher stress
        "journal": -1.0,    # Negative sentiment -> higher stress
        "voice": -1.0,      # Compressed pitch variability -> higher stress
        "activity": -1.0,   # Low steps -> higher stress
    })
    uncertainty_threshold: float = 0.65  # If missing weight > 65%, suppress alert
    alert_composite_threshold: float = 0.68  # Composite score threshold for shift alert


@dataclass
class FusionOutput:
    """Structured result of late fusion for a single temporal epoch."""
    composite_stress_score: float
    is_alert_triggered: bool
    epistemic_uncertainty: float
    observed_modalities: List[str]
    missing_modalities: List[str]
    factor_attributions: Dict[str, float]  # Modality -> delta contribution
    primary_contributor: str
    explanation_narrative: str


class DynamicLateFusionEngine:
    """
    Combines standardized modality deviations into an integrated well-being composite score.
    Maintains graceful degradation under missing modalities without imputing false signals.
    """

    def __init__(self, config: Optional[FusionConfig] = None):
        self.config = config or FusionConfig()

    @staticmethod
    def sigmoid(x: float) -> float:
        """Standard logistic sigmoid function mapping z-score to probability [0, 1]."""
        # Guard against overflow
        clamped = max(-10.0, min(10.0, x))
        return 1.0 / (1.0 + np.exp(-clamped))

    def fuse_epoch(
        self,
        modality_z_scores: Dict[str, Optional[float]],
        modality_qualities: Optional[Dict[str, float]] = None,
    ) -> FusionOutput:
        """
        Executes dynamic reliability-weighted late fusion for a single day.
        
        Args:
            modality_z_scores: Dict mapping modality name to its standardized z-score (or None if missing).
            modality_qualities: Dict mapping modality name to data quality/confidence r in (0, 1].
        """
        qualities = modality_qualities or {}
        priors = self.config.prior_weights
        directions = self.config.modality_directions

        observed_modalities: List[str] = []
        missing_modalities: List[str] = []
        weighted_scores_sum = 0.0
        weight_normalizer = 0.0
        observed_prior_sum = 0.0

        modality_stress_probs: Dict[str, float] = {}

        for mod, prior_w in priors.items():
            z_val = modality_z_scores.get(mod)
            if z_val is not None and not np.isnan(z_val):
                observed_modalities.append(mod)
                observed_prior_sum += prior_w
                r_qual = max(0.1, min(1.0, qualities.get(mod, 1.0)))
                effective_weight = prior_w * r_qual

                # Orient z-score so positive indicates elevated stress
                dir_factor = directions.get(mod, 1.0)
                directed_z = z_val * dir_factor

                # Convert to stress probability in [0, 1]
                prob = self.sigmoid(directed_z)
                modality_stress_probs[mod] = prob

                weighted_scores_sum += effective_weight * prob
                weight_normalizer += effective_weight
            else:
                missing_modalities.append(mod)

        # Handle zero observed modalities
        if weight_normalizer == 0.0:
            return FusionOutput(
                composite_stress_score=0.5,
                is_alert_triggered=False,
                epistemic_uncertainty=1.0,
                observed_modalities=[],
                missing_modalities=list(priors.keys()),
                factor_attributions={},
                primary_contributor="none",
                explanation_narrative="No observations recorded today. Baseline remains unchanged.",
            )

        composite_score = float(weighted_scores_sum / weight_normalizer)
        epistemic_uncertainty = float(1.0 - observed_prior_sum)

        # Compute factor attributions (deviation from neutral 0.5)
        attributions: Dict[str, float] = {}
        for mod in observed_modalities:
            prob = modality_stress_probs[mod]
            r_qual = qualities.get(mod, 1.0)
            norm_w = (priors[mod] * r_qual) / weight_normalizer
            attributions[mod] = float(norm_w * (prob - 0.5))

        # Find primary contributor (modality driving stress highest above neutral)
        primary_mod = "none"
        if attributions:
            sorted_contributors = sorted(attributions.items(), key=lambda x: x[1], reverse=True)
            if sorted_contributors[0][1] > 0.02:
                primary_mod = sorted_contributors[0][0]

        # Determine alert trigger condition
        is_alert = (
            composite_score >= self.config.alert_composite_threshold
            and epistemic_uncertainty <= self.config.uncertainty_threshold
        )

        narrative = self.generate_narrative(
            composite_score=composite_score,
            is_alert=is_alert,
            uncertainty=epistemic_uncertainty,
            attributions=attributions,
            observed=observed_modalities,
        )

        return FusionOutput(
            composite_stress_score=round(composite_score, 4),
            is_alert_triggered=is_alert,
            epistemic_uncertainty=round(epistemic_uncertainty, 4),
            observed_modalities=observed_modalities,
            missing_modalities=missing_modalities,
            factor_attributions={k: round(v, 4) for k, v in attributions.items()},
            primary_contributor=primary_mod,
            explanation_narrative=narrative,
        )

    def generate_narrative(
        self,
        composite_score: float,
        is_alert: bool,
        uncertainty: float,
        attributions: Dict[str, float],
        observed: List[str],
    ) -> str:
        """
        Synthesizes an evidence-grounded, non-alarmist natural language explanation card.
        """
        if uncertainty > self.config.uncertainty_threshold:
            return (
                f"We observed limited data today ({', '.join(observed)}). "
                f"Observations remain within your typical bounds, but more check-ins will increase confidence."
            )

        modality_human_names = {
            "check_in": "subjective stress check-ins",
            "sleep": "sleep duration and rest consistency",
            "workload": "reported cognitive task demands",
            "journal": "emotional tone in your journal reflections",
            "voice": "speech pitch variability",
            "activity": "daily physical movement",
        }

        if is_alert:
            # Rank top two stressors
            top_factors = sorted([item for item in attributions.items() if item[1] > 0], key=lambda x: x[1], reverse=True)
            if top_factors:
                primary = modality_human_names.get(top_factors[0][0], top_factors[0][0])
                secondary_phrase = ""
                if len(top_factors) > 1:
                    secondary = modality_human_names.get(top_factors[1][0], top_factors[1][0])
                    secondary_phrase = f", combined with shifts in your {secondary}"
                
                return (
                    f"Your recorded patterns indicate an elevated stress pattern relative to your personal baseline. "
                    f"The primary factor is a noticeable change in your {primary}{secondary_phrase}. "
                    f"Consider scheduling intentional micro-breaks and prioritizing restorative rest this evening."
                )
            return "Your recorded well-being indicators show sustained deviation from your personal historical equilibrium."

        # Notable shift in a single modality even if composite alert threshold is not crossed
        top_positive = sorted([item for item in attributions.items() if item[1] > 0.04], key=lambda x: x[1], reverse=True)
        if top_positive:
            primary_name = modality_human_names.get(top_positive[0][0], top_positive[0][0])
            return (
                f"Your daily indicators remain mostly within your historical corridor, "
                f"though we observed an isolated shift in your {primary_name}."
            )

        if composite_score < 0.40:
            return "Your recorded rest, mood, and daily indicators are comfortably aligned with or better than your personal baseline."

        return "Your daily indicators remain within your normal historical equilibrium corridor."
