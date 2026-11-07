# MindPulse (SENSE)
## Personalized Multimodal AI-Based Stress Monitoring and Early-Warning System

[![Project Phase](https://img.shields.io/badge/Phase-0%3A%20Foundation%20%26%20Scope-blue.svg)](#project-lifecycle--phases)
[![Domain](https://img.shields.io/badge/Domain-Digital%20Wellbeing%20%7C%20Multimodal%20ML-purple.svg)](#project-identity)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](#primary-platforms)
[![License](https://img.shields.io/badge/Governance-Research%20Only-orange.svg)](#governance--ethics)

---

## 1. Project Identity

- **Project Name:** MindPulse
- **Repository Name:** SENSE (`NotKrish019/SENSE`)
- **Working Full Title:** Personalized Multimodal AI-Based Stress Monitoring and Early-Warning System
- **Core Category:** Artificial Intelligence, Multimodal Machine Learning, Digital Well-being, Natural Language Processing, Time-Series Analysis, Explainable AI (XAI), Mobile Computing
- **Project Ambition:** Scientifically grounded, research-driven digital well-being platform yielding an experimentally evaluated multimodal ML framework and a production-grade cross-platform mobile application.

---

## 2. Core Problem & Research Mission

Individuals encounter stress stemming from diverse personal, academic, vocational, and environmental pressures. Chronic or escalating stress frequently manifests across fragmented life indicators—mood fluctuations, disrupted sleep architecture, workload escalation, shifting linguistic sentiment, altered acoustic prosody, and reduced physical activity. Because individuals experience and record these dimensions in silos, gradual deteriorations in well-being frequently escape self-detection until severe burn-out occurs.

### Core Problem Statement
> *How can a personalized multimodal AI system integrate voluntarily provided emotional, behavioral, and lifestyle indicators to identify changes in an individual's stress-related well-being patterns over time and provide understandable, evidence-supported insights?*

### Foundational Research Principles
1. **Within-Person Baseline Modeling:** Stress is physiologically and psychologically idiosyncratic. Population-wide fixed thresholds yield unacceptable false-alarm rates; detection must be calibrated against an individual's personal historical baseline.
2. **Longitudinal Temporal Analysis:** Transient single-day stress spikes (e.g., prior to an exam) differ fundamentally from sustained multi-week deviations. Time-series analysis must capture baseline drift, trend persistence, and recovery dynamics.
3. **Multimodal Information Fusion:** Multimodal inputs must provide quantifiable incremental value over structured self-reports alone. If a modality does not improve estimation, it must be pruned.
4. **Non-Clinical Boundary:** MindPulse monitors lifestyle well-being patterns. It **does not diagnose, treat, or predict clinical psychiatric conditions (such as Major Depressive Disorder, Generalized Anxiety Disorder, or Bipolar Disorder), nor does it predict self-harm or suicide.**

---

## 3. The Six Input Modalities

All modalities are voluntary, opt-in, and independently consent-governed:

| Modality | Description | Core Indicators | Collection Mechanism |
| :--- | :--- | :--- | :--- |
| **M1: Structured Check-ins** | Validated brief rating scales & Ecological Momentary Assessment (EMA) | Perceived stress (PSS-4/single-item), valence, arousal, energy, motivation | Active in-app 15-second check-in |
| **M2: Text Journal** | Voluntary reflective writing | Sentiment polarity, emotional affect, cognitive load markers, thematic shifts | Active in-app text editor (processed with privacy safeguards) |
| **M3: Sleep Tracking** | Nocturnal rest metrics | Total sleep time (TST), sleep onset latency, sleep consistency index, wake-after-sleep-onset (WASO) | Manual daily log or authorized Health Connect / Apple Health sync |
| **M4: Workload Tracking** | Academic & vocational demand metrics | Task volume, deadline proximity, subjective cognitive load, work hours | Structured daily slider / task counter |
| **M5: Voice Analysis** | Acoustic prosody & speech dynamics | Pitch variability ($F_0$ SD), speaking rate, jitter, shimmer, pause duration ratio | Voluntary 30-second audio prompt (eGeMAPS acoustic feature extraction) |
| **M6: Physical Activity** | Movement & sedentary patterns | Daily step volume, active minutes, circadian activity entropy | Manual logging or authorized platform fitness API |

---

## 4. Project Governance & Strict Git Policy

In accordance with Section 19 of the Project Constitution:
- **Default Development Mode:** Local Development Only. Remote Writes are strictly prohibited without prior explicit human approval.
- **Git Push Policy:** No automated `git push` commands.
- **Commit Policy:** No automated `git commit` commands without explicit user authorization.
- **Accountability:** Every development session concludes with a comprehensive in-chat execution report detailing files modified, tests executed, independent testing instructions, and Git status.

---

## 5. Repository Documentation Structure

```text
SENSE/
├── README.md                      # Project landing page & quick orientation
├── docs/
│   ├── context.md                 # Canonical Single Source of Truth
│   ├── decisions.md               # Architecture Decision Records (ADRs)
│   ├── assumptions.md             # Assumption tracking register
│   ├── risk_register.md           # Multi-category risk matrix
│   │
│   ├── phase-0/                   # Foundation & Scope Definition Deliverables
│   │   ├── project_charter.md
│   │   ├── problem_statement.md
│   │   ├── scope_and_non_goals.md
│   │   ├── research_questions.md
│   │   ├── literature_review.md
│   │   ├── competitor_analysis.md
│   │   ├── user_research.md
│   │   ├── dataset_strategy.md
│   │   ├── data_dictionary.md
│   │   ├── research_methodology.md
│   │   ├── privacy_and_ethics.md
│   │   ├── safety_requirements.md
│   │   ├── technical_feasibility.md
│   │   ├── system_architecture.md
│   │   ├── mobile_app_requirements.md
│   │   ├── mvp_requirements.md
│   │   └── phase_0_signoff.md
│   │
│   ├── research/                  # Scientific Foundations & Evidence Base
│   │   ├── papers.md              # Annotated bibliography of verified papers
│   │   ├── datasets.md            # Benchmark dataset evaluations
│   │   └── experiments.md         # Empirical experiment designs & protocols
│   │
│   └── architecture/              # Technical & System Design Specifications
│       ├── architecture_decisions.md
│       └── system_flows.md
```

---

## 6. Project Lifecycle & Phases

1. **Phase 0 — Foundation & Scope Definition (CURRENT):** Literature review, formal mathematical formulation, privacy & ethics governance, technology stack trade-offs, architecture blueprints, and MVP boundary definition. Major app development and model training are prohibited during this phase.
2. **Phase 1 — Research & Technical Feasibility:** Synthetic dataset generation, pipeline benchmarking, statistical baseline formulation, and verification of modality integration algorithms.
3. **Phase 2 — MVP Implementation:** Mobile core development (Flutter), local encrypted database, onboarding, structured check-ins (M1), sleep (M3), workload (M4), optional journal (M2), personal baseline engine, and supportive non-clinical insights.
4. **Phase 3 — Advanced AI Research:** Integration of privacy-preserving acoustic feature extraction (M5), physical activity analytics (M6), multimodal fusion, and uncertainty-aware explainable AI (XAI).
5. **Phase 4 — Empirical Validation:** Longitudinal user studies, within-person metric evaluations, usability assessments, and research publication preparation.

---

## 7. Running the Project

### Mobile Application (Expo / React Native)
To test and interact with the SENSE mobile app on your physical mobile phone via Expo Go:
```bash
# Start the Expo Metro Bundler
npx expo start
```
- **Android:** Scan the terminal QR code with the **Expo Go** app.
- **iOS:** Scan the terminal QR code using the default **Camera** app.

### Interactive Browser Prototype
For immediate desktop preview without a mobile device:
- Open `mobile_preview.html` in any modern web browser.

### Verification & Automated Tests
Execute the comprehensive test suites across the stack (52 automated tests):
```bash
# Dart Mobile Test Suite (17 tests)
dart run mobile/test/run_all_tests.dart

# Python Research Pipeline Test Suite (24 tests)
python -m pytest -q

# Rust Backend Engine Test Suite (11 tests)
cargo test --manifest-path backend-rust/Cargo.toml
```

