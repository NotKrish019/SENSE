# MindPulse (SENSE) — Canonical Project Context
## Canonical Single Source of Truth (SSOT)

> **Document Status:** Active Canonical Document  
> **Last Updated:** 2026-11-06  
> **Current Project Phase:** Phase 2 — Minimum Viable Product (MVP) Implementation (Active)  
> **Governing Repository:** `NotKrish019/SENSE`  
> **Default Branch:** `main`

---

## 1. Executive Summary & Identity

- **Project Name:** MindPulse (Internal Repository: SENSE)
- **Full Working Title:** Personalized Multimodal AI-Based Stress Monitoring and Early-Warning System
- **Domain:** Multimodal Machine Learning, Digital Well-being, Natural Language Processing, Acoustic Signal Processing, Time-Series Modeling, Human-Computer Interaction (HCI)
- **Primary Product Delivery:** Cross-platform native mobile application (Android & iOS) supported by reproducible Python/Jupyter research pipelines and an optional privacy-preserving processing backend.
- **Scientific Premise:** Subjective stress and well-being changes are idiosyncratic, non-linear, and manifested heterogeneously across cognitive, behavioral, verbal, and physiological dimensions. MindPulse posits that personalized baseline modeling over voluntarily supplied multimodal signals detects meaningful shifts in well-being significantly earlier and with greater precision than static population-level thresholds.

---

## 2. Problem Statement & Scope Boundaries

### 2.1 The Problem
Individuals undergo periodic stress due to academic, professional, financial, personal, and environmental factors. When acute stress transitions into chronic allostatic load, it manifests across multiple lifestyle facets: disrupted sleep patterns, reduced physical activity, altered lexical/linguistic tone, shifting vocal acoustics, elevated perceived workload, and impaired subjective mood. Individuals frequently experience these shifts in isolation and fail to recognize subtle, compounding degradations in well-being until significant burnout or impairment occurs.

### 2.2 Scope Boundaries & Non-Goals

| What MindPulse WILL Do | What MindPulse WILL NOT Do |
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

- **Mobile Application Framework:** **Flutter (Dart)** selected over React Native and Kotlin Multiplatform for the following verified criteria:
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
  - Storage: AES-256-GCM encryption at rest for local SQLite database.
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
[PHASE 1] Research & Technical Feasibility (COMPLETE & BENCHMARKED)
  │  ├── Synthetic Multi-Participant Longitudinal Dataset Generation (N=100, T=60d)
  │  ├── Baseline Engine Formulation & Change-Point Algorithm Benchmarking (EXP-1.1, EXP-1.3)
  │  └── Missing-Modality Late Fusion Verification (EXP-1.2)
  ▼
[PHASE 2] Minimum Viable Product (MVP) Implementation (ACTIVE)
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

- **Phase 0 Status:** COMPLETE & SIGNED OFF.
- **Phase 1 Status:** COMPLETE & BENCHMARKED (Synthetic cohort $N=100$, CUSUM 97.6% spike suppression verified, missing modality neutrality verified).
- **Phase 2 Status:** ACTIVE (Rust backend engine `backend-rust` fully implemented and verified with 11/11 tests, Python backend verified with 24/24 tests, Flutter/Dart client verified with 17/17 tests; total 52 automated tests passing).
- **Git Status:** Clean local working directory on branch `main` cloned from `https://github.com/NotKrish019/SENSE.git`. Local changes: YES (uncommitted), Remote push: NO (Strict Section 19 governance maintained).
- **Key Open Decisions (Awaiting Phase 0 Sign-Off):**
  1. *Target Cohort Profile for Initial Study:* Will the Phase 1/4 empirical validation recruit university students or corporate knowledge workers as the primary demographic? (Recommendation: University students and young working professionals aged 18–35).
  2. *Voice Feature Processing Location:* Full on-device extraction via embedded C++ openSMILE / ONNX vs. local batch transfer to a self-hosted privacy-preserving edge container? (Recommendation: On-device extraction of eGeMAPS acoustic features to guarantee raw voice audio never leaves the phone).
  3. *Ground Truth Anchor Instrument:* Choice of secondary longitudinal reference scale alongside daily EMA: PSS-10 administered bi-weekly vs. weekly PSS-4. (Recommendation: Weekly PSS-4 to minimize survey fatigue).

