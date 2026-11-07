# MindPulse (SENSE) — Project Charter
## Phase 0 Deliverable | Foundation & Scope Definition

---

## 1. Project Vision & Mission

### 1.1 Vision
To pioneer a scientifically validated, privacy-first digital well-being architecture that empowers individuals to understand, contextualize, and navigate longitudinal shifts in their personal stress and lifestyle equilibrium.

### 1.2 Mission
To construct an open, reproducible, multimodal artificial intelligence framework that combines voluntarily provided subjective ratings, sleep metrics, cognitive workload indicators, reflective text journals, acoustic prosody, and physical activity into an explainable, personalized early-warning system—operating strictly within an ethical, non-clinical boundary.

---

## 2. Project Governance & Stakeholders

| Role | Responsibility | Primary Competencies |
| :--- | :--- | :--- |
| **Principal Research Architect** | Directs scientific methodology, experimental design, and validation integrity. | Psychoinformatics, Time-Series Modeling, Multimodal ML |
| **Mobile Systems Architect** | Leads cross-platform mobile implementation, audio buffer streaming, and local storage. | Flutter/Dart, iOS/Android Audio APIs, SQLCipher |
| **ML & Signal Processing Engineer** | Implements acoustic feature extraction, NLP pipelines, and baseline anomaly detection. | PyTorch, openSMILE, ONNX Runtime, SciPy |
| **Data Governance & Privacy Officer** | Oversees regulatory compliance (DPDP Act 2023, ICMR guidelines), cryptographic security, and ethics. | Information Security, Health Data Privacy, Ethics |
| **Clinical & Safety Advisor** | Validates psychological instrumentation (PSS, EMA) and crisis safety pathways. | Clinical Psychology, Behavioral Science |

---

## 3. Project Objectives & Success Criteria

### 3.1 Primary Technical Objectives
1. **Personalized Baseline Calibration:** Develop algorithms capable of estimating a robust individual baseline within 14 days of sparse user interaction.
2. **Longitudinal Change Detection:** Achieve statistically significant detection of multi-day stress deviations against baseline with an F1-score $\ge 0.75$ and a false-alarm rate $\le 1.0$ false alert per participant-month.
3. **Multimodal Incremental Gain:** Quantify whether multimodal fusion outperforms structured check-ins alone by at least a $15\%$ relative improvement in detection sensitivity.
4. **On-Device Privacy Guarantees:** Ensure zero raw audio or unencrypted journal text leaves the host device.

### 3.2 Key Project Milestones & Phase Gates

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 0: Foundation & Scope Definition (Current Gate)                  │
│ Exit Gate: Complete Charter, Review, Architecture, Data Dictionary   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Approved
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Research & Technical Feasibility                              │
│ Exit Gate: Synthetic Data Generation, Pipeline Benchmarks, ML Proofs   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Approved
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 2: MVP Implementation                                            │
│ Exit Gate: Flutter Client (M1, M3, M4, M2), Local Encrypted DB, Tests │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Approved
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 3: Advanced Multimodal AI Research                               │
│ Exit Gate: On-device Voice (M5), Health Connect (M6), Late Fusion      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Approved
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 4: Longitudinal Validation & Reporting                           │
│ Exit Gate: Participant Cohort Study, Usability Audit, Publication      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Resource & Operating Constraints

1. **Hardware & Environment:** Mobile app must function on standard consumer smartphones (Android 9.0+ / iOS 14.0+) without requiring high-end neural processing hardware or external wearable devices.
2. **Computational Footprint:** On-device processing must consume $<30$MB RAM overhead and $<2\%$ daily battery consumption during standard user interaction.
3. **Git Governance:** Strict adherence to Section 19 of the project constitution. No pushing to GitHub without explicit authorization; no unapproved commits; every milestone verified locally.

