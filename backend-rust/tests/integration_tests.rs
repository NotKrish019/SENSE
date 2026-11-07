use std::collections::HashMap;
use mindpulse_core::{
    CheckInInput, DatabaseManager, DynamicLateFusionEngine, FusionConfig, MindPulsePipeline,
    SignalPreprocessor, SleepInput, WorkloadInput,
};

#[test]
fn test_crisis_interceptor_detects_explicit_keywords() {
    let crisis_samples = [
        "I feel completely hopeless and want to end my life.",
        "I want to kill myself tonight.",
        "There is no reason to live anymore.",
        "I've been thinking about suicide all day.",
    ];
    for sample in crisis_samples {
        assert!(
            SignalPreprocessor::check_crisis_markers(sample),
            "Failed to detect crisis keyword in: {}",
            sample
        );
    }
}

#[test]
fn test_crisis_interceptor_ignores_benign_stress() {
    let benign_samples = [
        "Today was exhausting and my manager piled on extra deadlines.",
        "I have a killer headache and need some rest.",
        "I am so stressed about tomorrow's exam, I could scream.",
        "Work was so hard today, it almost killed my enthusiasm.",
    ];
    for sample in benign_samples {
        assert!(
            !SignalPreprocessor::check_crisis_markers(sample),
            "False positive crisis alert on benign text: {}",
            sample
        );
    }
}

#[test]
fn test_sentiment_and_subjectivity_extraction() {
    let positive = "I had a great, peaceful, and productive day today!";
    let pos_res = SignalPreprocessor::process_journal_text(positive);
    assert!(pos_res.sentiment_polarity > 0.3);
    assert!(pos_res.sentiment_subjectivity > 0.0);

    let negative = "I felt stressed, overwhelmed, tired, and anxious all afternoon.";
    let neg_res = SignalPreprocessor::process_journal_text(negative);
    assert!(neg_res.sentiment_polarity < -0.3);
    assert!(neg_res.sentiment_subjectivity > 0.0);
}

#[test]
fn test_first_person_pronoun_density() {
    let self_focused = "I told myself that I need to improve my work because I feel tired.";
    let res = SignalPreprocessor::process_journal_text(self_focused);
    assert!(
        res.first_person_pronoun_ratio > 0.25,
        "Expected high first-person pronoun ratio, got {}",
        res.first_person_pronoun_ratio
    );
}

#[test]
fn test_sleep_and_workload_scaling() {
    // 7.5 hours (450 mins)
    let sleep_hrs = SignalPreprocessor::process_sleep(450);
    assert!((sleep_hrs - 7.5).abs() < 1e-6);

    // Sleep clamping: 60 mins -> 2.0 hrs, 1200 mins -> 16.0 hrs
    assert_eq!(SignalPreprocessor::process_sleep(60), 2.0);
    assert_eq!(SignalPreprocessor::process_sleep(1200), 16.0);

    // Workload index: mental=4, effort=3, deadlines=2 -> 0.5*4 + 0.5*3 + 0.2*2 = 2.0 + 1.5 + 0.4 = 3.9
    let wl = SignalPreprocessor::process_workload(4, 3, 2);
    assert!((wl - 3.9).abs() < 1e-6);
}

#[test]
fn test_checkin_quality_penalty_for_sub_2s_latency() {
    assert_eq!(SignalPreprocessor::assess_checkin_quality(1.2), 0.40);
    assert_eq!(SignalPreprocessor::assess_checkin_quality(3.1), 0.75);
    assert_eq!(SignalPreprocessor::assess_checkin_quality(10.5), 1.00);
}

#[test]
fn test_calibration_suppresses_alerts_during_first_14_days() {
    let db = DatabaseManager::open_in_memory().expect("In-memory SQLite");
    let pipeline = MindPulsePipeline::new(db);

    // Feed 5 days of extreme stress during initial calibration
    for d in 1..=5 {
        let date_str = format!("2026-11-{:02}", d);
        let res = pipeline
            .process_daily_intake(
                "user_calib_test",
                &date_str,
                Some(CheckInInput {
                    perceived_stress: 5,
                    mood_valence: Some(1),
                    mood_arousal: Some(5),
                    motivation_level: Some(1),
                    completion_latency_sec: Some(15.0),
                    session_type: Some("EVENING".to_string()),
                }),
                Some(SleepInput {
                    total_sleep_minutes: 4 * 60,
                    sleep_quality_rating: Some(1),
                    bedtime_utc: None,
                    wake_time_utc: None,
                    source_type: None,
                }),
                Some(WorkloadInput {
                    mental_demand_rating: 5,
                    effort_rating: Some(5),
                    tasks_completed_count: Some(2),
                    impending_deadlines_count: Some(4),
                }),
                Some("I am completely exhausted and burned out."),
            )
            .expect("Intake processed");

        assert!(!res.is_calibrated);
        assert!(!res.is_alert_triggered, "Alert must be suppressed during calibration");
        assert!(res.explanation_narrative.contains("calibrating"));
    }
}

#[test]
fn test_causal_rolling_lookback_strictly_past_only() {
    let db = DatabaseManager::open_in_memory().expect("In-memory SQLite");
    let pipeline = MindPulsePipeline::new(db);

    let _ = pipeline.process_daily_intake(
        "user_leakage_test",
        "2026-11-01",
        Some(CheckInInput {
            perceived_stress: 2,
            ..Default::default()
        }),
        None,
        None,
        None,
    );

    let _ = pipeline.process_daily_intake(
        "user_leakage_test",
        "2026-11-02",
        Some(CheckInInput {
            perceived_stress: 2,
            ..Default::default()
        }),
        None,
        None,
        None,
    );

    // Query history strictly before 2026-11-02: must only have 1 record (Nov 1)
    let hist_before_nov2 = pipeline
        .db()
        .get_rolling_history("user_leakage_test", "2026-11-02", 14)
        .expect("Query history");
    assert_eq!(hist_before_nov2.stress.len(), 1);
    assert_eq!(hist_before_nov2.stress[0], 2.0);

    // Query history strictly before 2026-11-03: must have 2 records (Nov 1 and Nov 2)
    let hist_before_nov3 = pipeline
        .db()
        .get_rolling_history("user_leakage_test", "2026-11-03", 14)
        .expect("Query history");
    assert_eq!(hist_before_nov3.stress.len(), 2);
}

#[test]
fn test_missing_modality_late_fusion_maintains_neutral_expectation() {
    let engine = DynamicLateFusionEngine::new(FusionConfig::default());

    // When all modalities are at baseline z=0:
    let mut z_all_zero = HashMap::new();
    z_all_zero.insert("check_in".to_string(), Some(0.0));
    z_all_zero.insert("sleep".to_string(), Some(0.0));
    z_all_zero.insert("workload".to_string(), Some(0.0));
    z_all_zero.insert("journal".to_string(), Some(0.0));
    z_all_zero.insert("voice".to_string(), Some(0.0));
    z_all_zero.insert("activity".to_string(), Some(0.0));

    let out_full = engine.fuse_epoch(&z_all_zero, None);
    assert!((out_full.composite_stress_score - 0.50).abs() < 1e-4);
    assert!((out_full.epistemic_uncertainty - 0.0).abs() < 1e-4);

    // When 50% of modalities are missing (voice, activity, journal missing):
    let mut z_partial = HashMap::new();
    z_partial.insert("check_in".to_string(), Some(0.0));
    z_partial.insert("sleep".to_string(), Some(0.0));
    z_partial.insert("workload".to_string(), Some(0.0));
    z_partial.insert("journal".to_string(), None);
    z_partial.insert("voice".to_string(), None);
    z_partial.insert("activity".to_string(), None);

    let out_partial = engine.fuse_epoch(&z_partial, None);
    assert!(
        (out_partial.composite_stress_score - 0.50).abs() < 1e-4,
        "Missing modalities must not bias neutral baseline score"
    );
    // Missing weights: 0.10 (journal) + 0.10 (voice) + 0.05 (activity) = 0.25 uncertainty
    assert!((out_partial.epistemic_uncertainty - 0.25).abs() < 1e-4);
}

#[test]
fn test_sustained_stress_triggers_alert_and_attribution() {
    let db = DatabaseManager::open_in_memory().expect("In-memory SQLite");
    let pipeline = MindPulsePipeline::new(db);
    let user_id = "user_alert_test";

    // 14 days of baseline calibration (mild, steady stress 2, sleep 8h, workload 2)
    for d in 1..=14 {
        let date_str = format!("2026-10-{:02}", d);
        pipeline
            .process_daily_intake(
                user_id,
                &date_str,
                Some(CheckInInput {
                    perceived_stress: 2,
                    mood_valence: Some(4),
                    mood_arousal: Some(3),
                    motivation_level: Some(3),
                    completion_latency_sec: Some(15.0),
                    session_type: Some("EVENING".to_string()),
                }),
                Some(SleepInput {
                    total_sleep_minutes: 8 * 60,
                    sleep_quality_rating: Some(4),
                    bedtime_utc: None,
                    wake_time_utc: None,
                    source_type: None,
                }),
                Some(WorkloadInput {
                    mental_demand_rating: 2,
                    effort_rating: Some(2),
                    tasks_completed_count: Some(5),
                    impending_deadlines_count: Some(0),
                }),
                Some("Feeling calm, productive, and balanced today."),
            )
            .expect("Calibration day intake");
    }

    // Now Day 15: severe sustained drift (stress 5, sleep 4h, workload 5)
    let res = pipeline
        .process_daily_intake(
            user_id,
            "2026-10-15",
            Some(CheckInInput {
                perceived_stress: 5,
                mood_valence: Some(1),
                mood_arousal: Some(5),
                motivation_level: Some(1),
                completion_latency_sec: Some(12.0),
                session_type: Some("EVENING".to_string()),
            }),
            Some(SleepInput {
                total_sleep_minutes: 4 * 60,
                sleep_quality_rating: Some(1),
                bedtime_utc: None,
                wake_time_utc: None,
                source_type: None,
            }),
            Some(WorkloadInput {
                mental_demand_rating: 5,
                effort_rating: Some(5),
                tasks_completed_count: Some(1),
                impending_deadlines_count: Some(4),
            }),
            Some("Exhausted, overwhelmed, and completely drained."),
        )
        .expect("Day 15 intake");

    assert!(res.is_calibrated, "User must be calibrated after 14 days");
    assert!(res.is_alert_triggered, "Sustained high drift must trigger alert");
    assert!(
        res.composite_stress_score > 0.70,
        "Composite score should exceed 0.70, got {}",
        res.composite_stress_score
    );
    assert_ne!(res.primary_contributor, "none");
    assert!(res.explanation_narrative.contains("elevated stress pattern"));
}

#[test]
fn test_dpdp_act_2023_export_and_purge() {
    let db = DatabaseManager::open_in_memory().expect("In-memory SQLite");
    let pipeline = MindPulsePipeline::new(db);
    let user_id = "user_dpdp_test";

    pipeline
        .process_daily_intake(
            user_id,
            "2026-11-01",
            Some(CheckInInput {
                perceived_stress: 3,
                ..Default::default()
            }),
            None,
            None,
            None,
        )
        .expect("Intake processed");

    // 1. Verify JSON export
    let exported = pipeline.db().export_user_data_json(user_id).expect("Export JSON");
    assert!(exported.contains("MindPulse"));
    assert!(exported.contains("user_dpdp_test"));
    assert!(exported.contains("check_ins"));

    // 2. Verify complete purge
    pipeline.db().purge_user_data(user_id).expect("Purge user");
    let calib_days = pipeline.db().get_calibration_days_count(user_id).expect("Count");
    assert_eq!(calib_days, 0, "All user records must be purged");
}
