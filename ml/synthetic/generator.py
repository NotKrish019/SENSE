"""
Synthetic Longitudinal Multi-Participant Cohort Generator.
Implements reproducible generation of multimodal ambulatory well-being time series.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
import numpy as np
import pandas as pd


@dataclass
class CohortConfig:
    """Configuration for synthetic cohort generation."""
    n_participants: int = 100
    n_days: int = 60
    seed: int = 42
    calibration_days: int = 14
    spike_day: int = 20
    drift_start_day: int = 35
    drift_duration_days: int = 10
    drift_prevalence: float = 0.35  # Fraction of participants experiencing sustained drift
    missingness_rate: float = 0.20  # Overall MCAR missingness rate


class SyntheticLongitudinalGenerator:
    """
    Generates realistic, longitudinally consistent, multimodal time-series data
    for evaluating personal baseline engines and late fusion algorithms.
    """

    def __init__(self, config: Optional[CohortConfig] = None):
        self.config = config or CohortConfig()
        self.rng = np.random.default_rng(self.config.seed)

    def generate_participant_profiles(self) -> pd.DataFrame:
        """
        Creates heterogeneous baseline latent traits for each participant.
        Reflects individual differences in baseline rest, stress disposition, and vocal pitch.
        """
        n = self.config.n_participants
        
        # Latent baseline set-points
        sleep_mean = self.rng.uniform(6.2, 8.5, size=n)
        sleep_std = self.rng.uniform(0.5, 1.2, size=n)
        
        stress_mean = self.rng.uniform(1.8, 3.2, size=n)
        stress_std = self.rng.uniform(0.4, 0.8, size=n)
        
        workload_mean = self.rng.uniform(2.0, 3.5, size=n)
        workload_std = self.rng.uniform(0.5, 0.9, size=n)
        
        f0_mean = self.rng.uniform(120.0, 240.0, size=n)  # Pitch in Hz
        f0_var_mean = self.rng.uniform(25.0, 45.0, size=n)  # Pitch variability SD in Hz
        
        steps_mean = self.rng.uniform(5000, 11000, size=n)
        steps_std = self.rng.uniform(1200, 2500, size=n)
        
        # Boolean indicator whether participant experiences sustained allostatic drift
        experiences_drift = self.rng.random(size=n) < self.config.drift_prevalence
        
        profiles = pd.DataFrame({
            "participant_id": [f"user_{i:03d}" for i in range(n)],
            "sleep_mean": sleep_mean,
            "sleep_std": sleep_std,
            "stress_mean": stress_mean,
            "stress_std": stress_std,
            "workload_mean": workload_mean,
            "workload_std": workload_std,
            "f0_mean": f0_mean,
            "f0_var_mean": f0_var_mean,
            "steps_mean": steps_mean,
            "steps_std": steps_std,
            "experiences_drift": experiences_drift,
        })
        return profiles

    def generate_cohort(self) -> pd.DataFrame:
        """
        Generates full longitudinal records across all participants and days.
        Injects:
          - Cyclic weekday vs weekend patterns
          - Scenario 1: Transient 1-day acute stress spike at day 20
          - Scenario 2: Multi-day allostatic drift at days 35-45 (for affected subset)
          - Ground truth labels: 0=Baseline, 1=Acute Spike, 2=Sustained Drift
        """
        profiles = self.generate_participant_profiles()
        rows: List[Dict] = []
        n_days = self.config.n_days

        for _, p in profiles.iterrows():
            uid = p["participant_id"]
            experiences_drift = p["experiences_drift"]

            for day in range(1, n_days + 1):
                day_of_week = (day - 1) % 7  # 0=Monday, 5=Sat, 6=Sun
                is_weekend = day_of_week in (5, 6)

                # Base values with diurnal/weekend modulation
                weekend_sleep_bonus = 1.1 if is_weekend else 0.0
                weekend_workload_relief = -1.2 if is_weekend else 0.0

                # Latent baseline draws
                curr_sleep = self.rng.normal(p["sleep_mean"] + weekend_sleep_bonus, p["sleep_std"])
                curr_stress = self.rng.normal(p["stress_mean"], p["stress_std"])
                curr_workload = self.rng.normal(p["workload_mean"] + weekend_workload_relief, p["workload_std"])
                curr_mood_valence = 5.0 - curr_stress + self.rng.normal(0, 0.3)
                curr_mood_arousal = 3.0 + self.rng.normal(0, 0.5)
                curr_sentiment = (curr_mood_valence - 3.0) / 2.0 + self.rng.normal(0, 0.15)
                curr_f0_var = self.rng.normal(p["f0_var_mean"], 5.0)
                curr_steps = self.rng.normal(p["steps_mean"], p["steps_std"])

                ground_truth_state = 0  # 0=Normal/Baseline
                ground_truth_stress_level = (curr_stress - 1.0) / 4.0  # Normalized [0, 1]

                # SCENARIO 1: Acute 1-day Spike at day 20
                if day == self.config.spike_day:
                    curr_stress += self.rng.uniform(1.5, 2.2)
                    curr_workload += self.rng.uniform(1.8, 2.5)
                    curr_sleep -= self.rng.uniform(1.5, 2.5)
                    curr_mood_valence -= 1.8
                    curr_f0_var -= 8.0  # Pitch compression under acute pressure
                    curr_sentiment -= 0.6
                    ground_truth_state = 1  # Acute spike
                    ground_truth_stress_level = min(1.0, ground_truth_stress_level + 0.45)

                # SCENARIO 2: Sustained Multi-Day Allostatic Drift
                drift_start = self.config.drift_start_day
                drift_end = drift_start + self.config.drift_duration_days
                if experiences_drift and (drift_start <= day <= drift_end):
                    drift_progress = (day - drift_start) / self.config.drift_duration_days
                    drift_intensity = np.sin(drift_progress * np.pi) * 2.0  # Smooth peak curve

                    curr_stress += 0.8 * drift_intensity
                    curr_workload += 0.9 * drift_intensity
                    curr_sleep -= 0.9 * drift_intensity
                    curr_mood_valence -= 0.7 * drift_intensity
                    curr_f0_var -= 4.0 * drift_intensity
                    curr_steps -= 1500.0 * drift_intensity
                    curr_sentiment -= 0.3 * drift_intensity
                    ground_truth_state = 2  # Sustained Drift
                    ground_truth_stress_level = min(1.0, ground_truth_stress_level + 0.35 * drift_intensity)

                # Boundary clamping according to formal data dictionary
                sleep_hours = float(np.clip(curr_sleep, 2.5, 14.0))
                perceived_stress = int(np.clip(np.round(curr_stress), 1, 5))
                mood_valence = int(np.clip(np.round(curr_mood_valence), 1, 5))
                mood_arousal = int(np.clip(np.round(curr_mood_arousal), 1, 5))
                workload_demand = int(np.clip(np.round(curr_workload), 1, 5))
                sentiment_polarity = float(np.clip(curr_sentiment, -1.0, 1.0))
                f0_variability_hz = float(np.clip(curr_f0_var, 5.0, 80.0))
                daily_steps = int(np.clip(np.round(curr_steps), 500, 35000))

                rows.append({
                    "participant_id": uid,
                    "day": day,
                    "is_weekend": is_weekend,
                    "is_calibration_phase": day <= self.config.calibration_days,
                    # M1: Structured Check-in
                    "perceived_stress": perceived_stress,
                    "mood_valence": mood_valence,
                    "mood_arousal": mood_arousal,
                    # M2: Text Journal
                    "sentiment_polarity": sentiment_polarity,
                    "self_pronoun_ratio": float(np.clip(0.05 + 0.02 * (5 - mood_valence), 0.01, 0.40)),
                    # M3: Sleep
                    "total_sleep_hours": sleep_hours,
                    "sleep_quality_rating": int(np.clip(np.round(sleep_hours / 2.0), 1, 5)),
                    # M4: Workload
                    "workload_demand": workload_demand,
                    "impending_deadlines_count": int(np.clip(np.round(workload_demand / 1.5), 0, 8)),
                    # M5: Voice
                    "f0_variability_hz": f0_variability_hz,
                    "pause_ratio": float(np.clip(0.3 + 0.05 * (perceived_stress - 1), 0.1, 1.2)),
                    # M6: Physical Activity
                    "daily_step_count": daily_steps,
                    # Ground Truth
                    "ground_truth_state": ground_truth_state,
                    "ground_truth_stress_level": float(np.clip(ground_truth_stress_level, 0.0, 1.0)),
                })

        df = pd.DataFrame(rows)
        return df

    def inject_missingness(self, df: pd.DataFrame, missing_rate: Optional[float] = None) -> pd.DataFrame:
        """
        Injects realistic asynchronous missingness across optional modalities.
        Modality M1 has lower missingness; M5 (voice) and M2 (journal) have higher missingness.
        """
        rate = missing_rate if missing_rate is not None else self.config.missingness_rate
        df_masked = df.copy()

        # Differential missingness rates per modality reflecting user burden
        modality_dropout_weights = {
            "perceived_stress": rate * 0.4,       # M1: High compliance (~8%)
            "sentiment_polarity": rate * 1.5,     # M2: Higher friction (~30%)
            "total_sleep_hours": rate * 0.6,      # M3: Moderate compliance (~12%)
            "workload_demand": rate * 0.7,        # M4: Moderate compliance (~14%)
            "f0_variability_hz": rate * 1.8,      # M5: Highest friction (~36%)
            "daily_step_count": rate * 0.8,       # M6: Sensor sync drop (~16%)
        }

        for col, p_drop in modality_dropout_weights.items():
            mask = self.rng.random(size=len(df_masked)) < p_drop
            # Never mask during ground truth inspection
            df_masked.loc[mask, col] = np.nan

        return df_masked
