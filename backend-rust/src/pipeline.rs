use std::collections::HashMap;
use uuid::Uuid;

use crate::baseline::{BaselineConfig, PersonalBaselineEngine};
use crate::database::DatabaseManager;
use crate::fusion::{DynamicLateFusionEngine, FusionConfig};
use crate::models::{
    CheckInRecord, DailyInferenceRecord, JournalRecord, PipelineInferenceResult, SleepRecord,
    UserBaselineRecord, WorkloadRecord,
};
use crate::preprocessor::SignalPreprocessor;

/// High-level input packet for daily subjective check-in
#[derive(Debug, Clone, Default)]
pub struct CheckInInput {
    pub perceived_stress: i32,
    pub mood_valence: Option<i32>,
    pub mood_arousal: Option<i32>,
    pub motivation_level: Option<i32>,
    pub completion_latency_sec: Option<f64>,
    pub session_type: Option<String>,
}

/// High-level input packet for sleep log
#[derive(Debug, Clone, Default)]
pub struct SleepInput {
    pub total_sleep_minutes: i32,
    pub sleep_quality_rating: Option<i32>,
    pub bedtime_utc: Option<String>,
    pub wake_time_utc: Option<String>,
    pub source_type: Option<String>,
}

/// High-level input packet for cognitive workload
#[derive(Debug, Clone, Default)]
pub struct WorkloadInput {
    pub mental_demand_rating: i32,
    pub effort_rating: Option<i32>,
    pub tasks_completed_count: Option<i32>,
    pub impending_deadlines_count: Option<i32>,
}

/// MindPulse Core Processing Pipeline in Rust
pub struct MindPulsePipeline {
    db: DatabaseManager,
    baseline_engine: PersonalBaselineEngine,
    fusion_engine: DynamicLateFusionEngine,
}

impl MindPulsePipeline {
    pub fn new(db: DatabaseManager) -> Self {
        Self {
            db,
            baseline_engine: PersonalBaselineEngine::new(BaselineConfig {
                window_size: 14,
                min_calibration_points: 7,
                ..Default::default()
            }),
            fusion_engine: DynamicLateFusionEngine::new(FusionConfig::default()),
        }
    }

    pub fn db(&self) -> &DatabaseManager {
        &self.db
    }

    pub fn baseline_engine(&self) -> &PersonalBaselineEngine {
        &self.baseline_engine
    }

    pub fn fusion_engine(&self) -> &DynamicLateFusionEngine {
        &self.fusion_engine
    }

    /// Ingests daily inputs, calculates within-person deviations against causal history,
    /// performs dynamic multimodal late fusion, and records results to SQLite.
    pub fn process_daily_intake(
        &self,
        user_id: &str,
        date_epoch: &str,
        check_in: Option<CheckInInput>,
        sleep: Option<SleepInput>,
        workload: Option<WorkloadInput>,
        journal_text: Option<&str>,
    ) -> Result<PipelineInferenceResult, rusqlite::Error> {
        let mut crisis_triggered = false;
        let mut checkin_quality = 1.0;

        // 1. Process and store M1: Structured Check-in
        if let Some(ref ci) = check_in {
            let cid = Uuid::new_v4().to_string();
            let latency = ci.completion_latency_sec.unwrap_or(15.0);
            checkin_quality = SignalPreprocessor::assess_checkin_quality(latency);

            let record = CheckInRecord {
                check_in_id: cid,
                user_id: user_id.to_string(),
                timestamp_utc: format!("{}T20:00:00Z", date_epoch),
                session_type: ci.session_type.clone().unwrap_or_else(|| "EVENING".to_string()),
                perceived_stress: ci.perceived_stress,
                mood_valence: ci.mood_valence.unwrap_or(3),
                mood_arousal: ci.mood_arousal.unwrap_or(3),
                motivation_level: ci.motivation_level,
                completion_latency_sec: latency,
            };
            self.db.insert_check_in(&record)?;
        }

        // 2. Process and store M3: Sleep
        let mut curr_sleep_hours: Option<f64> = None;
        if let Some(ref sl) = sleep {
            let sid = Uuid::new_v4().to_string();
            let hours = SignalPreprocessor::process_sleep(sl.total_sleep_minutes);
            curr_sleep_hours = Some(hours);

            let record = SleepRecord {
                sleep_id: sid,
                user_id: user_id.to_string(),
                date_epoch: date_epoch.to_string(),
                bedtime_utc: sl.bedtime_utc.clone().unwrap_or_else(|| format!("{}T23:30:00Z", date_epoch)),
                wake_time_utc: sl.wake_time_utc.clone().unwrap_or_else(|| format!("{}T07:15:00Z", date_epoch)),
                total_sleep_minutes: sl.total_sleep_minutes,
                sleep_quality_rating: sl.sleep_quality_rating.or(Some(3)),
                source_type: sl.source_type.clone().unwrap_or_else(|| "MANUAL_LOG".to_string()),
            };
            self.db.insert_sleep(&record)?;
        }

        // 3. Process and store M4: Workload
        let mut curr_workload_intensity: Option<f64> = None;
        if let Some(ref wl) = workload {
            let wid = Uuid::new_v4().to_string();
            let mental = wl.mental_demand_rating;
            let effort = wl.effort_rating.unwrap_or(3);
            let deadlines = wl.impending_deadlines_count.unwrap_or(0);
            let intensity = SignalPreprocessor::process_workload(mental, effort, deadlines);
            curr_workload_intensity = Some(intensity);

            let record = WorkloadRecord {
                workload_id: wid,
                user_id: user_id.to_string(),
                date_epoch: date_epoch.to_string(),
                mental_demand_rating: mental,
                effort_rating: effort,
                tasks_completed_count: wl.tasks_completed_count,
                impending_deadlines_count: wl.impending_deadlines_count,
            };
            self.db.insert_workload(&record)?;
        }

        // 4. Process and store M2: Text Journal with Safety Interceptor
        let mut curr_sentiment: Option<f64> = None;
        if let Some(jt) = journal_text {
            let trimmed = jt.trim();
            if !trimmed.is_empty() {
                let text_res = SignalPreprocessor::process_journal_text(trimmed);
                if text_res.contains_crisis_markers {
                    crisis_triggered = true;
                }
                curr_sentiment = Some(text_res.sentiment_polarity);

                let jid = Uuid::new_v4().to_string();
                let record = JournalRecord {
                    journal_id: jid,
                    user_id: user_id.to_string(),
                    timestamp_utc: format!("{}T21:00:00Z", date_epoch),
                    raw_text_encrypted: trimmed.to_string(),
                    word_count: text_res.word_count,
                    sentiment_polarity: text_res.sentiment_polarity,
                    sentiment_subjectivity: text_res.sentiment_subjectivity,
                    first_person_pronoun_ratio: text_res.first_person_pronoun_ratio,
                    cognitive_tentative_ratio: text_res.cognitive_tentative_ratio,
                };
                self.db.insert_journal(&record)?;
            }
        }

        // 5. Historical causal lookback strictly prior to date_epoch
        let history = self.db.get_rolling_history(user_id, date_epoch, 14)?;
        let calibration_days = self.db.get_calibration_days_count(user_id)?;
        let is_calibrated = calibration_days >= 14;

        // 6. Calculate Within-Person Baseline Deviations (z-scores)
        let mut z_scores: HashMap<String, Option<f64>> = HashMap::new();
        z_scores.insert("check_in".to_string(), None);
        z_scores.insert("sleep".to_string(), None);
        z_scores.insert("workload".to_string(), None);
        z_scores.insert("journal".to_string(), None);
        z_scores.insert("voice".to_string(), None);
        z_scores.insert("activity".to_string(), None);

        // Check-in deviation
        let mut stress_mean = None;
        let mut stress_std = None;
        if let Some(ref ci) = check_in {
            if history.stress.len() >= 3 {
                let mut sorted = history.stress.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
                let med = sorted[sorted.len() / 2];
                let std = PersonalBaselineEngine::compute_mad(&history.stress);
                stress_mean = Some(med);
                stress_std = Some(std);
                let z = (ci.perceived_stress as f64 - med) / std.max(1e-4);
                z_scores.insert("check_in".to_string(), Some(z));
            }
        }

        // Sleep deviation
        let mut sleep_mean = None;
        let mut sleep_std = None;
        if let Some(sleep_hrs) = curr_sleep_hours {
            if history.sleep.len() >= 3 {
                let mut sorted = history.sleep.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
                let med = sorted[sorted.len() / 2];
                let std = PersonalBaselineEngine::compute_mad(&history.sleep);
                sleep_mean = Some(med);
                sleep_std = Some(std);
                let z = (sleep_hrs - med) / std.max(1e-4);
                z_scores.insert("sleep".to_string(), Some(z));
            }
        }

        // Workload deviation
        let mut workload_mean = None;
        let mut workload_std = None;
        if let Some(wl_val) = curr_workload_intensity {
            if history.workload.len() >= 3 {
                let mut sorted = history.workload.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
                let med = sorted[sorted.len() / 2];
                let std = PersonalBaselineEngine::compute_mad(&history.workload);
                workload_mean = Some(med);
                workload_std = Some(std);
                let z = (wl_val - med) / std.max(1e-4);
                z_scores.insert("workload".to_string(), Some(z));
            }
        }

        // Journal sentiment deviation
        if let Some(sent_val) = curr_sentiment {
            if history.sentiment.len() >= 3 {
                let mut sorted = history.sentiment.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
                let med = sorted[sorted.len() / 2];
                let std = PersonalBaselineEngine::compute_mad(&history.sentiment);
                let z = (sent_val - med) / std.max(1e-4);
                z_scores.insert("journal".to_string(), Some(z));
            }
        }

        // Store baseline state
        let baseline_record = UserBaselineRecord {
            baseline_id: Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            date_epoch: date_epoch.to_string(),
            calibration_day_count: calibration_days as i32,
            is_calibrated,
            sleep_mean_hours: sleep_mean,
            sleep_std_hours: sleep_std,
            stress_mean_rating: stress_mean,
            stress_std_rating: stress_std,
            workload_mean_rating: workload_mean,
            workload_std_rating: workload_std,
        };
        self.db.insert_baseline(&baseline_record)?;

        // 7. Dynamic Late Decision Fusion
        let mut qualities = HashMap::new();
        qualities.insert("check_in".to_string(), checkin_quality);
        let fusion_out = self.fusion_engine.fuse_epoch(&z_scores, Some(&qualities));

        // 8. Alerts gating: Suppress alerts during initial 14-day calibration
        let effective_alert = fusion_out.is_alert_triggered && is_calibrated;
        let narrative = if !is_calibrated {
            format!(
                "Personal baseline is calibrating (Day {} of 14). Alerts are suppressed while we model your typical rest and workload equilibrium.",
                calibration_days
            )
        } else {
            fusion_out.explanation_narrative.clone()
        };

        // 9. Store Daily Inference
        let inference_record = DailyInferenceRecord {
            inference_id: Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            date_epoch: date_epoch.to_string(),
            composite_deviation_score: fusion_out.composite_stress_score,
            shift_alert_triggered: effective_alert,
            primary_contributing_modality: fusion_out.primary_contributor.clone(),
            factor_attributions: fusion_out.factor_attributions.clone(),
            explanation_narrative: narrative.clone(),
            epistemic_uncertainty: fusion_out.epistemic_uncertainty,
        };
        self.db.insert_inference(&inference_record)?;

        Ok(PipelineInferenceResult {
            user_id: user_id.to_string(),
            date_epoch: date_epoch.to_string(),
            is_calibrated,
            calibration_day_count: calibration_days as i32,
            composite_stress_score: fusion_out.composite_stress_score,
            is_alert_triggered: effective_alert,
            epistemic_uncertainty: fusion_out.epistemic_uncertainty,
            primary_contributor: fusion_out.primary_contributor,
            factor_attributions: fusion_out.factor_attributions,
            explanation_narrative: narrative,
            crisis_safety_triggered: crisis_triggered,
        })
    }
}
