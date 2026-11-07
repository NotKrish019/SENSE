use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct FusionConfig {
    pub prior_weights: HashMap<String, f64>,
    pub modality_directions: HashMap<String, f64>,
    pub uncertainty_threshold: f64,
    pub alert_composite_threshold: f64,
}

impl Default for FusionConfig {
    fn default() -> Self {
        let mut prior_weights = HashMap::new();
        prior_weights.insert("check_in".to_string(), 0.30);
        prior_weights.insert("sleep".to_string(), 0.25);
        prior_weights.insert("workload".to_string(), 0.20);
        prior_weights.insert("journal".to_string(), 0.10);
        prior_weights.insert("voice".to_string(), 0.10);
        prior_weights.insert("activity".to_string(), 0.05);

        let mut modality_directions = HashMap::new();
        modality_directions.insert("check_in".to_string(), 1.0);
        modality_directions.insert("sleep".to_string(), -1.0);
        modality_directions.insert("workload".to_string(), 1.0);
        modality_directions.insert("journal".to_string(), -1.0);
        modality_directions.insert("voice".to_string(), -1.0);
        modality_directions.insert("activity".to_string(), -1.0);

        Self {
            prior_weights,
            modality_directions,
            uncertainty_threshold: 0.65,
            alert_composite_threshold: 0.68,
        }
    }
}

#[derive(Debug, Clone)]
pub struct FusionOutput {
    pub composite_stress_score: f64,
    pub is_alert_triggered: bool,
    pub epistemic_uncertainty: f64,
    pub observed_modalities: Vec<String>,
    pub missing_modalities: Vec<String>,
    pub factor_attributions: HashMap<String, f64>,
    pub primary_contributor: String,
    pub explanation_narrative: String,
}

pub struct DynamicLateFusionEngine {
    pub config: FusionConfig,
}

impl DynamicLateFusionEngine {
    pub fn new(config: FusionConfig) -> Self {
        Self { config }
    }

    pub fn sigmoid(x: f64) -> f64 {
        let clamped = x.clamp(-10.0, 10.0);
        1.0 / (1.0 + (-clamped).exp())
    }

    /// Fuses an epoch across available modalities with dynamic denominator normalization
    pub fn fuse_epoch(
        &self,
        modality_z_scores: &HashMap<String, Option<f64>>,
        qualities: Option<&HashMap<String, f64>>,
    ) -> FusionOutput {
        let empty_map = HashMap::new();
        let qual_map = qualities.unwrap_or(&empty_map);

        let mut observed_modalities = Vec::new();
        let mut missing_modalities = Vec::new();
        let mut weighted_scores_sum = 0.0;
        let mut weight_normalizer = 0.0;
        let mut observed_prior_sum = 0.0;

        let mut modality_stress_probs: HashMap<String, f64> = HashMap::new();

        for (modality, &prior_w) in &self.config.prior_weights {
            if let Some(Some(z_val)) = modality_z_scores.get(modality) {
                observed_modalities.push(modality.clone());
                observed_prior_sum += prior_w;

                let r_qual = qual_map.get(modality).copied().unwrap_or(1.0).clamp(0.1, 1.0);
                let effective_weight = prior_w * r_qual;

                let dir_factor = self.config.modality_directions.get(modality).copied().unwrap_or(1.0);
                let directed_z = z_val * dir_factor;

                let prob = Self::sigmoid(directed_z);
                modality_stress_probs.insert(modality.clone(), prob);

                weighted_scores_sum += effective_weight * prob;
                weight_normalizer += effective_weight;
            } else {
                missing_modalities.push(modality.clone());
            }
        }

        if weight_normalizer == 0.0 {
            return FusionOutput {
                composite_stress_score: 0.5,
                is_alert_triggered: false,
                epistemic_uncertainty: 1.0,
                observed_modalities: vec![],
                missing_modalities: self.config.prior_weights.keys().cloned().collect(),
                factor_attributions: HashMap::new(),
                primary_contributor: "none".to_string(),
                explanation_narrative: "No observations recorded today. Baseline remains unchanged.".to_string(),
            };
        }

        let composite_score = weighted_scores_sum / weight_normalizer;
        let epistemic_uncertainty = 1.0 - observed_prior_sum;

        // Compute factor attributions: delta from neutral 0.5
        let mut attributions = HashMap::new();
        for m in &observed_modalities {
            let prob = modality_stress_probs[m];
            let r_qual = qual_map.get(m).copied().unwrap_or(1.0);
            let norm_w = (self.config.prior_weights[m] * r_qual) / weight_normalizer;
            attributions.insert(m.clone(), norm_w * (prob - 0.5));
        }

        let mut primary_mod = "none".to_string();
        if !attributions.is_empty() {
            let mut sorted_factors: Vec<(&String, &f64)> = attributions.iter().collect();
            sorted_factors.sort_by(|a, b| b.1.partial_cmp(a.1).unwrap_or(std::cmp::Ordering::Equal));
            if *sorted_factors[0].1 > 0.02 {
                primary_mod = sorted_factors[0].0.clone();
            }
        }

        let is_alert = composite_score >= self.config.alert_composite_threshold
            && epistemic_uncertainty <= self.config.uncertainty_threshold;

        let narrative = self.generate_narrative(
            composite_score,
            is_alert,
            epistemic_uncertainty,
            &attributions,
            &observed_modalities,
        );

        FusionOutput {
            composite_stress_score: (composite_score * 10000.0).round() / 10000.0,
            is_alert_triggered: is_alert,
            epistemic_uncertainty: (epistemic_uncertainty * 10000.0).round() / 10000.0,
            observed_modalities,
            missing_modalities,
            factor_attributions: attributions.into_iter().map(|(k, v)| (k, (v * 10000.0).round() / 10000.0)).collect(),
            primary_contributor: primary_mod,
            explanation_narrative: narrative,
        }
    }

    fn generate_narrative(
        &self,
        composite_score: f64,
        is_alert: bool,
        uncertainty: f64,
        attributions: &HashMap<String, f64>,
        observed: &[String],
    ) -> String {
        if uncertainty > self.config.uncertainty_threshold {
            return format!(
                "We observed limited data today ({}). Observations remain within your typical bounds, but more daily check-ins will increase confidence.",
                observed.join(", ")
            );
        }

        let modality_names: HashMap<&str, &str> = [
            ("check_in", "subjective stress check-ins"),
            ("sleep", "sleep duration and rest consistency"),
            ("workload", "reported cognitive task demands"),
            ("journal", "emotional tone in your journal reflections"),
            ("voice", "speech pitch variability"),
            ("activity", "daily physical movement"),
        ].into_iter().collect();

        if is_alert {
            let mut top_factors: Vec<(&String, &f64)> = attributions.iter().filter(|(_, &v)| v > 0.0).collect();
            top_factors.sort_by(|a, b| b.1.partial_cmp(a.1).unwrap_or(std::cmp::Ordering::Equal));

            if !top_factors.is_empty() {
                let default_primary = top_factors[0].0.as_str();
                let primary = modality_names.get(default_primary).copied().unwrap_or(default_primary);
                let secondary_phrase = if top_factors.len() > 1 {
                    let default_sec = top_factors[1].0.as_str();
                    let sec = modality_names.get(default_sec).copied().unwrap_or(default_sec);
                    format!(", combined with shifts in your {}", sec)
                } else {
                    "".to_string()
                };

                return format!(
                    "Your recorded patterns indicate an elevated stress pattern relative to your personal baseline. The primary factor is a noticeable change in your {}{}. Consider scheduling intentional micro-breaks and prioritizing restorative rest this evening.",
                    primary, secondary_phrase
                );
            }
            return "Your recorded well-being indicators show sustained deviation from your personal historical equilibrium.".to_string();
        }

        let mut top_positive: Vec<(&String, &f64)> = attributions.iter().filter(|(_, &v)| v > 0.04).collect();
        top_positive.sort_by(|a, b| b.1.partial_cmp(a.1).unwrap_or(std::cmp::Ordering::Equal));
        if !top_positive.is_empty() {
            let default_name = top_positive[0].0.as_str();
            let primary_name = modality_names.get(default_name).copied().unwrap_or(default_name);
            return format!(
                "Your daily indicators remain mostly within your historical corridor, though we observed an isolated shift in your {}.",
                primary_name
            );
        }

        if composite_score < 0.40 {
            return "Your recorded rest, mood, and daily indicators are comfortably aligned with or better than your personal baseline.".to_string();
        }

        "Your daily indicators remain within your normal historical equilibrium corridor.".to_string()
    }
}

