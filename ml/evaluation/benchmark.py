"""
Phase 1 Empirical Benchmarking Script.
Executes Experiments EXP-1.1, EXP-1.2, and EXP-1.3 to quantitatively evaluate RQ1, RQ4, and RQ6.
"""

from typing import Dict, Any
import numpy as np
import pandas as pd

from ml.synthetic.generator import SyntheticLongitudinalGenerator, CohortConfig
from ml.baseline.engine import PersonalBaselineEngine, BaselineConfig
from ml.fusion.late_fusion import DynamicLateFusionEngine, FusionConfig


def run_experiment_1_1(df: pd.DataFrame) -> Dict[str, Any]:
    """
    EXP-1.1: Personalized Baseline Modeling vs. Fixed Global Thresholds (RQ1).
    Evaluates Model A (Global), Model B (Rolling Median/MAD), and Model C (EWMA).
    Ground Truth: Sustained Drift (State == 2).
    Metric: False Alert Rate (FAR per participant-month) and F1-score.
    """
    engine = PersonalBaselineEngine(BaselineConfig(window_size=14, min_calibration_points=7))
    post_calib_mask = ~df["is_calibration_phase"]
    y_true_drift = (df.loc[post_calib_mask, "ground_truth_state"] == 2).values
    n_post_days = post_calib_mask.sum()
    participant_months = n_post_days / (30.0 * df["participant_id"].nunique())

    # Model A: Global Population Baseline on perceived_stress
    global_alerts = engine.evaluate_global_model(df, "perceived_stress", threshold_z=1.96)[post_calib_mask].values

    # Model B & C evaluated within each participant
    rolling_mad_alerts = []
    ewma_alerts = []

    for uid, group in df.groupby("participant_id"):
        sub_mask = post_calib_mask.loc[group.index]
        
        # Model B: Rolling MAD
        _, _, z_mad = engine.compute_rolling_mad_baseline(group["perceived_stress"])
        alerts_mad = (z_mad > 1.96).loc[sub_mask].values
        rolling_mad_alerts.extend(alerts_mad)

        # Model C: EWMA
        _, _, z_ewma = engine.compute_ewma_baseline(group["perceived_stress"])
        alerts_ewma = (z_ewma > 1.96).loc[sub_mask].values
        ewma_alerts.extend(alerts_ewma)

    rolling_mad_alerts = np.array(rolling_mad_alerts)
    ewma_alerts = np.array(ewma_alerts)

    def calc_metrics(y_pred):
        tp = np.sum((y_pred == 1) & (y_true_drift == 1))
        fp = np.sum((y_pred == 1) & (y_true_drift == 0))
        fn = np.sum((y_pred == 0) & (y_true_drift == 1))
        precision = tp / max(tp + fp, 1)
        recall = tp / max(tp + fn, 1)
        f1 = 2 * (precision * recall) / max(precision + recall, 1e-4)
        far = fp / max(participant_months * df["participant_id"].nunique(), 1e-4)
        return {"precision": round(float(precision), 3), "recall": round(float(recall), 3), "f1": round(float(f1), 3), "far_per_user_month": round(float(far), 2)}

    results = {
        "Model A (Global Population)": calc_metrics(global_alerts),
        "Model B (Within-Person Rolling MAD)": calc_metrics(rolling_mad_alerts),
        "Model C (Within-Person EWMA)": calc_metrics(ewma_alerts),
    }
    return results


def run_experiment_1_3(df: pd.DataFrame) -> Dict[str, Any]:
    """
    EXP-1.3: Temporal Persistence Filtering Benchmark (RQ4).
    Compares Raw Snapshot Alert vs CUSUM Sequential Persistence Filter on 1-Day Acute Spikes.
    Objective: CUSUM must suppress transient 1-day acute spikes (State == 1) while capturing sustained drift (State == 2).
    """
    engine = PersonalBaselineEngine(BaselineConfig(cusum_threshold_h=3.5, cusum_allowance_k=0.5))
    
    snapshot_spikes_flagged = 0
    snapshot_drift_flagged = 0
    cusum_spikes_flagged = 0
    cusum_drift_flagged = 0

    total_spike_events = 0
    total_drift_events = 0

    for uid, group in df.groupby("participant_id"):
        _, _, z_ewma = engine.compute_ewma_baseline(group["perceived_stress"])
        _, cusum_alerts = engine.apply_cusum_filter(z_ewma)
        raw_alerts = z_ewma > 1.8

        spike_days = group["ground_truth_state"] == 1
        drift_days = group["ground_truth_state"] == 2

        total_spike_events += spike_days.sum()
        total_drift_events += drift_days.sum()

        snapshot_spikes_flagged += (raw_alerts & spike_days).sum()
        snapshot_drift_flagged += (raw_alerts & drift_days).sum()

        cusum_spikes_flagged += (cusum_alerts & spike_days).sum()
        cusum_drift_flagged += (cusum_alerts & drift_days).sum()

    spike_false_alert_rate_snapshot = snapshot_spikes_flagged / max(total_spike_events, 1)
    spike_false_alert_rate_cusum = cusum_spikes_flagged / max(total_spike_events, 1)

    drift_detection_rate_snapshot = snapshot_drift_flagged / max(total_drift_events, 1)
    drift_detection_rate_cusum = cusum_drift_flagged / max(total_drift_events, 1)

    return {
        "total_acute_spikes_tested": int(total_spike_events),
        "total_drift_days_tested": int(total_drift_events),
        "snapshot_acute_spike_false_alert_rate": round(float(spike_false_alert_rate_snapshot), 3),
        "cusum_acute_spike_false_alert_rate": round(float(spike_false_alert_rate_cusum), 3),
        "spike_suppression_improvement": f"{round((1.0 - spike_false_alert_rate_cusum / max(spike_false_alert_rate_snapshot, 1e-4)) * 100, 1)}%",
        "cusum_drift_detection_sensitivity": round(float(drift_detection_rate_cusum), 3),
    }


def run_experiment_1_2(generator: SyntheticLongitudinalGenerator, df_clean: pd.DataFrame) -> Dict[str, Any]:
    """
    EXP-1.2: Missing Modality Robustness Evaluation (RQ6).
    Evaluates Late Fusion stability across missingness rates (0%, 20%, 40%, 60%).
    """
    fusion_engine = DynamicLateFusionEngine(FusionConfig())
    engine = PersonalBaselineEngine()

    dropout_levels = [0.0, 0.20, 0.40, 0.50]
    results_by_dropout = {}

    for rate in dropout_levels:
        df_dropped = generator.inject_missingness(df_clean, missing_rate=rate)
        fused_scores = []
        uncertainties = []

        # Run on a sample of 20 participants for fast benchmarking
        sample_ids = df_dropped["participant_id"].unique()[:20]
        sample_df = df_dropped[df_dropped["participant_id"].isin(sample_ids)]

        for uid, group in sample_df.groupby("participant_id"):
            # Compute z-scores for available modalities
            _, _, z_stress = engine.compute_ewma_baseline(group["perceived_stress"])
            _, _, z_sleep = engine.compute_ewma_baseline(group["total_sleep_hours"])
            _, _, z_workload = engine.compute_ewma_baseline(group["workload_demand"])
            _, _, z_sentiment = engine.compute_ewma_baseline(group["sentiment_polarity"])
            _, _, z_f0 = engine.compute_ewma_baseline(group["f0_variability_hz"])
            _, _, z_steps = engine.compute_ewma_baseline(group["daily_step_count"])

            for idx in group.index:
                z_dict = {
                    "check_in": z_stress.loc[idx] if not np.isnan(z_stress.loc[idx]) else None,
                    "sleep": z_sleep.loc[idx] if not np.isnan(z_sleep.loc[idx]) else None,
                    "workload": z_workload.loc[idx] if not np.isnan(z_workload.loc[idx]) else None,
                    "journal": z_sentiment.loc[idx] if not np.isnan(z_sentiment.loc[idx]) else None,
                    "voice": z_f0.loc[idx] if not np.isnan(z_f0.loc[idx]) else None,
                    "activity": z_steps.loc[idx] if not np.isnan(z_steps.loc[idx]) else None,
                }
                out = fusion_engine.fuse_epoch(z_dict)
                fused_scores.append(out.composite_stress_score)
                uncertainties.append(out.epistemic_uncertainty)

        results_by_dropout[f"missingness_{int(rate * 100)}%"] = {
            "mean_composite_score": round(float(np.mean(fused_scores)), 3),
            "std_composite_score": round(float(np.std(fused_scores)), 3),
            "mean_epistemic_uncertainty": round(float(np.mean(uncertainties)), 3),
        }

    return results_by_dropout


def run_phase1_benchmarks() -> Dict[str, Any]:
    """Executes all Phase 1 research benchmarks and returns consolidated report."""
    print("[1/4] Generating synthetic longitudinal cohort (N=100, T=60 days, seed=42)...")
    config = CohortConfig(n_participants=100, n_days=60, seed=42)
    generator = SyntheticLongitudinalGenerator(config)
    df_clean = generator.generate_cohort()

    print("[2/4] Executing EXP-1.1: Personalized Baseline Modeling vs. Fixed Global Thresholds (RQ1)...")
    exp_1_1 = run_experiment_1_1(df_clean)

    print("[3/4] Executing EXP-1.3: Temporal Persistence Filtering Benchmark (RQ4)...")
    exp_1_3 = run_experiment_1_3(df_clean)

    print("[4/4] Executing EXP-1.2: Missing Modality Robustness Benchmark (RQ6)...")
    exp_1_2 = run_experiment_1_2(generator, df_clean)

    return {
        "cohort_summary": {
            "total_participants": config.n_participants,
            "total_days": config.n_days,
            "total_records": len(df_clean),
        },
        "EXP-1.1_Personalized_Baselines_RQ1": exp_1_1,
        "EXP-1.3_Temporal_Persistence_RQ4": exp_1_3,
        "EXP-1.2_Missing_Modality_Robustness_RQ6": exp_1_2,
    }


if __name__ == "__main__":
    report = run_phase1_benchmarks()
    import pprint
    print("\n================== PHASE 1 EMPIRICAL BENCHMARK REPORT ==================")
    pprint.pprint(report)
