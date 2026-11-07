use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Modality M1: Structured Check-in Record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckInRecord {
    pub check_in_id: String,
    pub user_id: String,
    pub timestamp_utc: String,
    pub session_type: String, // MORNING, EVENING, ADHOC
    pub perceived_stress: i32, // 1 to 5
    pub mood_valence: i32,    // 1 to 5
    pub mood_arousal: i32,    // 1 to 5
    pub motivation_level: Option<i32>,
    pub completion_latency_sec: f64,
}

/// Modality M3: Sleep Record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SleepRecord {
    pub sleep_id: String,
    pub user_id: String,
    pub date_epoch: String, // YYYY-MM-DD
    pub bedtime_utc: String,
    pub wake_time_utc: String,
    pub total_sleep_minutes: i32,
    pub sleep_quality_rating: Option<i32>,
    pub source_type: String, // MANUAL_LOG, HEALTH_CONNECT, HEALTHKIT
}

/// Modality M4: Cognitive Workload Record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkloadRecord {
    pub workload_id: String,
    pub user_id: String,
    pub date_epoch: String,
    pub mental_demand_rating: i32,
    pub effort_rating: i32,
    pub tasks_completed_count: Option<i32>,
    pub impending_deadlines_count: Option<i32>,
}

/// Modality M2: Text Journal Record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JournalRecord {
    pub journal_id: String,
    pub user_id: String,
    pub timestamp_utc: String,
    pub raw_text_encrypted: String,
    pub word_count: i32,
    pub sentiment_polarity: f64,
    pub sentiment_subjectivity: f64,
    pub first_person_pronoun_ratio: f64,
    pub cognitive_tentative_ratio: f64,
}

/// User Baseline Record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserBaselineRecord {
    pub baseline_id: String,
    pub user_id: String,
    pub date_epoch: String,
    pub calibration_day_count: i32,
    pub is_calibrated: bool,
    pub sleep_mean_hours: Option<f64>,
    pub sleep_std_hours: Option<f64>,
    pub stress_mean_rating: Option<f64>,
    pub stress_std_rating: Option<f64>,
    pub workload_mean_rating: Option<f64>,
    pub workload_std_rating: Option<f64>,
}

/// Daily Inference & Explanation Record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyInferenceRecord {
    pub inference_id: String,
    pub user_id: String,
    pub date_epoch: String,
    pub composite_deviation_score: f64,
    pub shift_alert_triggered: bool,
    pub primary_contributing_modality: String,
    pub factor_attributions: HashMap<String, f64>,
    pub explanation_narrative: String,
    pub epistemic_uncertainty: f64,
}

/// Result of processing a daily intake packet
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PipelineInferenceResult {
    pub user_id: String,
    pub date_epoch: String,
    pub is_calibrated: bool,
    pub calibration_day_count: i32,
    pub composite_stress_score: f64,
    pub is_alert_triggered: bool,
    pub epistemic_uncertainty: f64,
    pub primary_contributor: String,
    pub factor_attributions: HashMap<String, f64>,
    pub explanation_narrative: String,
    pub crisis_safety_triggered: bool,
}

