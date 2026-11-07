# MindPulse (SENSE) — Research Papers & Verified Evidence Base
## Annotated Bibliography of Primary Scientific Foundations

This document provides detailed research profiles for all primary academic sources underpinning the MindPulse research architecture. Every paper listed has been verified for bibliographic authenticity, author attribution, publication venue, and DOI validity.

---

## 1. Wang et al. (2014) — StudentLife Study
- **Full Title:** StudentLife: Assessing Mental Health, Academic Performance and Behavioral Trends of College Students using Smartphones
- **Authors:** Rui Wang, Fanglin Chen, Zhenyu Chen, Tianxing Li, Gabriella M. Harari, Stefanie Tignor, Xia Zhou, Dror Ben-Zeev, and Andrew T. Campbell
- **Publication Year:** 2014
- **Conference / Journal:** Proceedings of the 2014 ACM International Joint Conference on Pervasive and Ubiquitous Computing (UbiComp '14), pp. 3–14
- **DOI:** [10.1145/2632048.2632054](https://doi.org/10.1145/2632048.2632054)
- **Research Objective:** Continuously track behavioral rhythms, mental health trajectories (depression, stress, flourishing), and academic performance in college students using continuous mobile sensing.
- **Methodology:** Multi-sensor Android mobile app deployed on $N=48$ undergraduate and graduate students over a 10-week academic term. Modalities included audio conversation sensor, accelerometer, GPS mobility, screen lock/unlock, and ecological momentary assessments (EMA).
- **Findings:** Significant correlations between changes in sleep duration, conversational frequency, physical activity, and subjective stress/depression scores. Confirmed that stress peaks sharply near academic midterm and final exam weeks.
- **Limitations:** Continuous background audio and GPS sensing caused heavy battery drain and raised serious participant privacy concerns; high participant attrition and missing EMA data towards term conclusion.
- **Relevance to MindPulse:** Validates the relationship between sleep, activity, and academic/cognitive stress, but highlights the necessity of MindPulse's voluntary micro-interaction paradigm over continuous background listening.

---

## 2. Schmidt et al. (2018) — WESAD Dataset
- **Full Title:** Introducing WESAD, a Multimodal Dataset for Wearable Stress and Affect Detection
- **Authors:** Philip Schmidt, Attila Reiss, Robert Duerichen, Claus Stockloew, and Kristof Van Laerhoven
- **Publication Year:** 2018
- **Conference / Journal:** Proceedings of the 20th ACM International Conference on Multimodal Interaction (ICMI '18), pp. 400–408
- **DOI:** [10.1145/3242969.3242985](https://doi.org/10.1145/3242969.3242985)
- **Research Objective:** Create a high-quality publicly accessible multimodal benchmark dataset for wearable physiological stress and affect detection.
- **Methodology:** Laboratory study with $N=15$ healthy adult participants instrumented with laboratory chest sensors (Respiration, ECG, EDA, EMG, Skin Temperature, 3D Acceleration) and consumer wristbands (Empatica E4: BVP, EDA, Temperature, Acceleration). Protocol included baseline, Trier Social Stress Test (TSST), amusement video clip induction, and guided meditation recovery.
- **Findings:** Achieved up to $93\%$ accuracy in binary stress classification (Stress vs. Non-stress) and $80\%$ in three-class classification (Baseline vs. Stress vs. Amusement) using decision tree and AdaBoost classifiers.
- **Limitations:** Controlled laboratory stress (TSST) differs fundamentally in duration, chronic wear, and context from naturalistic ambulatory chronic stress; small sample size ($N=15$).
- **Relevance to MindPulse:** Provides a laboratory gold-standard baseline for validating physiological and autonomic responses to acute stressors during algorithm prototyping.

---

## 3. Koldijk et al. (2014) — SWELL-KW Dataset
- **Full Title:** The SWELL Knowledge Work Dataset for Stress and User Modeling Research
- **Authors:** Saskia Koldijk, Maya Sappelli, Suzan Verberne, Mark A. Neerincx, and Wessel Kraaij
- **Publication Year:** 2014
- **Conference / Journal:** Proceedings of the 16th International Conference on Multimodal Interaction (ICMI '14), pp. 291–298
- **DOI:** [10.1145/2663204.2663257](https://doi.org/10.1145/2663204.2663257)
- **Research Objective:** Collect and model multimodal behavioral indicators of stress in realistic knowledge-work environments.
- **Methodology:** $N=25$ knowledge workers performed typical office tasks (writing reports, presentations, reading email) under three experimental conditions: neutral work, email interruptions, and strict time pressure. Tracked via facial expressions, body posture, ECG, skin conductance, and computer keystrokes.
- **Findings:** Time pressure and frequent interruptions significantly elevated subjective stress and altered body posture/interaction cadence. Subjective stress correlated strongly with cognitive task demands.
- **Limitations:** Focuses on office/desk workers; simulated office tasks may not capture long-term emotional or personal relationship stressors.
- **Relevance to MindPulse:** Informs the design of Modality M4 (Workload and Cognitive Demand Tracking), confirming that task volume and deadline pressure are direct drivers of perceived stress shifts.

---

## 4. Mundnich et al. (2020) — TILES-2018 Study
- **Full Title:** TILES-2018, a longitudinal physiologic and behavioral data set of hospital workers
- **Authors:** Karel Mundnich, Brandon M. Booth, Michelle L'Hommedieu, Theodora Chaspari, Tiantian Feng, Shrikanth S. Narayanan, et al.
- **Publication Year:** 2020
- **Conference / Journal:** Scientific Data (Nature Research), 7, Article 230
- **DOI:** [10.1038/s41597-020-00655-3](https://doi.org/10.1038/s41597-020-00655-3)
- **Research Objective:** Capture continuous physiological, environmental, and behavioral dynamics in high-stress, real-world operational environments.
- **Methodology:** Longitudinal monitoring of $N=212$ hospital healthcare professionals over 10 weeks using smartwatches, sleep trackers, proximity badges, and daily EMA surveys.
- **Findings:** Demonstrated that in real-world ambulatory field studies, missing data is unavoidable (missingness ranged from 20% to over 50% across days). Models relying on rigid synchronous early fusion experienced severe degradation.
- **Limitations:** High operational burden on hospital staff; sensor compliance dropped substantially across the 10-week duration.
- **Relevance to MindPulse:** Confirms that asynchronous compliance and missing data are fundamental realities of longitudinal research, directly motivating MindPulse’s ADR-006 (Late Decision Fusion with Dynamic Reliability Weighting).

---

## 5. Eyben et al. (2016) — The eGeMAPS Acoustic Parameter Set
- **Full Title:** The Geneva Minimalistic Acoustic Parameter Set (GeMAPS) for Voice Research and Affective Computing
- **Authors:** Florian Eyben, Klaus R. Scherer, Björn W. Schuller, Johan Sundberg, Elisabeth André, Carlos Busso, Laurence Devillers, Julien Epps, Petter Laukka, Shrikanth S. Narayanan, and Khiet P. Truong
- **Publication Year:** 2016
- **Conference / Journal:** IEEE Transactions on Affective Computing, 7(2), pp. 190–202
- **DOI:** [10.1109/TAFFC.2015.2457417](https://doi.org/10.1109/TAFFC.2015.2457417)
- **Research Objective:** Define a standardized, scientifically grounded, compact set of acoustic features for voice affective computing and clinical voice research.
- **Methodology:** Systematic theoretical and empirical reduction of acoustic parameters down to a basic 62-parameter set (GeMAPS) and an extended 88-parameter set (eGeMAPS), incorporating frequency (pitch $F_0$, jitter), energy/amplitude (shimmer, loudness), and spectral balance (HNR, spectral flux).
- **Findings:** The compact eGeMAPS feature set achieved competitive or superior emotion and stress classification compared to unguided brute-force high-dimensional acoustic feature sets ($>6000$ features), while offering superior interpretability and resistance to overfitting.
- **Limitations:** Sensitive to microphone quality and background ambient noise; acoustic parameters reflect general physiological arousal rather than specific cognitive labels.
- **Relevance to MindPulse:** Directly adopted as the official feature extraction standard for Modality M5 (Voice), enabling compact on-device computation without storing raw audio.

---

## 6. Taylor et al. (2017) — Personalized Multitask Learning
- **Full Title:** Personalized Multitask Learning for Predicting Tomorrow's Mood, Stress, and Health
- **Authors:** Sara Taylor, Natasha Jaques, Ehimwenma Nosakhare, Akane Sano, and Rosalind Picard
- **Publication Year:** 2017
- **Conference / Journal:** IEEE Transactions on Affective Computing, 11(3), pp. 514–524
- **DOI:** [10.1109/TAFFC.2017.2784832](https://doi.org/10.1109/TAFFC.2017.2784832)
- **Research Objective:** Address the poor generalization of population-wide machine learning models in predicting next-day well-being.
- **Methodology:** Multitask learning framework where each participant represents a separate task while sharing common representations, trained on longitudinal mobile and wearable data.
- **Findings:** Personalized multitask models improved next-day stress prediction accuracy by $18.2\%$ over global population models. Demonstrated that individual baseline differences dominate population-level patterns.
- **Limitations:** Required several weeks of training data per participant before personalized performance exceeded generic baselines.
- **Relevance to MindPulse:** Provides direct empirical evidence supporting MindPulse's primary research contribution: personalized baseline modeling (RQ1).

---

## 7. Cohen, Kamarck, & Mermelstein (1983) — Perceived Stress Scale
- **Full Title:** A Global Measure of Perceived Stress
- **Authors:** Sheldon Cohen, Tom Kamarck, and Robin Mermelstein
- **Publication Year:** 1983
- **Conference / Journal:** Journal of Health and Social Behavior, 24(4), pp. 385–396
- **DOI:** [10.2307/2136404](https://doi.org/10.2307/2136404)
- **Research Objective:** Develop and validate a psychometrically sound self-report instrument to measure the degree to which situations in one's life are appraised as unpredictable, uncontrollable, and overloading.
- **Methodology:** Validation across two college student samples ($N=332$, $N=114$) and a smoking-cessation community sample ($N=64$). Evaluated internal consistency, test-retest reliability, and concurrent validity with life-event scales and depressive symptomatology.
- **Findings:** Established the Perceived Stress Scale (PSS-14, PSS-10, PSS-4) as the global standard for cognitive appraisal of stress.
- **Relevance to MindPulse:** Serves as the ground-truth reference instrument for calibrating daily EMA items (M1) and validating longitudinal shift detection.

