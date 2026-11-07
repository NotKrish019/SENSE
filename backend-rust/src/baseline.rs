#[derive(Debug, Clone)]
pub struct BaselineConfig {
    pub window_size: usize,
    pub ewma_alpha: f64,
    pub min_calibration_points: usize,
    pub cusum_allowance_k: f64,
    pub cusum_threshold_h: f64,
    pub epsilon: f64,
}

impl Default for BaselineConfig {
    fn default() -> Self {
        Self {
            window_size: 14,
            ewma_alpha: 0.15,
            min_calibration_points: 7,
            cusum_allowance_k: 0.5,
            cusum_threshold_h: 3.5,
            epsilon: 1e-4,
        }
    }
}

#[derive(Debug, Clone)]
pub struct BaselineResult {
    pub locations: Vec<Option<f64>>,
    pub scales: Vec<Option<f64>>,
    pub z_scores: Vec<Option<f64>>,
}

#[derive(Debug, Clone)]
pub struct CusumResult {
    pub cusum_values: Vec<f64>,
    pub alerts: Vec<bool>,
}

pub struct PersonalBaselineEngine {
    pub config: BaselineConfig,
}

impl PersonalBaselineEngine {
    pub fn new(config: BaselineConfig) -> Self {
        Self { config }
    }

    /// Computes Median Absolute Deviation (MAD) scaled to estimate standard deviation:
    /// sigma_hat = 1.4826 * median(|x - median(x)|)
    pub fn compute_mad(values: &[f64]) -> f64 {
        if values.len() < 2 {
            return 1.0;
        }

        let mut sorted = values.to_vec();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let med = Self::median(&sorted);

        let mut deviations: Vec<f64> = sorted.iter().map(|x| (x - med).abs()).collect();
        deviations.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let mad = Self::median(&deviations);
        let scale = 1.4826 * mad;

        if scale > 1e-4 {
            scale
        } else {
            // Fallback standard deviation
            let mean = values.iter().sum::<f64>() / values.len() as f64;
            let variance = values.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / values.len() as f64;
            variance.sqrt() + 1e-4
        }
    }

    fn median(sorted: &[f64]) -> f64 {
        let n = sorted.len();
        if n == 0 {
            return 0.0;
        }
        if n % 2 == 1 {
            sorted[n / 2]
        } else {
            (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        }
    }

    /// Model B: Rolling Window with Median and MAD. Causal lookback strictly enforcing zero future leakage.
    pub fn compute_rolling_mad_baseline(&self, series: &[Option<f64>]) -> BaselineResult {
        let n = series.len();
        let w = self.config.window_size;
        let mut locations = vec![None; n];
        let mut scales = vec![None; n];
        let mut z_scores = vec![None; n];

        for i in 0..n {
            let start_idx = if i >= w - 1 { i + 1 - w } else { 0 };
            let window: Vec<f64> = series[start_idx..=i].iter().filter_map(|&x| x).collect();

            if window.len() >= self.config.min_calibration_points {
                let mut sorted = window.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
                let med = Self::median(&sorted);
                let scale = Self::compute_mad(&window);

                locations[i] = Some(med);
                scales[i] = Some(scale);

                if let Some(val) = series[i] {
                    let denom = scale.max(self.config.epsilon);
                    z_scores[i] = Some((val - med) / denom);
                }
            }
        }

        BaselineResult { locations, scales, z_scores }
    }

    /// Model C: Exponentially Weighted Moving Average (EWMA) with adaptive variance corridor
    pub fn compute_ewma_baseline(&self, series: &[Option<f64>]) -> BaselineResult {
        let n = series.len();
        let alpha = self.config.ewma_alpha;
        let mut locations = vec![None; n];
        let mut scales = vec![None; n];
        let mut z_scores = vec![None; n];

        let mut curr_mean: Option<f64> = None;
        let mut curr_var: Option<f64> = None;
        let mut observed_count = 0;

        for i in 0..n {
            if let Some(val) = series[i] {
                observed_count += 1;
                match curr_mean {
                    None => {
                        curr_mean = Some(val);
                        curr_var = Some(1.0);
                    }
                    Some(m) => {
                        let diff = val - m;
                        let new_mean = alpha * val + (1.0 - alpha) * m;
                        let new_var = (1.0 - alpha) * (curr_var.unwrap_or(1.0) + alpha * diff.powi(2));
                        curr_mean = Some(new_mean);
                        curr_var = Some(new_var);
                    }
                }

                if observed_count >= self.config.min_calibration_points {
                    let m = curr_mean.unwrap();
                    let std = curr_var.unwrap().max(self.config.epsilon).sqrt();
                    locations[i] = Some(m);
                    scales[i] = Some(std);
                    z_scores[i] = Some((val - m) / std.max(self.config.epsilon));
                }
            } else {
                if observed_count >= self.config.min_calibration_points {
                    locations[i] = curr_mean;
                    scales[i] = curr_var.map(|v| v.max(self.config.epsilon).sqrt());
                }
            }
        }

        BaselineResult { locations, scales, z_scores }
    }

    /// Sequential CUSUM Temporal Persistence Filter
    /// C_t = max(0, C_{t-1} + z_t - k)
    /// Triggers alert if C_t >= h AND trend is non-negative
    pub fn apply_cusum_filter(&self, z_series: &[Option<f64>]) -> CusumResult {
        let n = z_series.len();
        let k = self.config.cusum_allowance_k;
        let h = self.config.cusum_threshold_h;

        let mut cusum = vec![0.0; n];
        let mut alerts = vec![false; n];

        for i in 0..n {
            let prev_c = if i > 0 { cusum[i - 1] } else { 0.0 };
            match z_series[i] {
                Some(z) => {
                    cusum[i] = (prev_c + z - k).max(0.0);
                }
                None => {
                    // Decay slightly if unobserved (does not accumulate)
                    cusum[i] = (prev_c * 0.8).max(0.0);
                }
            }

            if cusum[i] >= h {
                if i >= 2 && z_series[i - 1].is_some() && z_series[i].is_some() {
                    let prev_z = z_series[i - 2].unwrap_or_else(|| z_series[i - 1].unwrap());
                    let trend = z_series[i].unwrap() - prev_z;
                    if trend >= -0.5 {
                        alerts[i] = true;
                    }
                } else {
                    alerts[i] = true;
                }
            }
        }

        CusumResult { cusum_values: cusum, alerts }
    }
}

