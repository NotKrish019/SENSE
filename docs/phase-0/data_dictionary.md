# MindPulse (SENSE) — Formal Data Dictionary & Schemas
## Modality Features, Baseline Parameters & Inference Data Schemas

This document defines the formal relational schemas, data types, value ranges, extraction frequencies, and privacy classifications for all data entities in MindPulse.

---

## 1. Privacy Classification Levels
- **Tier 1 (Public / Non-Sensitive):** System timestamps, anonymous app build metadata.
- **Tier 2 (Internal Pseudonymous):** Normalized $z$-scores, baseline anomaly scores, aggregated modality weights.
- **Tier 3 (Sensitive Personal):** Structured check-in ratings, sleep duration, workload counters, step counts.
- **Tier 4 (Highly Sensitive Biometric/Linguistic):** Free-text journal entries, raw voice recordings, fine-grained acoustic prosody vectors.

---

## 2. Modality Data Schemas

### 2.1 M1: Structured Check-ins (`check_ins`)
- *Frequency:* 1–2 times daily (Morning & Evening).
- *Privacy Tier:* Tier 3 (Sensitive Personal).

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `check_in_id` | UUIDv4 | String (36 chars) | No | Unique record identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `timestamp_utc` | ISO 8601 | YYYY-MM-DDTHH:MM:SSZ | No | Timestamp of submission. |
| `session_type` | Enum | `MORNING`, `EVENING`, `ADHOC` | No | Check-in window. |
| `perceived_stress` | Integer | 1 to 5 (Likert) | No | Single-item adapted PSS momentary stress rating. |
| `mood_valence` | Integer | 1 to 5 (Likert) | No | Russell circumplex valence (1=Very Unpleasant, 5=Very Pleasant). |
| `mood_arousal` | Integer | 1 to 5 (Likert) | No | Russell circumplex arousal (1=Low Energy/Tired, 5=High Energy/Alert). |
| `motivation_level`| Integer | 1 to 5 (Likert) | Yes | Current subjective motivation. |
| `completion_latency_sec` | Float | 0.0 to 300.0 | No | Time taken by user to complete the check-in interaction. |

---

### 2.2 M2: Text Journal (`journal_entries`)
- *Frequency:* Optional daily.
- *Privacy Tier:* Tier 4 (Highly Sensitive). Stored on-device encrypted via SQLCipher.

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `journal_id` | UUIDv4 | String (36 chars) | No | Unique entry identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `timestamp_utc` | ISO 8601 | YYYY-MM-DDTHH:MM:SSZ | No | Timestamp of writing. |
| `raw_text_encrypted` | Blob | AES-256-GCM ciphertext | No | Encrypted journal text (accessible only via user PIN/key). |
| `word_count` | Integer | 0 to 2000 | No | Total word tokens. |
| `sentiment_polarity` | Float | -1.0 to +1.0 | No | On-device computed sentiment valence. |
| `sentiment_subjectivity`| Float | 0.0 to 1.0 | No | Ratio of subjective vs objective lexical tokens. |
| `first_person_pronoun_ratio`| Float | 0.0 to 1.0 | No | Pennebaker linguistic marker (I, me, my density). |
| `cognitive_tentative_ratio` | Float | 0.0 to 1.0 | No | Ratio of uncertainty words (maybe, perhaps, wonder). |

---

### 2.3 M3: Sleep Metrics (`sleep_records`)
- *Frequency:* Once daily (Morning). Sourced from manual log or Health Connect / HealthKit.
- *Privacy Tier:* Tier 3 (Sensitive Personal).

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `sleep_id` | UUIDv4 | String (36 chars) | No | Unique sleep record identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `date_epoch` | Date | YYYY-MM-DD | No | Calendar date of wake-up. |
| `bedtime_utc` | ISO 8601 | YYYY-MM-DDTHH:MM:SSZ | No | Reported or detected sleep onset. |
| `wake_time_utc` | ISO 8601 | YYYY-MM-DDTHH:MM:SSZ | No | Reported or detected wake-up. |
| `total_sleep_minutes`| Integer | 0 to 1440 | No | Total Sleep Time (TST). |
| `sleep_quality_rating`| Integer | 1 to 5 (Likert) | Yes | Subjective restfulness upon waking. |
| `source_type` | Enum | `MANUAL_LOG`, `HEALTH_CONNECT`, `HEALTHKIT` | No | Origin of sleep data. |

---

### 2.4 M4: Workload Metrics (`workload_records`)
- *Frequency:* Once daily (Evening or Ad-hoc).
- *Privacy Tier:* Tier 3 (Sensitive Personal).

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `workload_id` | UUIDv4 | String (36 chars) | No | Unique workload entry identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `date_epoch` | Date | YYYY-MM-DD | No | Calendar date. |
| `mental_demand_rating`| Integer | 1 to 5 (Likert) | No | Adapted NASA-TLX mental demand subscale. |
| `effort_rating` | Integer | 1 to 5 (Likert) | No | Adapted NASA-TLX perceived effort subscale. |
| `tasks_completed_count` | Integer | 0 to 50 | Yes | Approximate number of discrete tasks executed. |
| `impending_deadlines_count` | Integer | 0 to 20 | Yes | Critical deadlines due within next 48 hours. |

---

### 2.5 M5: Voice Acoustic Features (`voice_features`)
- *Frequency:* Optional 1x daily (20–30 second voluntary prompt).
- *Privacy Tier:* Tier 4 (Highly Sensitive). **Raw audio is never stored; deleted immediately after extraction.**

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `voice_feature_id` | UUIDv4 | String (36 chars) | No | Unique feature vector identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `timestamp_utc` | ISO 8601 | YYYY-MM-DDTHH:MM:SSZ | No | Timestamp of recording. |
| `duration_sec` | Float | 5.0 to 60.0 | No | Length of audio recording analyzed. |
| `f0_mean_hz` | Float | 50.0 to 500.0 | No | Fundamental frequency mean pitch. |
| `f0_std_hz` | Float | 0.0 to 150.0 | No | Fundamental frequency standard deviation (pitch variability). |
| `jitter_local` | Float | 0.0 to 0.2 | No | Cycle-to-cycle frequency perturbation. |
| `shimmer_local` | Float | 0.0 to 0.3 | No | Cycle-to-cycle amplitude perturbation. |
| `hnr_db` | Float | 0.0 to 40.0 | No | Harmonics-to-noise ratio in decibels. |
| `speaking_rate_syllables_sec` | Float | 0.5 to 10.0 | No | Rate of speech production. |
| `pause_to_speech_ratio` | Float | 0.0 to 2.0 | No | Total silence duration divided by voiced duration. |

---

### 2.6 M6: Physical Activity Metrics (`activity_records`)
- *Frequency:* Once daily (synced at evening).
- *Privacy Tier:* Tier 3 (Sensitive Personal).

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `activity_id` | UUIDv4 | String (36 chars) | No | Unique record identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `date_epoch` | Date | YYYY-MM-DD | No | Calendar date. |
| `daily_step_count` | Integer | 0 to 100,000 | No | Total cumulative steps for date. |
| `active_minutes` | Integer | 0 to 1440 | Yes | Minutes spent in moderate-to-vigorous physical activity. |
| `source_type` | Enum | `MANUAL_LOG`, `HEALTH_CONNECT`, `HEALTHKIT` | No | Origin of activity data. |

---

## 3. Baseline & Inference Schemas

### 3.1 Personal Baseline State (`user_baselines`)
- *Frequency:* Updated nightly on-device via rolling 14-day window.

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `baseline_id` | UUIDv4 | String (36 chars) | No | Unique baseline identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `date_epoch` | Date | YYYY-MM-DD | No | Effective date of baseline. |
| `calibration_day_count` | Integer | 0 to 365 | No | Number of active interaction days contributing to baseline. |
| `is_calibrated` | Boolean | True / False | No | True if `calibration_day_count` $\ge 14$. |
| `sleep_mean_minutes` | Float | 0.0 to 1440.0 | Yes | Rolling 14-day mean sleep duration. |
| `sleep_std_minutes` | Float | 0.0 to 300.0 | Yes | Rolling 14-day sleep standard deviation. |
| `stress_mean_rating` | Float | 1.0 to 5.0 | Yes | Rolling 14-day mean subjective stress rating. |
| `stress_std_rating` | Float | 0.0 to 3.0 | Yes | Rolling 14-day stress rating standard deviation. |
| `workload_mean_rating`| Float | 1.0 to 5.0 | Yes | Rolling 14-day mean mental demand rating. |
| `f0_baseline_mean` | Float | 50.0 to 500.0 | Yes | Personalized vocal pitch baseline. |

---

### 3.2 Daily Inference & Explainable Observation (`daily_inferences`)
- *Frequency:* Computed each evening following user check-in.

| Field Name | Type | Range / Format | Nullable | Description |
| :--- | :--- | :--- | :---: | :--- |
| `inference_id` | UUIDv4 | String (36 chars) | No | Unique inference identifier. |
| `user_id` | UUIDv4 | String (36 chars) | No | Pseudonymous subject identifier. |
| `date_epoch` | Date | YYYY-MM-DD | No | Calendar date. |
| `composite_deviation_score` | Float | 0.0 to 1.0 | No | Late-fusion normalized stress shift index. |
| `shift_alert_triggered` | Boolean | True / False | No | True if multi-day sustained deviation crosses personalized $\tau_{\text{alert}}$. |
| `primary_contributing_modality`| Enum | `CHECK_IN`, `SLEEP`, `WORKLOAD`, `JOURNAL`, `VOICE`, `ACTIVITY`, `NONE` | No | Modality with highest positive SHAP/weight contribution. |
| `explanation_narrative` | Text | Formatted Markdown | No | Human-readable factor-attributed explanation string. |
| `uncertainty_score` | Float | 0.0 to 1.0 | No | Epistemic uncertainty based on missing modality ratio. |

