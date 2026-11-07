# SENSE — Comprehensive Risk Register

*Formerly titled "MindPulse (SENSE)"; MindPulse was the project's former working name.*
## Multi-Category Project Risk & Mitigation Matrix

This document identifies, analyzes, and establishes mitigation controls for risks spanning technical, scientific, privacy, ethical, clinical safety, and operational domains.

---

## 1. Risk Evaluation Severity Scale

- **Likelihood:** Low (1), Medium (2), High (3)
- **Impact:** Low (1), Medium (2), High (3), Critical (4)
- **Risk Score:** Likelihood $\times$ Impact (Score Range: 1 to 12)
  - 1–3: Low (Monitor)
  - 4–6: Moderate (Mitigate)
  - 7–9: High (Active Contingency Required)
  - 10–12: Critical (Immediate Architectural Gatekeeper)

---

## 2. Multi-Category Risk Matrix

| Risk ID | Category | Description | Likelihood (1–3) | Impact (1–4) | Risk Score | Pre-Mitigation Status | Mitigation & Control Strategy | Residual Score | Owner |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- | :--- | :---: | :--- |
| **TR-01** | Technical | High computational load & battery drain on mobile devices running on-device audio feature extraction. | 2 | 3 | 6 | Moderate | Restrict audio extraction to brief ($\le 30$s) recordings; use compiled C/C++ lightweight openSMILE routines; execute only during foreground user session; no background polling. | 3 | Mobile ML Architect |
| **TR-02** | Technical | OEM aggressive background app killing on Android (Xiaomi, Oppo, Samsung) disrupting sync. | 3 | 2 | 6 | Moderate | Do not rely on background sync; design data synchronization to trigger opportunistically during active user app opens. | 2 | Mobile Engineer |
| **SR-01** | Scientific | "Cold Start" problem: High false-alarm rate during initial days before an individual baseline is calibrated. | 3 | 3 | 9 | High | Explicit "14-Day Calibration Mode" in UI where baseline warnings are suppressed; only raw self-reflection logs are displayed. | 3 | Lead Data Scientist |
| **SR-02** | Scientific | Modality Sparsity / Asynchronous Missing Data degrading multimodal fusion accuracy. | 3 | 3 | 9 | High | Adopt late decision-level fusion with dynamic reliability weights; missing modalities set weight to zero without penalizing user. | 3 | ML Research Lead |
| **SR-03** | Scientific | Ground-truth label noise due to subjective recall bias in daily EMA ratings. | 3 | 2 | 6 | Moderate | Implement validated EMA anchor scales (PSS-4 daily adaptation) combined with end-of-week retrospective PSS-10 cross-checks. | 4 | Research Methodologist |
| **PR-01** | Privacy/Legal | Regulatory non-compliance with the Indian Digital Personal Data Protection (DPDP) Act 2023. | 2 | 4 | 8 | High | Zero-knowledge pseudonymous subject IDs; end-to-end encrypted storage at rest (SQLCipher AES-256); explicit, granular, revocable consent per modality; zero third-party telemetry. | 2 | Privacy & Security Lead |
| **PR-02** | Privacy/Legal | Sensitive text or voice samples intercepted or leaked via cloud API dependencies. | 1 | 4 | 4 | Moderate | Strict architectural policy: on-device acoustic feature extraction; raw audio deleted immediately; zero raw audio transmitted to cloud. | 1 | Security Engineer |
| **CR-01** | Clinical/Safety | User in acute suicidal or psychiatric crisis misinterprets non-clinical app insights as medical evaluation. | 2 | 4 | 8 | High | Prominently displayed non-clinical disclaimers; dedicated, permanent, one-tap Emergency Support Panel with verified national hotlines (KIRAN, Tele-MANAS); keyword trigger in journal alerting user to human care resources. | 2 | Clinical Safety Advisor |
| **CR-02** | Clinical/Safety | "Nocebo" effect: Over-alerting users to minor stress fluctuations, inadvertently inducing anxiety or distress. | 2 | 3 | 6 | Moderate | Calibrate alert thresholds conservatively ($>2.0\sigma$ deviation over $>3$ consecutive days); frame all insights in supportive, non-alarmist, psychoeducational language. | 2 | UX & Ethics Researcher |
| **OR-01** | Operational | Low participant retention and high attrition over longitudinal multi-week tracking. | 3 | 3 | 9 | High | Design check-in interactions to require $<30$ seconds; provide immediate intrinsic value via visual trend reflection; avoid gamification gimmicks that induce burnout. | 4 | Project Planner |
| **TR-03** | Technical / Integrity | *(Added 2026-11-07)* Prototype UI text claims capabilities that do not exist (on-device encryption, saved/exported/erased data, computed baselines, numeric stress attributions), misleading testers, reviewers or future participants. Found in both the Flutter app and the frozen Expo app. | 3 | 3 | 9 | High | Correct Flutter copy before any demo; label all hard-coded values as sample data; claim a capability only once it is implemented and verified; freeze Expo and never present it as the current product (ADR-001 amendment). *Status 2026-11-07: Flutter copy corrected and centralised in `prototype_copy.dart`; frozen Expo copy still contains the original claims.* | 2 | Mobile Engineer |
| **TR-04** | Technical | *(Added 2026-11-07)* Development preview limited to Flutter Web in Chrome (no Android Studio / USB available); web masks native issues (touch, permissions, `sqflite`, fonts, performance). | 3 | 2 | 6 | Moderate | Treat Chrome preview as UI review only; plan native Android verification via SDK command-line tools + emulator or Android 11+ wireless debugging before any MVP sign-off. | 2 | Mobile Engineer |

---

## 3. Incident Escalation & Response Protocol

1. **Safety Trigger:** If a user types overt self-harm language into the text journal (M2), an immediate modal overlay appears with direct click-to-call links to Tele-MANAS (14416 / 1800-891-4416) and KIRAN (1800-599-0019) with empathetic crisis guidance.
2. **Data Integrity Trigger:** If cryptographic key corruption or database tamper is detected on-device, the app halts data insertion, preserves an audit log, and prompts the user to re-authenticate or re-initialize.
3. **Model Anomaly Trigger:** If the baseline engine produces anomalous z-scores ($|z| > 5.0$) across $>50\%$ of active users, the baseline algorithm is flagged for automated calibration review and baseline update is paused.

