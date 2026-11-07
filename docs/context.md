# SENSE — Canonical Project Context
## Canonical Single Source of Truth (SSOT)

> **Document Status:** Active Canonical Document  
> **Last Updated:** 2026-11-07  
> **Current Project Phase:** Phase 0 signed off (2026-11-06). Phase 1 research work and Phase 2 mobile UI work are in progress; **no Phase 1 or Phase 2 gate sign-off document exists yet** (see §7).  
> **Governing Repository:** `NotKrish019/SENSE`  
> **Default Branch:** `main`

---

## 1. Executive Summary & Identity

- **Project Name:** **SENSE — Stress Estimation through Networked Signals and Emotions** (official since 2026-11-07). *Former working name: MindPulse — retained in historical documents and internal identifiers such as the `mindpulse` Dart package, `mindpulse_core` Rust crate and `MindPulsePipeline` Python class, which are intentionally not renamed.*
- **Descriptive Title:** Personalized Multimodal AI-Based Stress Monitoring and Early-Warning System
- **Domain:** Multimodal Machine Learning, Digital Well-being, Natural Language Processing, Acoustic Signal Processing, Time-Series Modeling, Human-Computer Interaction (HCI)
- **Primary Product Delivery:** Cross-platform native mobile application (Android & iOS) supported by reproducible Python/Jupyter research pipelines and an optional privacy-preserving processing backend.
- **Scientific Premise:** Subjective stress and well-being changes are idiosyncratic, non-linear, and manifested heterogeneously across cognitive, behavioral, verbal, and physiological dimensions. SENSE posits that personalized baseline modeling over voluntarily supplied multimodal signals detects meaningful shifts in well-being significantly earlier and with greater precision than static population-level thresholds.

---

## 2. Problem Statement & Scope Boundaries

### 2.1 The Problem
Individuals undergo periodic stress due to academic, professional, financial, personal, and environmental factors. When acute stress transitions into chronic allostatic load, it manifests across multiple lifestyle facets: disrupted sleep patterns, reduced physical activity, altered lexical/linguistic tone, shifting vocal acoustics, elevated perceived workload, and impaired subjective mood. Individuals frequently experience these shifts in isolation and fail to recognize subtle, compounding degradations in well-being until significant burnout or impairment occurs.

### 2.2 Scope Boundaries & Non-Goals

| What SENSE WILL Do | What SENSE WILL NOT Do |
| :--- | :--- |
| Capture voluntarily provided daily check-ins, sleep, workload, text journals, acoustic samples, and activity. | **WILL NOT diagnose** depression, generalized anxiety disorder, PTSD, or any clinical psychiatric condition. |
| Establish individualized, dynamic historical baselines using time-series and anomaly-detection techniques. | **WILL NOT predict** suicide, crisis events, or self-harm (a dedicated crisis resource pathway is provided independently of ML). |
| Detect gradual shifts and longitudinal trends against an individual's personal reference distribution. | **WILL NOT prescribe** medical interventions, pharmaceuticals, or formal cognitive behavioral therapy. |
| Provide transparent, evidence-grounded explanations highlighting which features contributed to detected shifts. | **WILL NOT replace** licensed mental health professionals, physicians, or counselors. |
| Deliver supportive, evidence-based non-clinical lifestyle observations and psychoeducational self-care habits. | **WILL NOT perform stealth surveillance**, background eavesdropping, ambient audio recording, or unauthorized location tracking. |
| Function fully with missing modalities; treat missing data neutrally. | **WILL NOT expose** raw data, summaries, or inferences to employers, universities, insurers, or third parties. |

---

## 3. Core Research Questions & Working Hypotheses

- **RQ1 (Personalized Baselines):** Does within-person baseline modeling achieve statistically significant reductions in false-positive stress alerts compared to fixed population-level thresholds?
  - *Hypothesis 1 (H1):* An adaptive personal baseline (e.g., dynamic $z$-score, Exponentially Weighted Moving Average, or isolation forest calibrated per individual) reduces false alerts by $>30\%$ compared to static population cutoffs.
- **RQ2 (Multimodal Value):** Does multimodal feature integration improve stress-shift detection accuracy and timeliness compared to structured self-report check-ins alone?
  - *Hypothesis 2 (H2):* Combining behavioral, acoustic, and textual signals with self-reports yields measurable improvements in detection F1-score and receiver operating characteristic area over single-modality tracking.
- **RQ3 (Modality Contribution):** What is the relative information gain and incremental predictive power of each modality (M1–M6) in detecting longitudinal stress deviations?
  - *Hypothesis 3 (H3):* Sleep consistency (M3) and subjective workload (M4) contribute the highest incremental gain to structured check-ins (M1), while text (M2) and voice (M5) provide contextual nuance.
- **RQ4 (Temporal Dynamics):** Can temporal time-series modeling distinguish transient, adaptive acute stress spikes (e.g., pre-exam/deadline) from sustained, maladaptive chronic shifts?
  - *Hypothesis 4 (H4):* Modeling autocorrelation decay and change-point persistence differentiates single-day transient spikes from persistent shifts spanning $>5$ days.
- **RQ5 (Explainability & Agency):** Do evidence-linked, factor-attributed explanations increase user comprehension and perceived agency compared to black-box stress scores?
  - *Hypothesis 5 (H5):* Users presented with feature-grounded explanations report higher trust, lower anxiety, and more actionable self-reflection than users shown raw numerical stress scores.
- **RQ6 (Missing Modality Robustness):** How does asynchronous, sporadic, and incomplete modality engagement degrade system estimation, and which fusion architectures maintain graceful degradation?
  - *Hypothesis 6 (H6):* Late decision-level fusion with dynamic reliability weighting preserves predictive stability better than naive early feature concatenation when modalities are missing at random.

---

## 4. Input Modality Specifications (M1 to M6)

```text
                               ┌────────────────────────┐
                               │  M1: Check-ins (Active)│
                               └───────────┬────────────┘
                                           │
  ┌────────────────────────┐               │               ┌────────────────────────┐
  │ M2: Text Journal (Opt) ├───────────────┼───────────────┤  M3: Sleep (Log/Health)│
  └────────────────────────┘               │               └────────────────────────┘
                                   MINDPULSE FUSION
  ┌────────────────────────┐            ENGINE             ┌────────────────────────┐
  │ M4: Workload (Log/Opt) ├───────────────┼───────────────┤  M5: Voice Audio (Opt) │
  └────────────────────────┘               │               └────────────────────────┘
                                           │
                               ┌───────────┴────────────┐
                               │M6: Physical Act (Opt)  │
                               └────────────────────────┘
```

1. **M1 — Structured Check-ins:** Perceived stress scale (PSS-4 adapted for daily EMA), circumplex mood grid (valence, arousal 1–5), energy level, motivation. Frequency: 1–2 times daily, taking $<30$ seconds.
2. **M2 — Text Journal:** Voluntary free-text reflection. Analysis includes lexicon-based affect valence, transformer-derived sentiment polarity, semantic theme extraction, and cognitive distortion markers. Processing must support on-device or privacy-hardened local representations.
3. **M3 — Sleep Metrics:** Total Sleep Time (TST in hours), Sleep Regularity Index (SRI), Sleep Onset Latency (SOL), and subjective sleep quality rating (1–5). Sourced from manual morning prompts or synced with explicit permission via Android Health Connect / iOS HealthKit.
4. **M4 — Workload:** Daily subjective workload rating (NASA-TLX shortened subscale: Mental Demand, Effort), estimated task volume, and upcoming deadline proximity count.
5. **M5 — Voice Samples:** Voluntary 20–30 second read or semi-structured voice prompt (e.g., standard phonetic paragraph or open daily check-in). Extracted features focus on acoustic prosody via eGeMAPS: Fundamental frequency mean/variance ($F_0$), jitter, shimmer, harmonics-to-noise ratio (HNR), speaking rate, and pause-to-speech ratio. Raw audio is immediately discarded after on-device feature extraction or securely encrypted.
6. **M6 — Physical Activity:** Daily step count, active metabolic minutes, and sedentary bout duration. Sourced via authorized OS health integrations. No real-time GPS or continuous background location tracking.

---

## 5. Architectural & Technical Decisions Summary

- **Mobile Application Framework — ACCEPTED (ADR-001, amended 2026-11-07):** **Flutter (Dart), located in `mobile/`, is the canonical and only actively developed mobile application** (joint team decision: Krish / `NotKrish019` and collaborating developer).
  - **Expo / React Native implementation** (repository root: `App.js`, `src/`, `package.json`, `app.json`): **FROZEN — REFERENCE IMPLEMENTATION.** Retained, not deleted; no independent development; modified only with explicit authorization. It contains unsupported claims (e.g., "AES-256 On-Device Only", "Stress Index 58 / 100") and must not be presented as the current product.
  - `mobile_preview.html` (root): static HTML mock-up; not the application.
  - The capabilities below are the original *selection rationale*; several listed plugins (`record`, `health`, `sqflite_sqlcipher`, `tflite_flutter`, `onnxruntime`) are **not yet dependencies**. Current `mobile/pubspec.yaml` dependencies: `sqflite`, `path`, `uuid`, `intl`, `crypto`.
  - Rationale (as originally recorded):
  - High cross-platform rendering parity on iOS and Android.
  - Mature low-level audio recording and signal buffer libraries (`record`, `audio_waveforms`, `flutter_sound`).
  - First-party and high-quality plugins for Android Health Connect and Apple HealthKit (`health`).
  - Strong local secure storage ecosystems: SQLCipher via `sqflite_sqlcipher` with hardware-backed key derivation (Android KeyStore / iOS Keychain).
  - Production-ready on-device ML runtimes via `tflite_flutter` and `onnxruntime`.
- **Backend & ML Research Stack:**
  - **Shared Core & Backend Engine (Rust):** `backend-rust/` crate (`mindpulse_core` and `mindpulse-cli`) compiled via `x86_64-pc-windows-gnullvm` and C-ABI FFI. Houses memory-safe SQLite manager (`rusqlite bundled`), `SignalPreprocessor` (affective lexicon, pronoun density, zero-latency crisis interceptor), `PersonalBaselineEngine` (MAD, causal rolling window, EWMA, CUSUM), and `DynamicLateFusionEngine` (prior weights, dynamic denominator normalization, epistemic uncertainty).
  - **Exploratory Research & Benchmarking (Python):** Python 3.11+ / PyTorch / NumPy / SciPy / pandas / scikit-learn for synthetic cohort generation, exploratory modeling, and statistical validation.
  - **Mobile Client Engine (Dart/Flutter):** On-device state, baseline algorithms, and UI presentation mirroring Rust core.
- **Privacy & Security Standard:**
  - Compliance targets: Digital Personal Data Protection Act (DPDP Act 2023, India) and ICMR Ethical Guidelines for Biomedical and Health Research (2017).
  - Storage (**target, not yet implemented**): AES-256-GCM encryption at rest for local SQLite database. The current Flutter data layer uses plain `sqflite` with **no encryption**, and no screen currently writes to the database.
  - Identification: Strict zero-knowledge pseudonymous Subject Identifiers (UUIDv4). No personally identifiable information (PII) linked to ML feature vectors.
  - Explicit Modality Permissions: Granular, independently revocable consent switches per modality in user settings.

---

## 6. Project Phase Gates & Roadmap

```text
[PHASE 0] Foundation & Scope Definition (COMPLETE & SIGNED OFF)
  │  ├── Problem & Population Definition
  │  ├── Scientific Literature Review & Benchmark Audit
  │  ├── Architectural Blueprint & Modality Feasibility
  │  └── Privacy, Ethics, and Safety Protocols
  ▼
[PHASE 1] Research & Technical Feasibility (WORK PERFORMED — GATE NOT SIGNED OFF)
  │  ├── Synthetic Multi-Participant Longitudinal Dataset Generation (N=100, T=60d)
  │  ├── Baseline Engine Formulation & Change-Point Algorithm Benchmarking (EXP-1.1, EXP-1.3)
  │  └── Missing-Modality Late Fusion Verification (EXP-1.2)
  ▼
[PHASE 2] Minimum Viable Product (MVP) Implementation (UI PROTOTYPE IN PROGRESS — GATE NOT SIGNED OFF)
  │  ├── Flutter Mobile Client Onboarding & Consent Architecture
  │  ├── Modules M1, M3, M4, and M2 Integration
  │  └── Local Encrypted Storage & Rule-Based / Statistical Trend Dashboard
  ▼
[PHASE 3] Advanced AI & Multimodal Fusion
  │  ├── On-device Acoustic (M5) & Health Connect Activity (M6) Integration
  │  ├── Multimodal Late-Fusion Model & Uncertainty Estimation
  │  └── Feature Attribution & Explainable AI Narrative Engine
  ▼
[PHASE 4] Empirical Research Validation
     ├── Controlled Cohort Study (Consenting Adults, Institutional Review)
     ├── Model Performance vs. Population Baselines Evaluation
     └── Research Paper Preparation & Formal Reporting
```

---

## 7. Current Project Status & Actionable Open Decisions

*Status reconciled 2026-11-07 against the repository and a fresh environment audit. Earlier text claimed "Phase 1 COMPLETE & BENCHMARKED", "Phase 2 ACTIVE" and "52 automated tests passing"; those claims were not backed by gate documents or reproducible on the current development machine and have been corrected below.*

- **Phase 0 Status:** COMPLETE & SIGNED OFF (`docs/phase-0/phase_0_signoff.md`, approved by `NotKrish019`, 2026-11-06, authorizing Phase 1).
- **Phase 1 Status:** Research work performed (synthetic cohort generator, baseline engine, late fusion, benchmarks in `ml/`; synthetic cohort `data/synthetic/cohort_60d_n100.csv`). **No Phase 1 gate sign-off document exists.** Benchmark figures quoted elsewhere (e.g., CUSUM spike suppression) are results on *synthetic* data only.
- **Phase 2 Status:** Flutter UI prototype in progress. **No Phase 2 gate sign-off document exists.**
- **Verified test results (2026-11-07, macOS arm64):**
  - Python (`python3 -m pytest -q`): **24/24 passed.**
  - Toolchain: **Flutter 3.47.9 (stable) / Dart 3.13.7**, installed at `~/development/flutter` on the development Mac (2026-11-07).
  - `flutter test` (7 test files): **184/184 passed** (2026-11-07): 9 domain/safety unit tests (baseline, fusion, crisis service) + 175 UI widget tests — consent flow (9), navigation and large text (33), input-screen layout/accessibility (113), contrast/semantics/honest-message regression guards (20). `dart run test/run_all_tests.dart`: **17/17 assertions passed** (domain/safety logic only; it overlaps the 9 unit tests — see note below).
  - `flutter analyze`: **0 errors** (4 warnings, 3 infos, all pre-existing) after fixing compile errors on 2026-11-07; previously 111 errors.
  - `flutter build web`: **succeeds.** First launched in Chrome on 2026-11-07 (headless; that early check ran at ~500 px, not a true phone width — later checks used exact 320/360/412 px device emulation): splash → onboarding → dashboard → all six modality screens, Settings and Insights render and navigate back correctly with no runtime exceptions; journal text input and the crisis-support banner work. **This is browser verification only, not native Android/iOS testing.**
  - *Test-duplication note:* `test/baseline_engine_test.dart`, `crisis_service_test.dart` and `late_fusion_engine_test.dart` (9 tests, `package:test`) overlap `test/run_all_tests.dart` (17 plain-Dart assertions). Both are kept: `flutter test` runs only the former, and the latter is the README's documented runner. Consolidating them is safe only after confirming every assertion is represented in the `package:test` files.
  - Rust (`backend-rust/`, 11 tests claimed): **not executed** — Rust toolchain not installed; `backend-rust/.cargo/config.toml` forces a Windows target (`x86_64-pc-windows-gnullvm`) that must be revisited for macOS/Linux builds.
- **Flutter application status (`mobile/`):**
  - 15 screen files (incl. `main_shell.dart` and the developer-only `design_showcase_screen.dart`) and 13 widget files exist (the initial commit had 14 and 12). All data shown is hard-coded sample data; **no screen reads from or writes to the database** (`DatabaseHelper` is not referenced by any screen). "Save" actions state that nothing was saved; "Export" and "Erase" open a "not available yet" explanation; no success is simulated (guarded by regression tests).
  - Encryption is **not implemented** (plain `sqflite`). **Safety & data-integrity correction completed 2026-11-07 (Task 1):** false encryption, storage, export/erase, on-device NLP, voice-processing, baseline-calibration, numeric-attribution and causal claims were removed from the Flutter UI. All prototype wording is centralised in `mobile/lib/core/constants/prototype_copy.dart`; hard-coded illustrative values carry a shared "Sample data" badge (`SenseProvenanceBadge.sampleData()`) and screen-level banner (`SenseSampleDataBanner`). "Save" actions now state that nothing was saved; export/erase show "not available yet"; the voice screen states that no audio is recorded. Crisis-phrase detection logic was not changed and was re-verified in Chrome.
  - **Consent flow integrated 2026-11-07 (Task 2):** Splash → Onboarding → Consent → Dashboard (both "Skip" and "Get Started" lead to consent; Back from consent returns to the last onboarding slide; Continue makes the dashboard the only route). Settings → "Review data and consent preferences" opens the same screen. Six optional inputs (M1–M6), **all off by default**, independently switchable; continuing with none enabled is allowed. Choices live only in memory (`mobile/lib/core/state/consent_preferences.dart`) — not saved, lost on refresh, no OS permissions requested, no data collection started; the screen states it is a demonstration and not a substitute for an approved research-participant consent process. Covered by `mobile/test/consent_flow_test.dart` (9 widget tests).
  - The `CrisisSafetyBanner`, `CalibrationProgressCard` and `InsightNarrativeCard` widgets remain **not reachable from navigation**. Their references to removed legacy `AppTheme` colour names were remapped to `SenseColors` tokens on 2026-11-07 so the project analyses cleanly.
  - **Navigation, Profile & large text (Task 3, 2026-11-07):** a `MainShell` (`mobile/lib/presentation/screens/main_shell.dart`) owns one bottom bar — Home · Insights · (+ check-in) · Profile — with tabs kept alive in an `IndexedStack` (one dashboard instance; detail screens pushed on top; system/browser Back on a non-Home tab returns to Home). Previously, choosing a non-Home tab replaced the dashboard with a screen that had no navigation bar, stranding the user. **Tools tab removed** (its only function was opening the developer Design System Showcase, still reachable from the dashboard header; the Home input grid already serves as the input hub). Settings is now the Profile tab ("Profile & settings": honest "Profile setup is not available yet", Support, Data & consent, Privacy & data management, About). Layouts were made text-scale-robust (flexible rows, content-height tile grid, minimum-not-fixed button height, stacking Insights charts) and verified with no overflow at 320/360/412 px × 1.0/1.3/1.5/2.0 text scale in widget tests (no overflow tolerance) and in Chrome via browser font size. Nav labels follow text size up to 1.3x (as Material's NavigationBar does).
  - **Accessibility polish (Task 5, 2026-11-07):** accessible text tokens (`textAccent` = Ocean Blue for small links/active labels; `blue700` for the button gradient; `textMuted` darkened to `#587187`) — Electric Blue kept for non-text use; button roles for the hero card and tappable cards; selected state for chips and the Insights period selector; switch semantics and 3:1 states for `SenseToggleSwitch`; the non-functional dashboard filter chips removed; weekday chart labels switch to single letters (full names announced) when three letters do not fit; the developer-only Design Showcase shortcut is compiled out of release builds. *Not validated with a real screen reader (VoiceOver/TalkBack).*
  - **Large-text pass on input screens (Task 4, 2026-11-07):** Journal, Sleep, Workload, Activity, Voice, Insight detail (plus Check-in, found clipping at 320 px) fixed for 320/360/412 px x 1.0/1.3/1.5/2.0 text: content-driven heights (journal writing area, sleep history), shared `SenseSliderLabels` (stacks and wraps whole labels), stacking time cards, width-sized mood grid. Accessible labels added to the shared app-bar Back button, workload stepper, sleep stars and time pickers, mood options, the voice demo button (states no audio is recorded) and the always-off Health Connect switch. Verified by `mobile/test/input_screens_layout_test.dart` (113 tests, no overflow tolerance) and in Chrome at a true 320 px viewport with 2x root font size.
  - Bottom navigation (historical note): before Task 3 the non-Home tabs replaced the dashboard without a navigation bar; the splash/header logo uses a three-wave icon that conflicts with `design.md` ("do not reuse … wave emblem").
  - Poppins is specified in `SenseTypography` but no font files are bundled.
  - `mobile/web/` platform folder added 2026-11-07 (generated in a scratch project and copied in; title/manifest set to SENSE). No `android/` or `ios/` folders exist yet. `pubspec.lock` now exists; `test` added as a dev-only dependency so the existing `*_test.dart` files can run.
- **Expo / React Native (repository root):** FROZEN — REFERENCE IMPLEMENTATION (ADR-001 amendment). Its Android JS bundle compiled on 2026-11-07; not developed further.
- **Preview strategy:**
  1. *Current (working since 2026-11-07):* Flutter Web in Chrome — `cd mobile && flutter run -d chrome`. **Browser preview is not native Android testing.**
  2. *Future native Android:* Android SDK command-line tools + JDK 17 (Android Studio optional), an `android/` platform folder, then an emulator or Android 11+ wireless debugging (`adb pair` / `adb connect`) — no USB cable required.
- **Outstanding approvals:**
  1. *(Done 2026-11-07, developer-approved)* Flutter SDK installation and `mobile/web/` platform folder.
  2. Native Android toolchain (deferred by developer; Android Studio not to be installed yet).
  3. Phase 1 and Phase 2 gate sign-offs (project lead).
  4. Any future decision to delete the frozen Expo implementation.
  5. Persistence/encryption architecture for the MVP (SQLCipher vs. alternatives) before any real data is stored.
- **Key Open Research Decisions** (carried over; originally listed under Phase 0):
  1. *Target Cohort Profile for Initial Study:* Will the Phase 1/4 empirical validation recruit university students or corporate knowledge workers as the primary demographic? (Recommendation: University students and young working professionals aged 18–35).
  2. *Voice Feature Processing Location:* Full on-device extraction via embedded C++ openSMILE / ONNX vs. local batch transfer to a self-hosted privacy-preserving edge container? (Recommendation: On-device extraction of eGeMAPS acoustic features to guarantee raw voice audio never leaves the phone).
  3. *Ground Truth Anchor Instrument:* Choice of secondary longitudinal reference scale alongside daily EMA: PSS-10 administered bi-weekly vs. weekly PSS-4. (Recommendation: Weekly PSS-4 to minimize survey fatigue).

