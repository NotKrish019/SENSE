# SENSE
## Stress Estimation through Networked Signals and Emotions

*Personalized multimodal AI-based stress monitoring and early-warning research system. Formerly known by the working name "MindPulse".*

[![Project Phase](https://img.shields.io/badge/Phase-2%20MVP%20%7C%20development%20storage%20only-blue.svg)](#project-lifecycle--phases)
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

> The table above is the research design. **Implemented in the app today:** manual entry for M1 (mood, motivation/energy, perceived stress), M3 (sleep duration, bedtime, wake time, rest quality) and M4 (mental demand, effort, deadlines in 48 hours), each 1 to 5 or a count, saved to encrypted local storage with per-input consent. M2 text is not stored; M5 and M6 are not implemented. See [`docs/submission/methodology.md`](docs/submission/methodology.md).

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
│   ├── architecture/              # Technical & System Design Specifications
│   │   ├── architecture_decisions.md
│   │   ├── encrypted_local_storage.md # SQLCipher, Keystore, storage owner, K1 to K4
│   │   └── system_flows.md
│   │
│   └── submission/                # Academic submission package (start here)
│       ├── project_overview.md
│       ├── system_architecture.md
│       ├── methodology.md
│       ├── testing_and_validation.md
│       ├── limitations_and_future_work.md
│       └── demonstration_guide.md
│
├── mobile/                        # Flutter application (the product)
│   ├── lib/core/state/            # Screen controllers, consent preferences
│   ├── lib/data/local/            # Repositories, narrow access interfaces, storage owner
│   ├── lib/data/local/encrypted/  # SQLCipher provider and Keystore channel
│   ├── lib/domain/                # Personal baseline engine and analysis
│   ├── lib/presentation/          # Screens and widgets
│   ├── android/                   # Native Android project (Keystore, lifecycle, build policy)
│   ├── test/                      # Host tests (unit, widget, persistence, static guards)
│   └── integration_test/          # On-device encrypted storage, restart and end-to-end tests
├── backend/, ml/, tests/          # Python research pipeline (synthetic data) and its tests
└── backend-rust/                  # Rust research/reference CLI (not part of the app)
```

**Academic submission:** start with [`docs/submission/project_overview.md`](docs/submission/project_overview.md). Validation evidence is in [`docs/submission/testing_and_validation.md`](docs/submission/testing_and_validation.md) and known limitations in [`docs/submission/limitations_and_future_work.md`](docs/submission/limitations_and_future_work.md).

---

## 6. Project Lifecycle & Phases

1. **Phase 0 — Foundation & Scope Definition (SIGNED OFF 2026-11-06):** Literature review, formal mathematical formulation, privacy & ethics governance, technology stack trade-offs, architecture blueprints, and MVP boundary definition. Major app development and model training are prohibited during this phase.
2. **Phase 1 — Research & Technical Feasibility (work performed on synthetic data; gate not yet signed off):** Synthetic dataset generation, pipeline benchmarking, statistical baseline formulation, and verification of modality integration algorithms.
3. **Phase 2 — MVP Implementation (in progress; gate not yet signed off):** Mobile core development (Flutter), onboarding, structured check-ins (M1), sleep (M3), workload (M4), optional journal (M2), personal baseline engine, and supportive non-clinical insights. **Implemented so far:** encrypted local storage (SQLCipher with an Android Keystore-wrapped key), persisted per-input consent, Check-in, Sleep and Workload persistence, and a consent-aware Insights screen with a within-person baseline. Saving currently works **only in the development namespace** of a debug build; participant storage is not enabled. Journal persistence is deliberately not implemented.
4. **Phase 3 — Advanced AI Research:** Integration of privacy-preserving acoustic feature extraction (M5), physical activity analytics (M6), multimodal fusion, and uncertainty-aware explainable AI (XAI).
5. **Phase 4 — Empirical Validation:** Longitudinal user studies, within-person metric evaluations, usability assessments, and research publication preparation.

---

## 7. Running the Project

> Current, verified implementation status (2026-11-11): [`docs/submission/testing_and_validation.md`](docs/submission/testing_and_validation.md). `docs/context.md` §7 predates the encrypted-storage and persistence milestones and has not been updated.

### Mobile Application — Flutter (canonical, `mobile/`)
The Flutter app in `mobile/` is the **only actively developed mobile application** (ADR-001, accepted 2026-11-07). On Android it saves Check-in, Sleep and Workload entries to an encrypted local database and shows a within-person baseline on the Insights screen, **but only in an isolated development namespace** of a debug build started with `--dart-define=SENSE_DEV_STORAGE=1` (see below). Without that define, and in profile and release builds, nothing is saved and the screens keep their honest "not saved" prototype behaviour. The Home dashboard and the Insight detail screen still show labelled sample content.

**Technology stack:** Flutter 3.47.9 / Dart 3.13 (UI, state and domain logic); `sqflite_sqlcipher` 3.4.1 with SQLCipher for Android 4.20.0 (encrypted SQLite); Kotlin and the Android Keystore (key wrapping, lifecycle lease, build policy); JDK 21 for Android builds; Python 3 (research pipeline, synthetic data only); Rust (research/reference CLI). No cloud service, account or network synchronisation.

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install), stable channel, and Google Chrome. Android Studio is **not** required for the browser preview.
- **Verified development version:** Flutter 3.47.9 / Dart 3.13.7 (2026-11-07). This is the version the current results were obtained with, not a hard requirement; however, the committed `pubspec.lock` was resolved with it and requires Flutter ≥ 3.44 / Dart ≥ 3.13.

```bash
cd mobile
flutter pub get
flutter devices                          # "Chrome (web)" should be listed
flutter run -d chrome --web-port 8765    # live preview at http://localhost:8765
```
While it runs: press `r` (hot reload) or `R` (hot restart) after code changes, `q` to stop. The developer-only Design Showcase shortcut appears in debug runs only (hidden in release builds).

> **Web preview:** the app builds for web and launches in Chrome, but the browser has no encrypted storage, so nothing is saved there. It is **not** equivalent to testing on Android. There is no iOS project.

#### Android with development storage (encrypted, development data only)
Requirements: the Android SDK with an emulator (verified on an Android 16 / API 36 arm64 emulator) and JDK 21 for Gradle.
```bash
export JAVA_HOME="$HOME/development/jdks/jdk-21.0.13+9/Contents/Home"   # adjust to your JDK 21
export PATH="$JAVA_HOME/bin:$PATH"
cd mobile
flutter run -d emulator-5554 --dart-define=SENSE_DEV_STORAGE=1
```
Every screen then shows the red banner **"DEVELOPMENT DATA — NOT FOR PARTICIPANTS"**. Turn on the inputs you want to use on the consent screen; nothing is saved for an input whose consent is off. A 3 to 5 minute walkthrough is in [`docs/submission/demonstration_guide.md`](docs/submission/demonstration_guide.md).

#### Security and privacy notes
- Data stays on the device in an SQLCipher database whose passphrase is wrapped by an Android Keystore key; opening fails closed (no plaintext fallback).
- Development storage is a separate namespace (own database file, Keystore alias and lifecycle lease), available only in debug builds with the explicit define, and is never production eligible. **The participant database is not opened by this version.**
- Consent is stored per input as append-only events and is checked inside each database write transaction.
- **Not yet verified:** hardware-backed (TEE or StrongBox) key protection on a physical device. All device testing so far used an emulator with software-backed keys. This version must not be used with participant or personal data. See [`docs/architecture/encrypted_local_storage.md`](docs/architecture/encrypted_local_storage.md), section 14.
- SENSE is non-clinical: it does not diagnose, assess health or predict anything.

Other useful commands (run inside `mobile/`):
```bash
flutter analyze                   # 0 errors; 5 known pre-existing issues (2 warnings, 3 infos), so it exits 1
flutter test                      # host suite: 1,004 tests (verified 2026-11-11)
dart run test/run_all_tests.dart  # plain-Dart assertion runner (17 assertions)
flutter build web                 # web build into mobile/build/web
flutter build apk --debug         # also --profile and --release (JDK 21)
```

On-device tests (emulator; see [`docs/submission/testing_and_validation.md`](docs/submission/testing_and_validation.md) for the full list, the two-phase restart procedure and the 2026-11-11 results):
```bash
(cd android && ./gradlew connectedDebugAndroidTest)                                       # 67 native tests
flutter test integration_test/encrypted_database_test.dart -d emulator-5554              # 21 tests
flutter test integration_test/sense_storage_test.dart -d emulator-5554 --dart-define=SENSE_DEV_STORAGE=1
# Two-phase restart tests (phase 1 with --no-uninstall, then adb shell am force-stop, then phase 2):
#   integration_test/{workload,check_in,sleep}_persistence_test.dart and insights_end_to_end_test.dart
```

### Frozen reference implementation — Expo / React Native (repository root)
`App.js`, `src/`, `package.json` and `app.json` contain an earlier Expo implementation. It is **FROZEN — REFERENCE ONLY**: retained for reference, not developed further, and it contains outdated, unsupported claims (e.g., encryption). Do not use it as the current product. If you need to inspect it: `npm ci && npx expo start`, then scan the QR code with Expo Go.

`mobile_preview.html` is a static HTML mock-up, not the application.

### Verification & Automated Tests
```bash
# Python research pipeline (24 tests — verified passing 2026-11-11)
python3 -m pytest -q

# Dart / Flutter (verified 2026-11-11: flutter test 1,004 passed; run_all_tests.dart 17/17 assertions passed)
# Accessibility is covered by automated semantics tests only: no real VoiceOver/TalkBack session.
cd mobile && flutter test && dart run test/run_all_tests.dart

# Rust backend (11 tests — not yet verified; .cargo/config.toml currently forces a Windows target)
cargo test --manifest-path backend-rust/Cargo.toml
```

