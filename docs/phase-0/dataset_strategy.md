# MindPulse (SENSE) — Dataset & Validation Strategy
## Synthetic Benchmarks, Public Datasets & Observational Data Protocol

---

## 1. Three-Tiered Data Strategy

```text
┌────────────────────────────────────────────────────────────────────────┐
│ TIER 1: Synthetic Longitudinal Cohort Data (Phase 1 Baseline & Bench)  │
│ - Statistically generated 60-day trajectories for N=100 virtual users  │
│ - Controlled acute spikes, allostatic drift, and missingness injection │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TIER 2: Secondary Public Benchmark Datasets (Algorithm Calibration)   │
│ - WESAD (Lab physiological stress ground truth)                        │
│ - SWELL-KW (Knowledge work stress & interruptions)                     │
│ - StudentLife / TILES (Longitudinal mobile & behavioral time-series)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TIER 3: Consenting Observational Participant Cohort (Phase 4 Study)    │
│ - N=30 to N=60 consenting adults over 8–10 weeks                       │
│ - IRB/Ethics Committee approved, end-to-end encrypted on-device logs   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Public Research Datasets Audit

| Dataset Name | Primary Citation & DOI | Population & Size | Modalities Covered | Ground Truth Labels | Access / License | Relevance to MindPulse |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **WESAD** | Schmidt et al. (2018)<br>[10.1145/3242969.3242985](https://doi.org/10.1145/3242969.3242985) | $N=15$ healthy adult participants in controlled laboratory setting. | Chest (Respiration, ECG, EDA, EMG, Temp, Acc) + Wrist (BVP, EDA, Temp, Acc). | 3 classes: Baseline, Stress (TSST), Amusement (PANAS & STAI self-reports). | Open Access (UCI Machine Learning Repository, CC-BY 4.0). | Serves as validation benchmark for physiological stress dynamics and feature extraction algorithms. |
| **SWELL-KW** | Koldijk et al. (2014)<br>[10.1145/2663204.2663257](https://doi.org/10.1145/2663204.2663257) | $N=25$ knowledge workers performing office tasks under stress conditions. | Facial expression video, posture, skin conductance, ECG, computer logging. | Self-reported perceived stress (VAS), mental effort (RSME), task condition (neutral, email, time pressure). | Academic Research Access upon license agreement. | Provides real knowledge-work cognitive load and workload stress reference data. |
| **TILES-2018** | Mundnich et al. (2020)<br>[10.1038/s41597-020-00655-3](https://doi.org/10.1145/2663204.2663257) | $N=212$ hospital nurses and medical staff monitored over 10 weeks. | Wearable physiological sensors, Bluetooth proximity, audio badges, daily surveys. | Daily subjective stress surveys, weekly PSS-10, sleep quality (PSQI), cognitive performance. | Controlled Research Access (NIH/NSF repository upon DUA). | Directly informs handling of real-world longitudinal missingness, asynchronous logging, and nurse workload stress. |
| **StudentLife** | Wang et al. (2014)<br>[10.1145/2632048.2632054](https://doi.org/10.1145/2632048.2632054) | $N=48$ undergraduate and graduate students over a 10-week academic term. | Passive phone sensing (audio conversation, GPS mobility, screen time) + EMA. | Ecological Momentary Assessment (PAM, daily stress), pre/post PSS, PHQ-9, academic scores. | Open Academic Dataset (Dartmouth College). | Validates academic exam stress trajectories, sleep irregularities, and semester-long stress trends. |

---

## 3. Synthetic Data Generation Strategy (Phase 1)

Before recruiting any human participants, Phase 1 will implement a deterministic synthetic data generator (`ml/synthetic/generator.py`) to simulate $N=100$ virtual participants over $T=60$ days:
- **Baseline Personalization:** Each synthetic participant is assigned distinct latent baseline distributions for sleep duration ($\mathcal{N}(\mu_u, \sigma_u^2)$), baseline perceived stress, and workload capacity.
- **Stress Injection Scenarios:**
  - *Scenario 1 (Transient Spike):* 1-day acute stress spike (e.g., simulated midterm exam) with rapid 24-hour homeostatic recovery.
  - *Scenario 2 (Allostatic Drift):* Gradual 7-day worsening of sleep, increasing workload, and declining mood to test change-point detection sensitivity.
  - *Scenario 3 (Missingness Stress Test):* Random modality dropout (MCAR 10%–60%) and block dropout (e.g., weekend non-compliance) to benchmark fusion robustness under RQ6.
- **Reproducibility:** Seeded random state (`numpy.random.seed(42)`) ensures identical reproducible evaluation across algorithm variants.

---

## 4. Consenting Observational Data Collection Protocol (Phase 4)

Real human participant data collection will commence only in Phase 4 following institutional ethics committee review:
1. **Informed Consent:** Multi-stage digital consent outlining study purpose, data minimization, voluntary status, and right to withdraw.
2. **Inclusion Criteria:** Consenting adults aged 18+, possessing a compatible Android (9.0+) or iOS (14.0+) smartphone, fluent in English (for initial linguistic features).
3. **Exclusion Criteria:** Individuals currently undergoing acute clinical psychiatric inpatient treatment or receiving active clinical crisis intervention (to preserve the non-clinical research boundary).
4. **Data Retention & Anonymization:** Data stored under random UUIDv4 pseudonyms. Raw audio is never stored; only eGeMAPS acoustic vectors are retained. Local encrypted backup retained for 12 months post-study, followed by automated cryptographic purge.

