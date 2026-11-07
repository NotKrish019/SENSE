//! MindPulse Core Rust Library (mindpulse_core)
//! High-performance, memory-safe longitudinal well-being analytics and multimodal baseline engine.

pub mod baseline;
pub mod database;
pub mod fusion;
pub mod models;
pub mod pipeline;
pub mod preprocessor;

pub use baseline::{BaselineConfig, BaselineResult, CusumResult, PersonalBaselineEngine};
pub use database::{DatabaseManager, RollingHistory};
pub use fusion::{DynamicLateFusionEngine, FusionConfig, FusionOutput};
pub use models::*;
pub use pipeline::{CheckInInput, MindPulsePipeline, SleepInput, WorkloadInput};
pub use preprocessor::{PreprocessedTextResult, SignalPreprocessor};
