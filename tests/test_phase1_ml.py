"""
Unit & Integration Test Suite for MindPulse Phase 1 Machine Learning Architecture.
Verifies synthetic data generation, personal baseline engines, CUSUM filtering,
late decision fusion, and missing-modality resilience.
"""

import pytest
import numpy as np
import pandas as pd

from ml.synthetic.generator import SyntheticLongitudinalGenerator, CohortConfig
from ml.baseline.engine import PersonalBaselineEngine, BaselineConfig
from ml.fusion.late_fusion import DynamicLateFusionEngine, FusionConfig, FusionOutput


class TestSyntheticDataGenerator:
    """Tests for the synthetic cohort generation pipeline."""

    def test_cohort_generation_shape_and_columns(self):
        config = CohortConfig(n_participants=10, n_days=30, seed=123)
        gen = SyntheticLongitudinalGenerator(config)
        df = gen.generate_cohort()

        assert len(df) == 10 * 30
        assert "participant_id" in df.columns
        assert "day" in df.columns
        assert "perceived_stress" in df.columns
        assert "total_sleep_hours" in df.columns
        assert "workload_demand" in df.columns
        assert "sentiment_polarity" in df.columns
        assert "f0_variability_hz" in df.columns
        assert "daily_step_count" in df.columns
        assert "ground_truth_state" in df.columns

    def test_value_ranges_adhere_to_data_dictionary(self):
        config = CohortConfig(n_participants=5, n_days=25, seed=42)
        gen = SyntheticLongitudinalGenerator(config)
        df = gen.generate_cohort()

        assert df["perceived_stress"].between(1, 5).all()
        assert df["mood_valence"].between(1, 5).all()
        assert df["workload_demand"].between(1, 5).all()
        assert df["sentiment_polarity"].between(-1.0, 1.0).all()
        assert df["total_sleep_hours"].between(2.0, 14.0).all()
        assert (df["daily_step_count"] >= 500).all()

    def test_reproducibility_with_seed(self):
        config1 = CohortConfig(n_participants=5, n_days=15, seed=99)
        config2 = CohortConfig(n_participants=5, n_days=15, seed=99)
        df1 = SyntheticLongitudinalGenerator(config1).generate_cohort()
        df2 = SyntheticLongitudinalGenerator(config2).generate_cohort()

        pd.testing.assert_frame_equal(df1, df2)

    def test_missingness_injection(self):
        config = CohortConfig(n_participants=5, n_days=20, seed=42)
        gen = SyntheticLongitudinalGenerator(config)
        df = gen.generate_cohort()
        df_masked = gen.inject_missingness(df, missing_rate=0.30)

        # Confirm NaNs were created in optional modalities
        assert df_masked["sentiment_polarity"].isna().sum() > 0
        assert df_masked["f0_variability_hz"].isna().sum() > 0


class TestPersonalBaselineEngine:
    """Tests for personal baseline modeling and temporal change detection."""

    def test_mad_computation(self):
        arr = np.array([10.0, 10.2, 9.8, 10.1, 9.9, 100.0])  # Contains an outlier
        scale = PersonalBaselineEngine.compute_mad(arr)
        # MAD is robust to the outlier, so scale should be small (~0.2 - 0.3)
        assert scale < 1.0

    def test_rolling_mad_causal_no_future_leakage(self):
        engine = PersonalBaselineEngine(BaselineConfig(window_size=5, min_calibration_points=3))
        # Initial constant series, then sudden step up
        series = pd.Series([2.0, 2.0, 2.0, 2.0, 10.0, 10.0, 10.0])
        medians, scales, z_scores = engine.compute_rolling_mad_baseline(series)

        # At index 2 (day 3), median should be 2.0
        assert medians.iloc[2] == 2.0
        # Day 4 (value=10.0) should not affect day 2 or 3
        assert medians.iloc[3] == 2.0
        assert z_scores.iloc[4] > 2.0  # Acute step produces significant z-score (>2 sigma)

    def test_ewma_baseline_adaptation(self):
        engine = PersonalBaselineEngine(BaselineConfig(ewma_alpha=0.2, min_calibration_points=3))
        series = pd.Series([3.0] * 10 + [5.0] * 10)
        means, _, z_scores = engine.compute_ewma_baseline(series)

        # Baseline should gradually adapt upward after the step
        assert means.iloc[9] == pytest.approx(3.0, abs=0.1)
        assert means.iloc[19] > 4.0

    def test_cusum_filter_suppresses_transient_spike(self):
        engine = PersonalBaselineEngine(BaselineConfig(cusum_threshold_h=3.5, cusum_allowance_k=0.5))
        # 1-day spike at index 5, then returns to 0
        z_transient = pd.Series([0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0])
        _, alerts_transient = engine.apply_cusum_filter(z_transient)

        # Transient spike should NOT trigger CUSUM alert
        assert not alerts_transient.any()

        # Sustained drift (consecutive positive deviations)
        z_sustained = pd.Series([0.0, 0.0, 0.0, 2.0, 2.5, 2.5, 2.5, 3.0])
        _, alerts_sustained = engine.apply_cusum_filter(z_sustained)

        # Sustained drift MUST trigger CUSUM alert
        assert alerts_sustained.iloc[-1] == True


class TestDynamicLateFusionEngine:
    """Tests for late decision fusion, uncertainty estimation, and explanations."""

    def test_equal_neutral_inputs_yield_neutral_composite(self):
        engine = DynamicLateFusionEngine()
        z_dict = {"check_in": 0.0, "sleep": 0.0, "workload": 0.0, "journal": 0.0, "voice": 0.0, "activity": 0.0}
        out = engine.fuse_epoch(z_dict)

        assert out.composite_stress_score == pytest.approx(0.50, abs=0.01)
        assert out.epistemic_uncertainty == 0.0
        assert not out.is_alert_triggered

    def test_missing_modality_graceful_handling(self):
        engine = DynamicLateFusionEngine()
        # Only Check-in and Sleep observed (weights 0.30 + 0.25 = 0.55 observed)
        z_dict = {"check_in": 2.0, "sleep": -2.0, "workload": None, "journal": None, "voice": None, "activity": None}
        out = engine.fuse_epoch(z_dict)

        # High stress in checkin (+2.0) and poor sleep (-2.0 directed to +2.0)
        assert out.composite_stress_score > 0.70
        # Epistemic uncertainty = 1.0 - 0.55 = 0.45
        assert out.epistemic_uncertainty == pytest.approx(0.45, abs=0.01)
        assert "check_in" in out.observed_modalities
        assert "voice" in out.missing_modalities

    def test_all_missing_returns_neutral_safely(self):
        engine = DynamicLateFusionEngine()
        z_dict = {"check_in": None, "sleep": None}
        out = engine.fuse_epoch(z_dict)

        assert out.composite_stress_score == 0.5
        assert out.epistemic_uncertainty == 1.0
        assert out.primary_contributor == "none"

    def test_factor_attribution_identifies_top_driver(self):
        engine = DynamicLateFusionEngine()
        # High workload (+3.0), everything else calm (0.0)
        z_dict = {"check_in": 0.0, "sleep": 0.0, "workload": 3.0, "journal": 0.0, "voice": 0.0, "activity": 0.0}
        out = engine.fuse_epoch(z_dict)

        assert out.primary_contributor == "workload"
        assert "cognitive task demands" in out.explanation_narrative


def test_end_to_end_phase1_pipeline():
    """Integration test connecting synthetic data generation, baseline engine, and late fusion."""
    config = CohortConfig(n_participants=2, n_days=25, seed=42)
    gen = SyntheticLongitudinalGenerator(config)
    df = gen.generate_cohort()

    engine = PersonalBaselineEngine()
    fusion = DynamicLateFusionEngine()

    sample_user = df[df["participant_id"] == "user_000"]
    _, _, z_stress = engine.compute_ewma_baseline(sample_user["perceived_stress"])
    _, _, z_sleep = engine.compute_ewma_baseline(sample_user["total_sleep_hours"])

    # Day 20 is the injected acute spike
    idx_spike = sample_user[sample_user["day"] == 20].index[0]
    z_dict_spike = {
        "check_in": z_stress.loc[idx_spike],
        "sleep": z_sleep.loc[idx_spike],
    }
    out_spike = fusion.fuse_epoch(z_dict_spike)

    assert out_spike.composite_stress_score > 0.65
    assert len(out_spike.explanation_narrative) > 20
