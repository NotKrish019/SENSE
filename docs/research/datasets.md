# MindPulse (SENSE) — Research Datasets Audit & Benchmarks
## In-Depth Evaluation of Reference Datasets & Synthetic Generation Protocols

---

## 1. External Research Datasets Detailed Audit

### 1.1 WESAD (Wearable Stress and Affect Detection)
- **Source:** University of Siegen & Bosch RTC, Germany.
- **Repository:** UCI Machine Learning Repository (DOI: [10.24432/C57K5T](https://doi.org/10.24432/C57K5T)).
- **License:** Creative Commons Attribution 4.0 International (CC-BY 4.0).
- **Access Restrictions:** Completely open public download.
- **Participants:** $N=15$ healthy adult participants (12 male, 3 female, mean age $27.5 \pm 2.4$).
- **Features:**
  - Chest RespiBAN (700 Hz): ECG, EDA, EMG, Respiration, Skin Temperature, 3-axis Accelerometer.
  - Wrist Empatica E4: BVP (64 Hz), EDA (4 Hz), Skin Temperature (4 Hz), Accelerometer (32 Hz).
- **Ground Truth Labels:** Continuous 1–7 self-report scales (PANAS, STAI), ground-truth protocol conditions: 0 = Transient/Not defined, 1 = Baseline, 2 = Stress (Trier Social Stress Test: public speaking & mental arithmetic), 3 = Amusement (funny video clips), 4 = Meditation.
- **Relevance to MindPulse:** Used in Phase 1 to benchmark physiological response kinetics and stress classification algorithms against published baselines.

---

### 1.2 SWELL-KW (SWELL Knowledge Work)
- **Source:** TNO & Radboud University, Netherlands.
- **Repository:** DANS EASY Archive / ICMI 2014.
- **License:** Open Access for Academic Research upon registration.
- **Participants:** $N=25$ knowledge workers (mean age 25 years).
- **Features:** Computer interaction logs (mouse movements, keystroke rates), facial video expressions (Action Units), body posture Kinect depth maps, ECG, skin conductance.
- **Ground Truth Labels:** NASA-TLX mental demand, RSME (Rating Scale Mental Effort), VAS perceived stress before/after each task block.
- **Relevance to MindPulse:** Provides direct empirical evidence for how cognitive demand, interruption frequency, and deadlines (Modality M4) modulate subjective stress and effort.

---

### 1.3 TILES-2018 (Tracking Individual Performance with Sensors)
- **Source:** University of Southern California (USC), Information Sciences Institute (ISI).
- **Repository:** NIH / NSF Data Archive (DOI: [10.1038/s41597-020-00655-3](https://doi.org/10.1038/s41597-020-00655-3)).
- **License:** Controlled Access Data Use Agreement (DUA) for research.
- **Participants:** $N=212$ full-time hospital nurses and healthcare professionals.
- **Features:** Multi-sensor wearable logs (Garmin Vivosmart, OMsignal biometric garment), Bluetooth proximity beacons, acoustic audio badges (OWL), daily mobile surveys over 10 weeks.
- **Ground Truth Labels:** Daily EMA surveys (affect, stress, fatigue), weekly PSS-10, PSQI sleep quality, job performance evaluations.
- **Relevance to MindPulse:** Unrivaled real-world reference for handling high real-world missingness (20%–50% missing days) and designing late-fusion algorithms robust to sporadic logging.

---

### 1.4 StudentLife
- **Source:** Dartmouth College (Wang et al., 2014).
- **Repository:** StudentLife Study Open Data Portal (Dartmouth).
- **License:** Open Research Data License.
- **Participants:** $N=48$ undergraduate and graduate college students over 10 weeks.
- **Features:** Android phone sensor logs (conversational audio duration, accelerometer motion states, GPS mobility radius, screen on/off events, app usage).
- **Ground Truth Labels:** Daily Ecological Momentary Assessment (Photographic Affect Meter, stress 1–5), pre/post term PSS, PHQ-9, term GPA.
- **Relevance to MindPulse:** Informs user personas for university students and demonstrates the longitudinal co-variation of sleep duration, activity, and academic deadline stress.

---

## 2. Phase 1 Synthetic Dataset Generation Specifications

To ensure algorithmic reproducibility and safe early pipeline development, MindPulse will generate a high-fidelity synthetic benchmark dataset:
- **Cohort Size:** $N = 100$ virtual participants.
- **Temporal Duration:** $T = 60$ contiguous days per participant (6,000 participant-days total).
- **Latent Parameters per Virtual Participant $u$:**
  - $\mu_{u}^{\text{sleep}} \sim \mathcal{U}(6.0, 8.5)$ hours, $\sigma_{u}^{\text{sleep}} \sim \mathcal{U}(0.5, 1.2)$ hours.
  - $\mu_{u}^{\text{stress}} \sim \mathcal{U}(1.8, 3.2)$ Likert scale (1–5), $\sigma_{u}^{\text{stress}} \sim \mathcal{U}(0.4, 0.9)$.
  - Baseline response bias and dispositional trait variance.
- **Injected Temporal Phenomena:**
  - *Weekday vs. Weekend Cyclic Effect:* Weekend sleep duration increases by $+1.2$ hours; workload decreases by $-2.0$ units.
  - *Acute 1-Day Spikes:* Injected at probability $p = 0.05$ per day (simulating isolated deadlines or exams) with complete recovery within 24–48 hours.
  - *Multi-Day Allostatic Drift:* Injected into $30\%$ of participants between days 30 and 42 (7–10 days of sustained elevated workload, deteriorating sleep, and declining mood).
  - *Missing Data Simulation:* Modality dropout injected under Missing Completely at Random (MCAR) and Missing at Random (MAR) at rates $10\%, 20\%, 30\%, 40\%, 50\%$.
- **Output Storage:** `data/synthetic/cohort_60d_n100.parquet` with deterministic seed `seed=42`.

