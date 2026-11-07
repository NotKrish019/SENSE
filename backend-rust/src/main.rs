use clap::{Parser, Subcommand};
use mindpulse_core::{
    CheckInInput, DatabaseManager, MindPulsePipeline, SleepInput, WorkloadInput,
};

#[derive(Parser)]
#[command(name = "mindpulse-cli")]
#[command(about = "MindPulse Rust Backend CLI & Research Pipeline Verification Tool", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run multi-day longitudinal simulation populating SQLite and verifying baseline adaptation
    RunSimulation {
        #[arg(short, long, default_value_t = 30)]
        days: usize,
        #[arg(short, long, default_value = "user_001")]
        user_id: String,
        #[arg(short = 'p', long, default_value = "data/mindpulse_rust.db")]
        db_path: String,
    },
    /// Verify crisis keyword interceptor
    TestCrisis,
    /// Export user records as JSON under DPDP Act 2023 data portability
    ExportData {
        #[arg(short, long, default_value = "user_001")]
        user_id: String,
        #[arg(short = 'p', long, default_value = "data/mindpulse_rust.db")]
        db_path: String,
    },
    /// Permanently wipe user records under DPDP Act 2023 right to erasure
    PurgeData {
        #[arg(short, long, default_value = "user_001")]
        user_id: String,
        #[arg(short = 'p', long, default_value = "data/mindpulse_rust.db")]
        db_path: String,
    },
}

struct SimpleRng {
    state: u64,
}

impl SimpleRng {
    fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    fn next_u64(&mut self) -> u64 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 7;
        self.state ^= self.state << 17;
        self.state
    }

    fn next_f64(&mut self) -> f64 {
        (self.next_u64() as f64) / (u64::MAX as f64)
    }

    fn normal(&mut self, mean: f64, std: f64) -> f64 {
        let u1 = self.next_f64().max(1e-10);
        let u2 = self.next_f64();
        let z0 = (-2.0 * u1.ln()).sqrt() * (2.0 * std::f64::consts::PI * u2).cos();
        mean + z0 * std
    }
}

fn run_simulation(days: usize, user_id: &str, db_path: &str) -> Result<(), Box<dyn std::error::Error>> {
    println!("\n=======================================================");
    println!("  MindPulse Rust System Simulation: {} Days for '{}'", days, user_id);
    println!("  Database Target: {}", db_path);
    println!("=======================================================\n");

    let db = DatabaseManager::open(db_path)?;
    let pipeline = MindPulsePipeline::new(db);

    // Clean previous records for clean simulation run
    let _ = pipeline.db().purge_user_data(user_id);

    let mut rng = SimpleRng::new(42);

    println!("{:<5} | {:<10} | {:<6} | {:<6} | {:<8} | {:<11} | {:<10} | {:<6} | Contributor",
        "Day", "Date", "Stress", "Sleep", "Workload", "Calibrated?", "Comp Score", "Alert?");
    println!("{}", "-".repeat(92));

    for d in 1..=days {
        let day_str = format!("2026-10-{:02}", d);

        // Baseline sampled values
        let mut stress = (rng.normal(2.5, 0.6).round() as i32).clamp(1, 5);
        let mut sleep_mins = (rng.normal(7.5 * 60.0, 45.0).round() as i32).clamp(4 * 60, 10 * 60);
        let mut mental_demand = (rng.normal(2.5, 0.7).round() as i32).clamp(1, 5);
        let mut deadlines = 0;

        // Scenario 1: Acute 1-day spike on Day 18 (CUSUM filter test)
        if d == 18 {
            stress = 5;
            sleep_mins = 4 * 60;
            mental_demand = 5;
            deadlines = 3;
        }

        // Scenario 2: Sustained allostatic drift on Days 23-27
        if (23..=27).contains(&d) {
            stress = 4;
            sleep_mins = 5 * 60 + 15;
            mental_demand = 4;
            deadlines = 2;
        }

        let journal_text = if stress <= 3 {
            "Productive day overall."
        } else {
            "Feeling quite drained and exhausted today."
        };

        let res = pipeline.process_daily_intake(
            user_id,
            &day_str,
            Some(CheckInInput {
                perceived_stress: stress,
                mood_valence: Some((6 - stress).max(1)),
                mood_arousal: Some(3),
                motivation_level: Some(3),
                completion_latency_sec: Some(12.5),
                session_type: Some("EVENING".to_string()),
            }),
            Some(SleepInput {
                total_sleep_minutes: sleep_mins,
                sleep_quality_rating: Some(if sleep_mins > 6 * 60 { 3 } else { 2 }),
                bedtime_utc: None,
                wake_time_utc: None,
                source_type: Some("MANUAL_LOG".to_string()),
            }),
            Some(WorkloadInput {
                mental_demand_rating: mental_demand,
                effort_rating: Some(mental_demand),
                tasks_completed_count: Some(5),
                impending_deadlines_count: Some(deadlines),
            }),
            Some(journal_text),
        )?;

        let calib_str = if res.is_calibrated {
            "YES".to_string()
        } else {
            format!("NO ({}/14)", res.calibration_day_count)
        };
        let alert_str = if res.is_alert_triggered { "ALERT!" } else { "No" };
        let sleep_hrs_str = format!("{:.1}h", sleep_mins as f64 / 60.0);

        println!("{:<5} | {:<10} | {:<6} | {:<6} | {:<8} | {:<11} | {:<10.3} | {:<6} | {}",
            d, day_str, stress, sleep_hrs_str, mental_demand, calib_str, res.composite_stress_score, alert_str, res.primary_contributor);
    }

    println!("\nSimulation complete. Querying latest narrative from database...");
    if let Some(latest) = pipeline.db().get_latest_inference(user_id)? {
        println!("\n[Latest Narrative for {}]:", latest.date_epoch);
        println!("\"{}\"", latest.explanation_narrative);
        println!("Factor Attributions: {:?}", latest.factor_attributions);
    }
    println!("\nTo inspect full JSON export, run: cargo run --bin mindpulse-cli -- export-data --user-id {}", user_id);

    Ok(())
}

fn test_crisis() -> Result<(), Box<dyn std::error::Error>> {
    let db = DatabaseManager::open_in_memory()?;
    let pipeline = MindPulsePipeline::new(db);

    let test_phrases = [
        ("I had a very busy and stressful day at the office.", false),
        ("My sleep was terrible and my workload is high.", false),
        ("I feel like I want to die, nothing matters anymore.", true),
        ("I don't see any hope and I want to kill myself.", true),
        ("I'm feeling calm and refreshed after taking a walk.", false),
    ];

    println!("\n=== Running Crisis Safety Interceptor Verification ===");
    let mut all_passed = true;
    for (text, expected) in test_phrases {
        let result = pipeline.process_daily_intake(
            "test_safety_user",
            "2026-11-06",
            None,
            None,
            None,
            Some(text),
        )?;
        let passed = result.crisis_safety_triggered == expected;
        let status = if passed { "[PASS]" } else { "[FAIL]" };
        if !passed {
            all_passed = false;
        }
        let preview = if text.len() > 45 { &text[..45] } else { text };
        println!("{} Text: \"{}...\" -> Intercepted: {} (Expected: {})",
            status, preview, result.crisis_safety_triggered, expected);
    }

    println!("\nCrisis Interceptor Status: {}", if all_passed { "100% VERIFIED" } else { "FAILURES DETECTED" });
    Ok(())
}

fn export_data(user_id: &str, db_path: &str) -> Result<(), Box<dyn std::error::Error>> {
    let db = DatabaseManager::open(db_path)?;
    let data = db.export_user_data_json(user_id)?;
    println!("{}", data);
    Ok(())
}

fn purge_data(user_id: &str, db_path: &str) -> Result<(), Box<dyn std::error::Error>> {
    let db = DatabaseManager::open(db_path)?;
    db.purge_user_data(user_id)?;
    println!("Successfully purged all personal records for '{}' from {}.", user_id, db_path);
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::RunSimulation { days, user_id, db_path } => {
            run_simulation(days, &user_id, &db_path)?;
        }
        Commands::TestCrisis => {
            test_crisis()?;
        }
        Commands::ExportData { user_id, db_path } => {
            export_data(&user_id, &db_path)?;
        }
        Commands::PurgeData { user_id, db_path } => {
            purge_data(&user_id, &db_path)?;
        }
    }

    Ok(())
}
