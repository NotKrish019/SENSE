"""
Personal Baseline & Longitudinal Change-Point Engine.
Implements Model A (Global), Model B (Rolling Median/MAD), Model C (EWMA),
and CUSUM temporal persistence filtering.
"""

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import numpy as np
import pandas as pd


@dataclass
class BaselineConfig:
    """Hyperparameters for baseline modeling and change detection."""
    window_size: int = 14            # Lookback window W for rolling statistics
    ewma_alpha: float = 0.15         # Smoothing parameter lambda for EWMA
    min_calibration_points: int = 7  # Minimum observations before computing deviations
    cusum_allowance_k: float = 0.5   # Slack parameter k in standardized units
    cusum_threshold_h: float = 3.5   # Decision threshold h for cumulative sum alert
    epsilon: float = 1e-4            # Small constant to prevent zero-division


class PersonalBaselineEngine:
    """
    Computes personalized baseline reference distributions and temporal change scores
    for individual participants across longitudinal time series.
    """

    def __init__(self, config: Optional[BaselineConfig] = None):
        self.config = config or BaselineConfig()

    @staticmethod
    def compute_mad(arr: np.ndarray) -> float:
        """
        Computes Median Absolute Deviation (MAD) scaled to estimate normal standard deviation:
        sigma_hat = 1.4826 * median(|x - median(x)|)
        """
        valid = arr[~np.isnan(arr)]
        if len(valid) < 2:
            return 1.0
        med = np.median(valid)
        mad = np.median(np.abs(valid - med))
        scale = 1.4826 * mad
        return float(scale if scale > 1e-4 else np.std(valid) + 1e-4)

    def evaluate_global_model(self, df: pd.DataFrame, feature_col: str, threshold_z: float = 1.96) -> pd.Series:
        """
        Model A: Global Population Baseline.
        Computes pooled mean and std across ALL participants and flags observations > threshold_z.
        """
        pooled_mean = df[feature_col].mean()
        pooled_std = df[feature_col].std()
        if pooled_std < self.config.epsilon:
            pooled_std = 1.0

        z_scores = (df[feature_col] - pooled_mean) / pooled_std
        return z_scores > threshold_z

    def compute_rolling_mad_baseline(self, series: pd.Series) -> Tuple[pd.Series, pd.Series, pd.Series]:
        """
        Model B: Within-Person Rolling Window with Median & MAD.
        Computes rolling location (median) and scale (MAD) over window_size.
        Returns: (median_series, scale_series, z_score_series)
        """
        w = self.config.window_size
        n = len(series)
        medians = np.full(n, np.nan)
        scales = np.full(n, np.nan)
        z_scores = np.full(n, np.nan)

        values = series.values

        for i in range(n):
            # Causal lookback: past observations strictly prior to or including current day
            start_idx = max(0, i - w + 1)
            window = values[start_idx : i + 1]
            valid_window = window[~np.isnan(window)]

            if len(valid_window) >= self.config.min_calibration_points:
                med = float(np.median(valid_window))
                scale = self.compute_mad(valid_window)
                medians[i] = med
                scales[i] = scale
                if not np.isnan(values[i]):
                    z_scores[i] = (values[i] - med) / max(scale, self.config.epsilon)

        return pd.Series(medians, index=series.index), pd.Series(scales, index=series.index), pd.Series(z_scores, index=series.index)

    def compute_ewma_baseline(self, series: pd.Series) -> Tuple[pd.Series, pd.Series, pd.Series]:
        """
        Model C: Exponentially Weighted Moving Average (EWMA) with adaptive variance.
        mu_t = lambda * x_t + (1 - lambda) * mu_{t-1}
        Returns: (ewma_mean, ewma_std, z_score_series)
        """
        alpha = self.config.ewma_alpha
        n = len(series)
        ewma_mean = np.full(n, np.nan)
        ewma_var = np.full(n, np.nan)
        z_scores = np.full(n, np.nan)

        values = series.values
        curr_mean = None
        curr_var = None
        observed_count = 0

        for i in range(n):
            val = values[i]
            if not np.isnan(val):
                observed_count += 1
                if curr_mean is None:
                    curr_mean = float(val)
                    curr_var = 1.0  # Initial variance prior
                else:
                    diff = val - curr_mean
                    # Update mean and variance online
                    curr_mean = alpha * val + (1.0 - alpha) * curr_mean
                    curr_var = (1.0 - alpha) * (curr_var + alpha * (diff ** 2))

                if observed_count >= self.config.min_calibration_points:
                    ewma_mean[i] = curr_mean
                    std = np.sqrt(max(curr_var, self.config.epsilon))
                    ewma_std_val = float(std)
                    ewma_var[i] = ewma_std_val
                    z_scores[i] = (val - curr_mean) / max(ewma_std_val, self.config.epsilon)
            else:
                # Carry forward last known baseline if unobserved
                if curr_mean is not None and observed_count >= self.config.min_calibration_points:
                    ewma_mean[i] = curr_mean
                    ewma_var[i] = np.sqrt(max(curr_var, self.config.epsilon))

        return pd.Series(ewma_mean, index=series.index), pd.Series(ewma_var, index=series.index), pd.Series(z_scores, index=series.index)

    def apply_cusum_filter(self, z_series: pd.Series) -> Tuple[pd.Series, pd.Series]:
        """
        Sequential CUSUM Persistence Filter for detecting sustained upward allostatic shifts.
        C_t = max(0, C_{t-1} + z_t - k)
        An alert triggers if C_t > h AND short-term trend slope >= 0.
        Returns: (cusum_values, alert_triggers_boolean)
        """
        k = self.config.cusum_allowance_k
        h = self.config.cusum_threshold_h
        n = len(z_series)

        cusum = np.zeros(n)
        alerts = np.zeros(n, dtype=bool)
        z_vals = z_series.values

        for i in range(n):
            z = z_vals[i]
            if np.isnan(z):
                # Mild decay if unobserved (does not penalize, does not accumulate)
                cusum[i] = max(0.0, cusum[i - 1] * 0.8) if i > 0 else 0.0
            else:
                prev_c = cusum[i - 1] if i > 0 else 0.0
                cusum[i] = max(0.0, prev_c + z - k)

            # Check threshold and trend persistence over 3-day window
            if cusum[i] >= h:
                # Require that recent trend slope is non-negative (not recovering)
                if i >= 2 and not np.isnan(z_vals[i - 1]):
                    trend = z_vals[i] - z_vals[i - 2]
                    if trend >= -0.5:  # Not crashing down
                        alerts[i] = True
                else:
                    alerts[i] = True

        return pd.Series(cusum, index=z_series.index), pd.Series(alerts, index=z_series.index)
