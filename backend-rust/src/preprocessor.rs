use regex::Regex;
use std::collections::HashSet;
use std::sync::OnceLock;

static CRISIS_REGEX: OnceLock<Regex> = OnceLock::new();

fn get_crisis_regex() -> &'static Regex {
    CRISIS_REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b(suicide|kill myself|end my life|want to die|hang myself|slit my wrist|take all my pills|no reason to live)\b")
            .expect("Valid crisis regex pattern")
    })
}

#[derive(Debug, Clone)]
pub struct PreprocessedTextResult {
    pub word_count: i32,
    pub sentiment_polarity: f64,
    pub sentiment_subjectivity: f64,
    pub first_person_pronoun_ratio: f64,
    pub cognitive_tentative_ratio: f64,
    pub contains_crisis_markers: bool,
}

pub struct SignalPreprocessor;

impl SignalPreprocessor {
    /// Deterministic safety scanner checking for explicit self-harm or suicidal expressions
    pub fn check_crisis_markers(text: &str) -> bool {
        let trimmed = text.trim();
        if trimmed.is_empty() {
            return false;
        }
        get_crisis_regex().is_match(trimmed)
    }

    /// Extracts word count, sentiment polarity, and pronoun density from journal reflections
    pub fn process_journal_text(text: &str) -> PreprocessedTextResult {
        let trimmed = text.trim();
        if trimmed.is_empty() {
            return PreprocessedTextResult {
                word_count: 0,
                sentiment_polarity: 0.0,
                sentiment_subjectivity: 0.0,
                first_person_pronoun_ratio: 0.0,
                cognitive_tentative_ratio: 0.0,
                contains_crisis_markers: false,
            };
        }

        let has_crisis = Self::check_crisis_markers(trimmed);

        let positive_words: HashSet<&'static str> = [
            "good", "great", "calm", "peaceful", "happy", "relaxed", "productive",
            "accomplished", "rested", "energized", "clear", "grateful", "confident",
            "balanced", "smooth", "content", "joy", "supported", "refreshed"
        ].into_iter().collect();

        let negative_words: HashSet<&'static str> = [
            "stressed", "tired", "exhausted", "overwhelmed", "anxious", "worried",
            "frustrated", "angry", "sad", "drained", "hectic", "chaotic", "furious",
            "struggling", "depressed", "nervous", "tense", "burnout", "hopeless"
        ].into_iter().collect();

        let tentative_words: HashSet<&'static str> = [
            "maybe", "perhaps", "guess", "unsure", "wonder", "suppose", "doubt",
            "possibly", "hesitant", "confused", "uncertain"
        ].into_iter().collect();

        let pronouns: HashSet<&'static str> = [
            "i", "me", "my", "mine", "myself"
        ].into_iter().collect();

        let words: Vec<String> = trimmed
            .split_whitespace()
            .map(|w| w.trim_matches(|c: char| !c.is_alphabetic()).to_lowercase())
            .filter(|w| !w.is_empty())
            .collect();

        let total_words = words.len();
        if total_words == 0 {
            return PreprocessedTextResult {
                word_count: 0,
                sentiment_polarity: 0.0,
                sentiment_subjectivity: 0.0,
                first_person_pronoun_ratio: 0.0,
                cognitive_tentative_ratio: 0.0,
                contains_crisis_markers: has_crisis,
            };
        }

        let mut pos_count = 0;
        let mut neg_count = 0;
        let mut pronoun_count = 0;
        let mut tentative_count = 0;

        for w in &words {
            if positive_words.contains(w.as_str()) {
                pos_count += 1;
            }
            if negative_words.contains(w.as_str()) {
                neg_count += 1;
            }
            if pronouns.contains(w.as_str()) {
                pronoun_count += 1;
            }
            if tentative_words.contains(w.as_str()) {
                tentative_count += 1;
            }
        }

        let total_affect = pos_count + neg_count;
        let polarity = if total_affect > 0 {
            (pos_count as f64 - neg_count as f64) / total_affect as f64
        } else {
            0.0
        };

        let subjectivity = if total_words > 0 {
            total_affect as f64 / total_words as f64
        } else {
            0.0
        };

        PreprocessedTextResult {
            word_count: total_words as i32,
            sentiment_polarity: polarity.clamp(-1.0, 1.0),
            sentiment_subjectivity: subjectivity.clamp(0.0, 1.0),
            first_person_pronoun_ratio: pronoun_count as f64 / total_words as f64,
            cognitive_tentative_ratio: tentative_count as f64 / total_words as f64,
            contains_crisis_markers: has_crisis,
        }
    }

    /// Converts sleep duration minutes into decimal hours, bounded between 2.0 and 16.0
    pub fn process_sleep(total_sleep_minutes: i32) -> f64 {
        let hours = total_sleep_minutes as f64 / 60.0;
        hours.clamp(2.0, 16.0)
    }

    /// Combines NASA-TLX mental demand, effort rating, and deadline count into a scalar workload index
    pub fn process_workload(mental_demand: i32, effort: i32, deadlines: i32) -> f64 {
        let d = mental_demand.clamp(1, 5) as f64;
        let e = effort.clamp(1, 5) as f64;
        let dl = deadlines.clamp(0, 10).min(5) as f64;
        0.5 * d + 0.5 * e + 0.2 * dl
    }

    /// Discounts reliability weight for rushed random check-in tapping (< 2.0 seconds)
    pub fn assess_checkin_quality(completion_latency_sec: f64) -> f64 {
        if completion_latency_sec < 2.0 {
            0.40
        } else if completion_latency_sec < 4.0 {
            0.75
        } else {
            1.00
        }
    }
}

