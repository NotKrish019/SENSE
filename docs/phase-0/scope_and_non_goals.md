# MindPulse (SENSE) — Scope Boundaries & Non-Goals
## Definitive Operational Demarcation & Safety Boundary

To preserve the scientific integrity, ethical posture, and legal compliance of MindPulse, this document delineates the immutable boundaries between what the system **WILL** do and what it **WILL NOT** do.

---

## 1. What MindPulse WILL Do

1. **Longitudinal Lifestyle Well-Being Tracking:** Record and visualize voluntarily supplied daily well-being metrics (perceived stress, mood valence/arousal, sleep timing, subjective workload, reflective text, acoustic prosody, and physical steps).
2. **Personal Baseline Estimation:** Dynamically model an individual's historical typical ranges using adaptive statistical estimators ($z$-score bands, moving medians, exponentially weighted variance).
3. **Multi-Day Temporal Change Detection:** Identify multi-day shifts where an individual's current composite state significantly deviates from their historical baseline.
4. **Multimodal Correlation & Pattern Exploration:** Surface non-judgmental associations between modalities (e.g., *"During weeks when sleep onset varies by more than 90 minutes, your reported daytime cognitive fatigue is 40% higher"*).
5. **Transparent, Factor-Attributed Explanations:** Disclose the specific underlying features and historical comparisons that contributed to an alert, ensuring zero black-box obscurity.
6. **Supportive, Non-Clinical Psychoeducation:** Provide general, evidence-grounded lifestyle suggestions (e.g., consistent sleep schedules, structured micro-breaks, breathing exercises, progressive muscle relaxation).
7. **Encourage Timely Professional Care:** Gently prompt users whose stress markers remain persistently elevated over multiple weeks to consult qualified human health professionals.
8. **Independent Crisis Resource Gateway:** Provide permanently accessible, immediate one-tap routing to verified emergency crisis hotlines (e.g., Tele-MANAS, KIRAN in India; 988 in North America).

---

## 2. What MindPulse WILL NOT Do (Strict Non-Goals)

1. **NO Clinical Psychiatric Diagnosis:** MindPulse will **never** diagnose Major Depressive Disorder (MDD), Generalized Anxiety Disorder (GAD), Post-Traumatic Stress Disorder (PTSD), Bipolar Disorder, or any mental disorder defined in DSM-5 or ICD-11.
2. **NO Suicide or Crisis Prediction:** The system will **never** claim to predict suicidal ideation, suicide attempts, or self-harm. Machine learning models for stress are probabilistic and will never serve as crisis gatekeepers.
3. **NO Medical Prescriptions or Clinical Interventions:** MindPulse will **never** prescribe pharmaceuticals, supplements, therapeutic regimens, or formal psychotherapy.
4. **NO Replacement of Mental Health Professionals:** MindPulse is not a digital therapist, virtual counselor, or medical provider. It does not replace clinical consultation.
5. **NO Autonomous Medical Decision-Making:** The application does not generate medical device data or clinical recommendations.
6. **NO Stealth Surveillance or Continuous Background Listening:** The application will **never** covertly record microphone audio, access cameras, track continuous GPS locations, read SMS messages, scan address books, or log background keyboard strokes.
7. **NO Institutional Data Sharing or Surveillance:** Personal records, baseline deviations, and journal entries will **never** be transmitted or made accessible to universities, employers, health insurance underwriters, or advertising brokers.
8. **NO Conflation of Correlation with Causation:** Statistical associations between features will be communicated as empirical observations, not absolute causal truths.
9. **NO Penalization of Missing Modalities:** Incomplete, skipped, or unrecorded modalities will **never** be scored as negative well-being indicators.
10. **NO Unconsented Third-Party Cloud Transmissions:** Raw audio recordings and raw reflective journals will **never** be transmitted to external commercial AI APIs (such as OpenAI, Google Gemini Cloud, or Anthropic) without approved on-device transformations and explicit consent.

---

## 3. Dedicated Crisis Safeguard Protocol

```text
                                 USER INTERACTION
                                        │
           ┌────────────────────────────┴───────────────────────────┐
           ▼                                                        ▼
   REGULAR ML PIPELINE                                     CRISIS SAFETY GATEWAY
(Daily Check-ins, Sleep, etc.)                           (Permanently Visible Top Bar)
           │                                                        │
           ▼                                                        ▼
Personal Baseline & Deviation                           One-Tap Instant Crisis Panel
           │                                                        │
           ▼                                                        ▼
Non-Clinical Lifestyle Insight                          Direct Phone Dialer:
- "Your workload was higher this week"                  - Tele-MANAS (14416 / 1800-891-4416)
- "Consider taking a brief evening walk"               - KIRAN (1800-599-0019)
                                                        - Vandrevala Foundation (9999-666-555)
                                                        - AASRA (91-9820466726)
```

- **Separation of Concerns:** The crisis safety panel is completely decoupled from ML inference. Even if the ML model estimates a normal stress score, the emergency support button is persistently accessible on every single screen.
- **Safety Keyword Interceptor:** In the voluntary text journal (M2), an on-device regex/keyword scanner monitors for explicit crisis markers (e.g., *"want to end my life"*, *"kill myself"*, *"cannot live anymore"*). Upon matching, an immediate empathetic dialog overlay is presented offering direct one-tap connection to verified national mental health helplines. The raw text is not flagged to third parties.

