# SENSE
## Stress Estimation through Networked Signals and Emotions

*Personalized multimodal AI-based stress monitoring and early-warning research system. Formerly known by the working name "MindPulse".*

[![Project Phase](https://img.shields.io/badge/Phase-0%20signed%20off%20%7C%20UI%20prototype-blue.svg)](#project-lifecycle--phases)
[![Domain](https://img.shields.io/badge/Domain-Digital%20Wellbeing%20%7C%20Multimodal%20ML-purple.svg)](#project-identity)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](#primary-platforms)
[![License](https://img.shields.io/badge/Governance-Research%20Only-orange.svg)](#governance--ethics)

---

## 1. Project Identity

- **Project Name:** SENSE — Stress Estimation through Networked Signals and Emotions (former working name: MindPulse, still used in some internal identifiers)
- **Repository Name:** SENSE (`NotKrish019/SENSE`)
- **Descriptive Title:** Personalized Multimodal AI-Based Stress Monitoring and Early-Warning System
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
4. **Non-Clinical Boundary:** SENSE monitors lifestyle well-being patterns. It **does not diagnose, treat, or predict clinical psychiatric conditions (such as Major Depressive Disorder, Generalized Anxiety Disorder, or Bipolar Disorder), nor does it predict self-harm or suicide.**

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

1. **Phase 0 — Foundation & Scope Definition (SIGNED OFF 2026-11-06):** Literature review, formal mathematical formulation, privacy & ethics governance, technology stack trade-offs, architecture blueprints, and MVP boundary definition. Major app development and model training are prohibited during this phase.
2. **Phase 1 — Research & Technical Feasibility (work performed on synthetic data; gate not yet signed off):** Synthetic dataset generation, pipeline benchmarking, statistical baseline formulation, and verification of modality integration algorithms.
3. **Phase 2 — MVP Implementation (Flutter UI prototype in progress; gate not yet signed off):** Mobile core development (Flutter), local encrypted database (planned; not yet implemented), onboarding, structured check-ins (M1), sleep (M3), workload (M4), optional journal (M2), personal baseline engine, and supportive non-clinical insights.
4. **Phase 3 — Advanced AI Research:** Integration of privacy-preserving acoustic feature extraction (M5), physical activity analytics (M6), multimodal fusion, and uncertainty-aware explainable AI (XAI).
5. **Phase 4 — Empirical Validation:** Longitudinal user studies, within-person metric evaluations, usability assessments, and research publication preparation.

---

## 7. Running the Project

> See `docs/context.md` §7 for the current, verified implementation status.

### Mobile Application — Flutter (canonical, `mobile/`)
The Flutter app in `mobile/` is the **only actively developed mobile application** (ADR-001, accepted 2026-11-07). It is currently a **UI prototype using hard-coded sample data**: nothing is saved, encrypted or analysed yet.

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install), stable channel, and Google Chrome. Android Studio is **not** required for the browser preview.
- **Verified development version:** Flutter 3.47.9 / Dart 3.13.7 (2026-11-07). This is the version the current results were obtained with, not a hard requirement; however, the committed `pubspec.lock` was resolved with it and requires Flutter ≥ 3.44 / Dart ≥ 3.13.

```bash
cd mobile
flutter pub get
flutter devices                          # "Chrome (web)" should be listed
flutter run -d chrome --web-port 8765    # live preview at http://localhost:8765
```
While it runs: press `r` (hot reload) or `R` (hot restart) after code changes, `q` to stop. The developer-only Design Showcase shortcut appears in debug runs only (hidden in release builds).

> **Status (verified 2026-11-07):** web support (`mobile/web/`) is enabled; the app builds for web and launches in Chrome. Chrome preview is **not** equivalent to testing on a native Android or iOS device; `android/` and `ios/` platform folders do not exist yet.

Other useful commands (run inside `mobile/`):
```bash
flutter analyze                   # static analysis (0 errors at last check)
flutter test                      # 184 widget + unit tests
dart run test/run_all_tests.dart  # plain-Dart assertion runner (17 assertions)
flutter build web                 # production web build into mobile/build/web
```

### Frozen reference implementation — Expo / React Native (repository root)
`App.js`, `src/`, `package.json` and `app.json` contain an earlier Expo implementation. It is **FROZEN — REFERENCE ONLY**: retained for reference, not developed further, and it contains outdated, unsupported claims (e.g., encryption). Do not use it as the current product. If you need to inspect it: `npm ci && npx expo start`, then scan the QR code with Expo Go.

`mobile_preview.html` is a static HTML mock-up, not the application.

### Verification & Automated Tests
```bash
# Python research pipeline (24 tests — verified passing 2026-11-07)
python3 -m pytest -q

# Dart / Flutter (verified 2026-11-07: flutter test 184/184 passed; run_all_tests.dart 17/17 assertions passed)
cd mobile && flutter test && dart run test/run_all_tests.dart

# Rust backend (11 tests — not yet verified; .cargo/config.toml currently forces a Windows target)
cargo test --manifest-path backend-rust/Cargo.toml
```

