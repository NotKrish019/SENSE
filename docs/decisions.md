# MindPulse (SENSE) — Architecture & Research Decision Records (ADR)
## Formal Decision Log

> **Naming note (2026-11-07):** The official product name is **SENSE — Stress Estimation through Networked Signals and Emotions**. "MindPulse" is the former working name; it is retained below in historical decision text and in internal technical identifiers (e.g., `mindpulse` Dart package, `mindpulse_core` Rust crate).

This document records the foundational research, architectural, and governance decisions made for the MindPulse project. Every decision documents the context, alternatives considered, justification, and implications.

---

## Index of Decisions

- [ADR-001: Selection of Flutter as the Cross-Platform Mobile Framework](#adr-001-selection-of-flutter-as-the-cross-platform-mobile-framework)
- [ADR-002: Modular Tiered Architecture for Multimodal Machine Learning](#adr-002-modular-tiered-architecture-for-multimodal-machine-learning)
- [ADR-003: On-Device Feature Extraction for Highly Sensitive Voice & Text](#adr-003-on-device-feature-extraction-for-highly-sensitive-voice--text)
- [ADR-004: Decoupled Independent Crisis Safety Pathway](#adr-004-decoupled-independent-crisis-safety-pathway)
- [ADR-005: Within-Person Statistical Baselines vs. Population Norms as Primary Engine](#adr-005-within-person-statistical-baselines-vs-population-norms-as-primary-engine)
- [ADR-006: Decision-Level Late Fusion for Asynchronous Modality Data](#adr-006-decision-level-late-fusion-for-asynchronous-modality-data)
- [ADR-007: Phased Modular MVP Scoping (Prioritizing M1, M3, M4, M2 before M5, M6)](#adr-007-phased-modular-mvp-scoping-prioritizing-m1-m3-m4-m2-before-m5-m6)
- [ADR-008: Adoption of Rust for Core Backend & Cross-Platform Processing Engine](#adr-008-adoption-of-rust-for-core-backend--cross-platform-processing-engine) *(runtime role superseded in part by ADR-009 K, 2026-11-08)*
- [ADR-009: M0 Research, Data and Runtime Decisions for the Local Data Foundation](#adr-009-m0-research-data-and-runtime-decisions-for-the-local-data-foundation)

---

### ADR-001: Selection of Flutter as the Cross-Platform Mobile Framework
- **Status:** Accepted — joint team decision by Krish (`NotKrish019`, project lead) and the collaborating developer, recorded 2026-11-07. *(Previously: "Proposed (Recommended for Phase 0 Approval)", 2026-11-06.)*
- **Date:** 2026-11-06 (proposed) · 2026-11-07 (accepted; see amendment below)
- **Context:** MindPulse requires a cross-platform mobile client for Android and iOS that supports smooth UI rendering, precise audio recording, health platform integration (Android Health Connect / iOS HealthKit), encrypted local storage (SQLCipher), and lightweight on-device ML model execution.
- **Alternatives Considered:**
  1. *React Native:* Strong ecosystem, but native bridging overhead for audio buffer processing and frequent breaking changes between New Architecture (Fabric/TurboModules) and community health libraries introduce stability risks.
  2. *Kotlin Multiplatform (KMP) + Compose Multiplatform:* Excellent native performance on Android, but iOS UI maturity and iOS audio processing ecosystems are comparatively nascent and require substantial separate Swift engineering.
  3. *Native Android (Kotlin) & iOS (Swift):* Maximizes platform performance, but doubles maintenance overhead and risks divergent feature behavior across platforms during rapid research iterations.
  4. *Flutter (Dart):* High graphics consistency (Impeller rendering engine), unified audio recording libraries (`record`, `audio_waveforms`), production Health integrations (`health` package supporting Android Health Connect & Apple HealthKit), first-class SQLite encryption (`sqflite_sqlcipher`), and mature ONNX/TFLite bindings.
- **Decision:** Select **Flutter (Dart)** as the primary cross-platform mobile framework.
- **Consequences:**
  - Single unified codebase for UI, local business logic, and data storage.
  - Efficient access to OS audio recording and health APIs via validated community plugins.
  - Requires compiling native C/C++ libraries if custom feature extraction binaries (e.g., custom openSMILE bindings) are integrated on-device.

#### ADR-001 Amendment (2026-11-07): Acceptance, single active mobile app, Expo frozen
- **Context:** The 2026-11-06 Phase 0 sign-off (exit criterion 12) treated Flutter as selected, while this ADR still read "Proposed". In parallel, an Expo / React Native implementation (`App.js`, `src/`, `package.json`, `app.json` at the repository root) had been committed alongside the Flutter implementation in `mobile/`, and the README directed developers to run Expo. Two competing mobile apps existed.
- **Decision:**
  1. **Flutter (`mobile/`) is the canonical and only actively developed mobile application.**
  2. **The Expo / React Native implementation is FROZEN — REFERENCE IMPLEMENTATION.** It is retained in the repository, not deleted, and receives no independent feature development. Its files are modified only with explicit authorization. Useful ideas may be consulted for reference but are not copied or migrated automatically in either direction.
- **Why Flutter (in addition to the original reasoning above):**
  - Consistent with this ADR, the Phase 0 sign-off and `docs/phase-0/technical_feasibility.md` (weighted score 4.63 vs. React Native 3.45 vs. KMP 3.60).
  - The Flutter implementation is the more complete code base: shared design tokens (`mobile/lib/core/theme/`), reusable widgets (`mobile/lib/presentation/widgets/`), SQLite data layer, and on-device baseline, late-fusion and crisis-safety logic with Dart tests.
- **Alternatives considered at acceptance:**
  1. *Adopt Expo as canonical:* fastest phone preview today (Expo Go over Wi-Fi), but contradicts the signed-off architecture, lacks shared UI components and on-device engines. Rejected.
  2. *Maintain both apps:* rejected — duplicated effort, divergent UI and safety copy, ambiguous source of truth.
  3. *Delete Expo:* rejected for now — it holds reference ideas (e.g., Log hub screen) and deletion is irreversible; may be revisited as a separate decision.
- **Consequences:**
  - All new mobile UI work happens in `mobile/` only; the README points developers to Flutter.
  - The immediate preview path changes from Expo Go to Flutter Web in Chrome, which requires installing the Flutter SDK and adding web platform files. **Chrome preview is not equivalent to native Android testing.** Native Android/iOS testing additionally requires Android SDK tooling / Xcode and the `android/` / `ios/` platform folders, which do not yet exist.
  - Misleading copy found in the frozen Expo UI (unsupported encryption claims, invented scores) remains there unless a fix is explicitly authorized; the frozen app must not be presented to participants or reviewers as the current product.
  - Statements in this ADR describing plugins (`record`, `health`, `sqflite_sqlcipher`, `onnxruntime`) describe intended capabilities; none of these are dependencies yet (`mobile/pubspec.yaml` currently uses plain `sqflite`, which provides **no encryption**).
- **Approval:** Accepted by joint team decision (Krish / `NotKrish019` and collaborating developer), 2026-11-07, as communicated to Claude Code by the collaborating developer.

---

### ADR-002: Modular Tiered Architecture for Multimodal Machine Learning
- **Status:** Approved
- **Date:** 2026-11-06
- **Context:** Stress manifests across disparate biological, behavioral, and psychological timescales. Bundling raw sensor and survey data directly into an end-to-end monolithic neural network prevents interpretability, fails catastrophically under missing modalities, and impedes scientific isolation of modality contributions.
- **Alternatives Considered:**
  1. *End-to-end Deep Neural Network:* High capacity, but opaque, prone to severe overfitting on small longitudinal cohorts, completely fragile to missing modality inputs, and lacks explainability.
  2. *Single-Modality Analysis only:* High interpretability, but discards cross-modal patterns (e.g., the compounding effect of poor sleep combined with high workload).
- **Decision:** Implement a **Modular 4-Stage Tiered Pipeline**:
  1. *Stage 1 (Modality Preprocessing & Feature Extraction):* Independent modules transform raw inputs into standardized daily feature vectors.
  2. *Stage 2 (Personalized Baseline & Deviation Modeling):* Within-person deviation scoring against personal rolling distributions ($z$-score, EWMA, CUSUM).
  3. *Stage 3 (Temporal & Cross-Modal Fusion):* Asynchronous temporal aggregation and decision-level fusion with missing-modality handling.
  4. *Stage 4 (Explainable Insight Generation):* Feature attribution maps and rule-based template narrative synthesis.
- **Consequences:**
  - Enables modular evaluation where any modality can be plugged in or omitted.
  - Allows strict benchmarking of whether adding a modality yields measurable scientific value.
  - Supports explainability at each distinct phase.

---

### ADR-003: On-Device Feature Extraction for Highly Sensitive Voice & Text
- **Status:** Approved
- **Date:** 2026-11-06
- **Context:** Free-text journal entries (M2) and voice recordings (M5) represent highly sensitive, private personal information. Sending raw audio or plain-text journal reflections to external third-party cloud LLM APIs violates the privacy guarantees of the MindPulse research charter and the DPDP Act 2023.
- **Alternatives Considered:**
  1. *Centralized Cloud Processing with Commercial APIs (OpenAI/Anthropic):* High linguistic accuracy, but severe privacy violation; exposes raw user journals and voice samples to third-party data processors.
  2. *Self-Hosted Cloud Inference Container:* Better data governance, but transmits raw voice recordings over the network, introducing transmission eavesdropping and central server breach risks.
  3. *On-Device Feature Extraction & Transformation:* Audio is converted on-device to non-reconstructible acoustic prosodic features (pitch variance, jitter, shimmer, pause ratio) via openSMILE/ONNX; raw audio is immediately deleted after extraction. Text is processed via on-device embedding/lexicon or zero-knowledge local representation.
- **Decision:** Adopt **On-Device Feature Extraction** for audio and sensitive text. Raw audio recordings shall never leave the device. Only mathematically transformed, irreversible acoustic parameters and lexical sentiment aggregates are retained.
- **Consequences:**
  - Eliminates the risk of ambient audio leaks or journal intercept.
  - Guarantees compliance with Indian DPDP Act 2023 data minimization mandates.
  - Constrains the computational complexity of models to what can execute smoothly on mid-tier mobile hardware.

---

### ADR-004: Decoupled Independent Crisis Safety Pathway
- **Status:** Approved
- **Date:** 2026-11-06
- **Context:** MindPulse is an experimental digital well-being research platform, not a clinical crisis intervention system. Machine learning models for stress are probabilistic and can produce false negatives. If a user is experiencing acute psychological distress or self-harm ideation, relying on an experimental ML model to trigger support is unsafe and ethically unacceptable.
- **Alternatives Considered:**
  1. *ML-Triggered Emergency Escalation:* Using NLP keyword detectors or anomaly scores to trigger crisis hotlines. Rejected because false negatives leave vulnerable individuals without aid, while false positives induce panic and user distrust.
  2. *No Crisis Resources in App:* Unethical; fails duty of care when researching stress and psychological well-being.
  3. *Decoupled, Static, Prominently Accessible Crisis Safety Pathway:* A permanently visible, one-tap safety panel that provides verified national crisis hotlines (e.g., Tele-MANAS, KIRAN 1800-599-0019 in India; 988 in the US) and emergency contacts completely independent of ML model state, supplemented by gentle rule-based keyword safeguards in journal input.
- **Decision:** Implement a **Decoupled Independent Crisis Safety Pathway** accessible at all times with one tap from every app screen.
- **Consequences:**
  - Preserves user safety without conflating experimental well-being research with emergency medical triage.
  - Explicitly states non-clinical disclaimers to ensure users never rely on MindPulse for medical or crisis emergencies.

---

### ADR-005: Within-Person Statistical Baselines vs. Population Norms as Primary Engine
- **Status:** Approved
- **Date:** 2026-11-06
- **Context:** Physiological and subjective stress markers vary drastically across individuals. A resting heart rate or sleep duration that indicates high stress in one individual may represent optimal baseline function in another. Similarly, rating scale usage varies widely (e.g., individual response styles, cultural differences in reporting distress).
- **Alternatives Considered:**
  1. *Global Population-Threshold Classification:* Train a single global model using fixed cutoffs (e.g., PSS $> 26$ = high stress). Suffers from massive inter-individual variability and high false-positive rates for chronically anxious users and false-negatives for stoic users.
  2. *Within-Person Adaptive Baseline Engine:* Compute each user's running historical baseline ($N \ge 14$ days) using Exponentially Weighted Moving Average (EWMA) and dynamic standard deviation bands. Individual stress scores are computed as normalized deviations ($z$-scores) from personal history.
- **Decision:** Establish **Within-Person Personalized Baselines** as the central algorithmic foundation.
- **Consequences:**
  - Requires a "calibration period" (typically 7–14 days) before high-confidence personalized early warnings can be generated.
  - Successfully handles diverse lifestyle rhythms and personal reporting norms.

---

### ADR-006: Decision-Level Late Fusion for Asynchronous Modality Data
- **Status:** Approved
- **Date:** 2026-11-06
- **Context:** In mobile digital health, participant compliance is asynchronous and sporadic. Users may complete a check-in (M1) and track sleep (M3), but skip journaling (M2) or decline voice recording (M5). Early fusion (concatenating all raw feature vectors into a single vector) fails when features are missing and requires complex imputation that can distort signals.
- **Alternatives Considered:**
  1. *Early Feature Concatenation:* Fails or degrades rapidly when $>30\%$ of modalities are unrecorded on a given day. Imputation introduces synthetic artifacts.
  2. *Intermediate Joint Embedding (e.g., Multimodal Autoencoder):* Computationally expensive, requires synchronized training data, and provides poor interpretability.
  3. *Decision-Level Late Fusion with Dynamic Reliability Weighting:* Each modality extracts an independent deviation score and an associated confidence metric. The final well-being shift estimation is a weighted consensus of available modalities.
- **Decision:** Implement **Decision-Level Late Fusion** as the primary multimodal integration mechanism.
- **Consequences:**
  - Gracefully handles missing modalities: if modality $m$ is missing, its weight is set to 0 and the denominator is renormalized without penalizing the user.
  - Preserves full auditability of each modality's specific contribution to the final composite score.

---

### ADR-007: Phased Modular MVP Scoping (Prioritizing M1, M3, M4, M2 before M5, M6)
- **Status:** Approved
- **Date:** 2026-11-06
- **Context:** Attempting to build all six modalities simultaneously creates excessive technical friction, delays user testing, and entangles audio/sensor permission hurdles with baseline engine validation.
- **Alternatives Considered:**
  1. *All-at-Once Implementation (M1–M6 simultaneously):* High risk of delayed delivery, high friction onboarding, and compounded debugging challenges.
  2. *Phased MVP Scoping:*
     - **Phase 2 (MVP):** Low-friction, high-compliance modalities: M1 (Structured Check-ins), M3 (Sleep logging), M4 (Workload rating), and M2 (Text Journal).
     - **Phase 3 (Advanced AI):** Higher-friction modalities: M5 (Voice prosody) and M6 (Passive Health Connect physical activity).
- **Decision:** Adopt **Phased Modular MVP Scoping**. The MVP delivers complete end-to-end functionality using M1, M3, M4, and M2.
- **Consequences:**
  - Accelerates baseline engine verification and UI usability validation.
  - Avoids early battery drain, microphone permission resistance, and background sync pitfalls until the core loop is robust.

---

### ADR-008: Adoption of Rust for Core Backend & Cross-Platform Processing Engine
- **Status:** Approved (Authorized by Project Stakeholder on 2026-11-06)
- **Date:** 2026-11-06
- **Context:** MindPulse requires mathematical parity between on-device mobile execution and central research processing. Re-implementing statistical baselines, CUSUM change detection, and dynamic late fusion across disparate languages (Python for server, Dart for mobile) creates maintenance friction and risk of subtle floating-point drift. Furthermore, processing sensitive health data under the DPDP Act 2023 benefits from strict memory safety and minimal resource footprint.
- **Alternatives Considered:**
  1. *Python-only Backend:* Excellent exploratory ecosystem, but heavy memory footprint ($\sim 200$MB+), difficult to embed natively on mobile devices, and slower execution speeds.
  2. *Node.js / TypeScript:* Event-driven, but lacks native high-performance mathematical computing and cannot be compiled to native C-ABI static libraries for mobile embedding without heavy V8/Hermes overhead.
  3. *Rust Core Engine:* Compiles to standalone high-performance server binaries (Axum/Tokio) AND compiles to C-ABI static libraries (`.so`/`.a`) for direct on-device mobile integration via FFI. Offers zero-cost abstractions, sub-millisecond execution, memory safety, and minimal memory usage ($\sim 15$MB).
- **Decision:** Build the **Core Backend and Shared Mathematical Engine in Rust**. Python is retained exclusively for exploratory research notebooks and training pipelines; production ingestion, baselines, fusion, and SQLite management are unified in Rust.
- **Consequences:**
  - Guarantees 100% bit-for-bit mathematical parity between mobile edge inference and research servers.
  - Sub-millisecond baseline updates and zero garbage collection pauses.
  - Strong compile-time guarantees preventing null pointer dereferences and data races on sensitive participant data.

#### ADR-008 Amendment (2026-11-08): Runtime role superseded in part by ADR-009 (Decision K)
- **Context:** The 2026-11-08 engineering audit found that the Rust crate (`backend-rust/`) is a command-line research tool with its own SQLite database: it has no HTTP server, no C-ABI/FFI build, and no connection to the Flutter app. The Flutter app already contains Dart ports of the baseline and fusion engines (`mobile/lib/domain/`). Embedding a Rust (or Python) runtime in Android is not justified by any existing code.
- **Decision:** For the Flutter application, on-device computation uses the existing **Dart** baseline engine (ADR-009 K). Rust and Python remain **research / reference** implementations. Neither runtime is embedded in Android.
- **What is superseded:** ADR-008's statements that "production ingestion, baselines, fusion, and SQLite management are unified in Rust" and that Rust is compiled for "direct on-device mobile integration via FFI". **What remains:** Rust is kept as a separate reference CLI; the original ADR-008 text above is preserved as the historical record.
- **Consequences:** Bit-for-bit parity is no longer guaranteed by a shared binary. Parity between the Dart, Python and Rust implementations must instead be checked with shared fixture tests (planned; not yet implemented).



---

### ADR-009: M0 Research, Data and Runtime Decisions for the Local Data Foundation
- **Status:** Approved (M0 decision brief, 2026-11-08). Recorded together with the Milestone A implementation in `mobile/lib/data/local/`.
- **Date:** 2026-11-08
- **Version:** 1.0
- **Context:** The production UI (Living Landscapes, Phases 1 to 5) is complete, but no screen saves anything. The 2026-11-08 audit found an unused legacy SQLite helper (`mobile/lib/data/database/database_helper.dart`, schema v1) whose fields do not match the production screens (for example mood valence and arousal, where the check-in collects one mood rating), whose consent table is seeded with four inputs ON, and whose `raw_text_encrypted` journal column has no encryption behind it. These decisions settle the research and data questions before any real data is stored. They do not change any screen, default or range.
- **Decisions:**
  - **A. M1 structured check-in.** Three distinct ordinal self-reports, each an integer 1 to 5: mood rating, motivation/energy rating, perceived stress rating. Mood is **not** mapped to valence or arousal. Motivation/energy is **one combined item**, not interpreted as arousal and not split. Screen labels, defaults (3, 3, 2) and ranges are preserved.
  - **B. Default-value provenance.** An explicit Save submits the displayed values, including untouched defaults. Each record stores which fields the person changed, which stayed at their initial default, and the submission time. Untouched defaults keep their values but are never indistinguishable from adjusted ones.
  - **C. M3 sleep.** Duration 240 to 720 minutes in 30-minute steps, default 450; bedtime and wake time as separate local wall-clock values (defaults 23:30 and 07:00); rest quality 1 to 5 (default 4). Duration is stored independently and is **never derived** from the two times.
  - **D. M4 workload.** Mental demand 1 to 5, effort 1 to 5 (defaults 3, 3), deadlines in the next 48 hours 0 to 20 (default 1). The data dictionary's 0 to 20 range is authoritative. **Required correction for Milestone D:** the production deadline counter currently has no upper limit and must be capped at 20 when it is connected (no UI change in M0/A).
  - **E. M6 activity (manual).** Steps 1,000 to 20,000 in 500-step increments, with the exact initial default 6,800 as a deliberate, preserved exception (recorded as untouched; never rounded to 7,000). Active minutes 0 to 120 in steps of 5, default 35. Manual entry is the only available input; Health Connect remains unavailable.
  - **F. M2 journal.** Raw journal text is **not** persisted, in plaintext or otherwise, until real encryption is implemented and verified, keys are securely managed, consent and access controls exist, retention and deletion are defined, and Export/Erase handle encrypted content. The legacy `raw_text_encrypted` name does not establish encryption. The on-device crisis-phrase check is preserved; journal text is never sent to a backend or external service.
  - **G. Consent.** Six modality preferences, M1 to M6, all OFF by default. They are not formal research-participation consent, not operating-system permissions, and not evidence of ethics approval. Future writes must be gated by the matching persisted preference (Milestone B). `ConsentPreferences` and the Consent screen are unchanged now.
  - **H. Identity and timestamps.** Single-person, local-first, no accounts. A locally generated random UUID is the **pseudonymous, device-local** person identifier (it is not anonymous). No names, email addresses or external account identifiers. UTC timestamps for creation and updates; local calendar dates as `YYYY-MM-DD`; local wall-clock strings for sleep times; the local UTC offset stored with each daily record.
  - **I. Retention and data management.** Records are kept until the person explicitly erases them. No cloud synchronisation, analytics telemetry or external transmission. Future Export (Milestone C) includes all records, consent history, schema version and export time. Future Erase (Milestone C) is transactional and removes input records, consent history, baseline state, derived observations and the local identity (and any preserved legacy tables); afterwards a new local identity starts with all preferences OFF.
  - **J. Local storage and encryption.** Native Android is the intended real-data platform. SQLite with an explicit schema version, forward-only migrations, transactions, foreign keys, typed repositories, unique daily-record constraints and no destructive schema replacement. Real participant data must not be stored in an unencrypted production database: SQLCipher-protected storage with Android Keystore-backed key management is required, after a compatibility and security review. Until that is verified, production screens are not connected to persistent writes, raw journal text is not stored, and database tests use disposable development data only. Chrome remains a UI development target and may hold data in memory only.
  - **K. Local inference runtime.** The Flutter app uses the existing Dart baseline engine. Python remains the research/reference pipeline and Rust a separate research/reference CLI. Neither is embedded in Android. *This supersedes ADR-008's on-device/production runtime role (see the ADR-008 amendment above); ADR-008 is preserved.*
  - **L. Personal baseline.** Start from the existing Dart implementation: 14-day window, at least seven valid observations per variable, rolling median/MAD with the existing EWMA/CUSUM. Descriptive within-person observations only. No composite stress score, alert, diagnosis or clinical risk output is exposed to users. Integration is Milestone E.
  - **M. Late fusion.** The existing fusion engine (ADR-006) stays disconnected from the user interface; its implementation is unchanged. Its prior weights, alert threshold and synthetic-only validation do not justify user-facing output. Promotion requires independent validation and an approved non-clinical output definition. *ADR-006 remains the research method; this decision restricts its product use.*
- **Consequences:**
  - Milestone A implements schema v2 (`mobile/lib/data/local/`): M1, M3, M4 and manual M6 daily tables with provenance and one record per person per date; a pseudonymous profile; empty consent-event, baseline and observation tables; no journal table. The legacy v1 tables are preserved unchanged as `legacy_v1_*`; they are not converted because their meanings differ.
  - The legacy `DatabaseHelper` is deprecated and remains uncalled.
  - The database is **not encrypted** and the app does **not** write to it. Both remain blocked by Decision J and Milestone B.
  - Field-level differences from the Phase 0 data dictionary are listed in its 2026-11-08 amendment (`docs/phase-0/data_dictionary.md`).

#### ADR-009 Implementation record (2026-11-08): Milestone B, persistent consent history and write gating
This records how Decision G is implemented. It does not change any ADR-009 decision.
- **Scope:** `mobile/lib/data/local/consent.dart` (new), `repositories.dart`, `sqlite_repositories.dart` and `local_data_store.dart`; tests in `mobile/test/consent_gating_test.dart`. Schema v2 is unchanged: the Milestone A `consent_events` table already had everything needed.
- **Event schema and ordering:** each event has an `id` (`INTEGER PRIMARY KEY AUTOINCREMENT`), `local_person_id` (foreign key to `local_profile`), `modality` (`M1` to `M6`, enforced by a CHECK and in Dart), `enabled` (0 or 1) and `changed_at_utc`. AUTOINCREMENT ids strictly increase and are never reused, so history is ordered by `id`, and the current preference for a person and modality is the event with the highest `id`. Ordering is therefore deterministic even when two events share a timestamp.
- **Append-only application API:** `ConsentRepository` (replacing Milestone A's read-only `ConsentHistoryReader`) offers `recordChange`, `isEnabled`, `currentPreferences`, `snapshot` and `history`. It has no update or delete operation; every change, including one that repeats the current state, appends an event. Append-only is enforced by the API, not by a database trigger: deleting the local profile still removes its history through the foreign key, as the future Erase (Milestone C) requires.
- **Default OFF:** no events are seeded. A modality with no event reads OFF. The legacy pre-ticked `legacy_v1_consent_settings` table is never read.
- **Authorization mapping:** check-ins require M1, sleep M3, workload M4 and manual activity M6. M2 (journal) and M5 (voice) have no write repository, so turning them on unlocks nothing.
- **Atomicity:** `upsert` checks the preference with the same executor and inside the same transaction as the write (reusing a caller's transaction from `LocalDataStore.transaction`). sqflite begins transactions with `BEGIN IMMEDIATE` and serialises operations per connection, so no consent change can commit between the check and the write. A consent change and a record written under it in one `LocalDataStore.transaction` commit or roll back together; a denied write inside such a transaction rolls back the whole transaction.
- **Fail closed:** a write is refused with `ConsentDeniedException` (modality plus reason `noProfile`, `notRecorded`, `disabled` or `unavailable`, with a message containing no record values) when the local profile is missing, no event exists, the latest event is OFF, or the consent state cannot be read (for example a missing table or a corrupt row). Nothing is written in any of these cases. Turning a preference OFF blocks later writes but does not delete existing records; deletion belongs to Export/Erase (Milestone C). `deleteByDate` is not gated, so a person can always remove their own records.
- **Tested persistence versus the shipped app:** the persistent consent repository is verified only against disposable SQLite files in tests. The shipped app is unchanged: the Consent screen still uses the in-memory `ConsentPreferences` (all OFF by default, reset on reload, with the same identifiers, wording and design), no production code opens the database, and no Save handler writes to it.
- **Why production persistence stays blocked:** the SQLite database is **not encrypted**. Under Decision J, real participant data, including consent history, must not be stored until SQLCipher-protected storage with Android Keystore-backed key management has passed a compatibility and security review, and the Android project needed to host it does not exist yet. Connecting `ConsentPreferences` and the screens to this repository is a later milestone, after that work.

#### ADR-009 Implementation record (2026-11-09): Milestone C, local export and transactional erase
This records how Decision I (export and erase) is implemented. It does not change any ADR-009 decision.
- **Scope:** `mobile/lib/data/local/local_data_service.dart` (new) with tests in `mobile/test/local_data_service_test.dart`. `LocalDataService` takes an already opened database (no global instance) and reuses `LocalDataStore` and its repositories. No schema change.
- **Export format (`sense-local-export`, version 1):** a JSON document returned in memory with `format`, `format_version`, `exported_at_utc`, `schema_version`, `app_version` (null unless the caller supplies it; the app has no runtime source for it without a new dependency), the active `local_profile`, `warnings`, and three table sections. `tables` holds every row of `local_profile`, `check_ins`, `sleep_records`, `workload_records`, `activity_records`, `consent_events`, `baselines` and `observations`, for every local identity. `legacy_v1_tables` holds every retained legacy table. `system_metadata` holds `migration_log`. Each table lists its columns in declared order (read with `PRAGMA table_xinfo`, so VIRTUAL and STORED generated columns and their computed values are included, and named in a `generated_columns` entry), its row count and its rows with their original column names. A column the export cannot represent, such as a hidden virtual-table column, makes the export fail rather than leave it out. Rows are in a fixed order (daily tables by person, date and id; consent events by event id; legacy tables by rowid), so the same data and clock give identical output. Binary values are Base64 with an explicit `$type`/`encoding` marker, and non-finite numbers are kept as marked text.
- **Legacy data:** legacy tables are discovered from `sqlite_master` with the strict `legacy_v1_` prefix (validated by a name pattern and quoted as identifiers), so new or unexpected legacy tables and columns are included rather than dropped. They are exported exactly as stored and are not converted into current records. When `legacy_v1_journal_entries` exists, the export warns that `raw_text_encrypted` may contain plaintext and is not verified ciphertext. Every export also states that it is not encrypted.
- **Snapshot consistency and failure:** the whole export runs in one transaction (sqflite's `BEGIN IMMEDIATE`), so concurrent writes are either entirely included or entirely excluded. Any query failure aborts the export with the underlying error; no partial export is returned. Export does not change the database and nothing is logged or printed. It is not written to disk, shared or transmitted.
- **Erase sequence (one transaction):** inspect the schema; delete every row from `consent_events`, `observations`, `baselines`, the four daily tables, every `legacy_v1_*` table, and `local_profile`; verify each is empty; create a new local identity through the existing profile repository; verify it differs from every previous identity and that all six preferences read OFF with no consent events. Any failure, including a failure after all deletions, rolls back everything and is rethrown; there is no partial success.
- **Identity rotation and default OFF:** after an erase there is exactly one, new, active pseudonymous identity, no consent events, and therefore every preference OFF; daily writes stay refused until a preference is turned on again.
- **Kept on purpose:** table structures, `migration_log` (schema versions, timestamps and legacy table row counts, no record contents or identity) and SQLite's own tables. `sqlite_sequence` keeps the AUTOINCREMENT counter, so new consent event ids continue to increase. A table the service does not recognise makes both export and erase refuse to run, so unknown data is neither skipped nor deleted.
- **Logical, not physical, erasure:** erase deletes rows inside an SQLite transaction. This is logical database erasure. It does not prove that earlier bytes are overwritten in database pages, the free list, journal or WAL files, backups or the storage medium, and it is not cryptographic erasure. Secure deletion must be addressed by the SQLCipher and Android Keystore work (key destruction, WAL and journal handling, database-file lifecycle).
- **Not connected:** Settings still shows Export and Erase as unavailable, and no production code uses this service or opens the database. The database remains **unencrypted**; under Decision J no real participant data may be stored until SQLCipher-protected storage with Android Keystore-backed keys has passed review.

#### ADR-009 Implementation record (2026-11-10): Milestone K1, storage owner and persisted consent
This records how the first stage of production data integration implements Decisions G and J. It does not change any ADR-009 decision.
- **Scope:** `mobile/lib/data/local/sense_storage.dart` (new), `mobile/lib/presentation/widgets/sense_storage_scope.dart` (new), `mobile/lib/main.dart`, `mobile/lib/core/state/consent_preferences.dart`, and status wording in the Consent, Settings and Voice screens. Schema v2, migrations, repositories, consent append-only semantics, export/erase and all native security code are unchanged. Details: `docs/architecture/encrypted_local_storage.md`, section 15.
- **Storage owner:** `SenseStorage` is created by the app (no global or static connection), opens only through `EncryptedDatabaseProvider` (existing lifecycle owner, native lease, build policy and Keystore checks), binds `LocalDataStore`, ensures the active local profile, serialises open and close, and reports typed availability. There is no plaintext fallback.
- **Development namespace (decision of this milestone):** a separate development database is opened only in a debuggable debug build with the explicit `--dart-define=SENSE_DEV_STORAGE=1`. It is the existing debug-only test namespace `dev_storage`: its own database path, Keystore alias, lease and destroy; never production eligible; rejected by profile and release builds in Dart and natively. The app shows "DEVELOPMENT DATA — NOT FOR PARTICIPANTS" on every route while it is enabled. Development data is not participant data.
- **Participant storage stays closed:** debug and profile builds cannot open it (unchanged policy); release builds do not open it at startup, because participant data collection is not connected and physical-device validation is outstanding.
- **Consent persistence:** the shared `ConsentPreferences` stays in memory by default. Attached to ready storage it loads the `ConsentRepository` snapshot (authoritative over memory), appends one event per explicit change, and shows a change only after the write succeeded; failures change nothing and are reported. Onboarding records nothing by itself. In-memory values never authorize a write; the repository check inside each write transaction remains the authorization boundary, and revocation keeps earlier records.
- **Host tests:** a test-only fake platform with `sqflite_common_ffi` disposable files (never in `lib/`); on-device behaviour is covered by `integration_test/sense_storage_test.dart` with the development define. Emulator results are not hardware-backed validation.
