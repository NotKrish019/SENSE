# MindPulse (SENSE) — Minimum Viable Product (MVP) Requirements
## Phase 2 MVP Boundaries, Modality Prioritization & Acceptance Criteria

---

## 1. MVP Scoping Philosophy

To balance rapid research validation with software robustness, MindPulse divides module delivery across two operational gates:
- **Phase 2 (Minimum Viable Product):** Focuses on high-compliance, low-friction, survey-and-text modalities that establish the baseline engine and user engagement loop.
- **Phase 3 (Advanced AI & Sensor Systems):** Introduces sensor-intensive, permission-heavy modalities (on-device acoustic signal processing and OS health step syncing).

```text
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: MINIMUM VIABLE PRODUCT (MVP) SCOPE                            │
│ ├── Module 01: Pseudonymous Onboarding                                 │
│ ├── Module 02: Granular Consent & Permission Management                │
│ ├── Module 03: User Profile & Notification Window Preferences          │
│ ├── Module 04: M1 Structured Check-ins (Perceived Stress, Mood)        │
│ ├── Module 05: M2 Optional Encrypted Text Journal                      │
│ ├── Module 06: M3 Sleep Logging (Manual + Basic HealthKit/Connect Sync)│
│ ├── Module 07: M4 Cognitive Workload Tracking                          │
│ ├── Module 10: Personalized Dashboard & Calibration Ring               │
│ ├── Module 11: Longitudinal Trend Visualizations (Baseline Bands)      │
│ ├── Module 12: Rule-Based & Statistical Factor-Attributed Insights     │
│ ├── Module 13: Non-Clinical Psychoeducational Micro-Practices          │
│ ├── Module 14: Data Portability (JSON Export) & Complete Wipe          │
│ └── Module 15: Permanent Decoupled Emergency Crisis Support Gateway    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ DEFERRED TO PHASE 3
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: ADVANCED MULTIMODAL AI (DEFERRED SCOPE)                       │
│ ├── Module 08: M5 On-Device Voice Recording & eGeMAPS Acoustic Parsing │
│ ├── Module 09: M6 Continuous Passive Physical Activity Tracking        │
│ └── Advanced Deep-Learning Multimodal Fusion & Dynamic Embeddings      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Justification for Phased Modality Deferral

1. **Deferral of Voice Prosody (M5):**
   - High user friction and privacy resistance during initial onboarding.
   - Significant native C++ openSMILE binding complexity across disparate Android NDK architectures (arm64-v8a, armeabi-v7a) and iOS CocoaPods.
   - Core baseline engine ($z$-scores, EWMA, CUSUM) can be fully validated first on structured check-ins and sleep before adding audio signal pipelines.
2. **Deferral of Passive Continuous Activity (M6):**
   - Health Connect / HealthKit API permissions introduce platform-specific edge cases across custom Android OEM skins (MIUI, ColorOS, OneUI).
   - Sleep tracking (M3) already provides nocturnal rest recovery markers; daytime step logging adds marginal initial value relative to the permission hurdles.

---

## 3. MVP Acceptance Criteria Checklist

- [ ] **AC-01:** User can complete onboarding in $<90$ seconds without submitting any email, phone number, or real name.
- [ ] **AC-02:** User can toggle consent independently for check-ins, journal, sleep, and workload.
- [ ] **AC-03:** Daily morning and evening check-ins take $<30$ seconds to complete and save locally to SQLCipher encrypted SQLite.
- [ ] **AC-04:** Text journal entries are encrypted using AES-256-GCM; keyword interceptor successfully triggers crisis safety dialog if acute distress phrases are typed.
- [ ] **AC-05:** The baseline engine successfully accumulates observations over 14 days, dynamically updates $\mu_{u,t}$ and $\sigma_{u,t}$, and visually suppresses false alerts during the calibration phase.
- [ ] **AC-06:** Historical dashboard charts render multi-day trajectories with distinct baseline corridor bands ($\pm 1.5\sigma$).
- [ ] **AC-07:** The Crisis Safety button is visible and one-tap clickable from every screen, directly prompting phone dialers for Tele-MANAS and KIRAN.
- [ ] **AC-08:** "Export Data" produces a valid, readable JSON file; "Wipe All Data" completely purges the local database and resets the application to a clean state.
- [ ] **AC-09:** Application operates 100% offline with zero external network connectivity required.

