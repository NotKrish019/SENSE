# MindPulse (SENSE) — Mobile Application Requirements
## Functional & Non-Functional Specifications for the Cross-Platform Mobile Client

---

## 1. Scope of the Mobile Application

The primary user-facing deliverable of MindPulse is a native cross-platform mobile application targeting **Android (API 28+ / Android 9.0+)** and **iOS (iOS 14.0+)** built with Flutter.

---

## 2. Functional Requirements by Module (Modules 1 to 15)

| Module ID | Module Name | Priority | Functional Requirement Specifications |
| :--- | :--- | :---: | :--- |
| **MOD-01** | **User Onboarding** | P0 (MVP) | Multi-step educational walkthrough explaining project mission, voluntary research nature, non-clinical boundaries, and pseudonymous account initialization. |
| **MOD-02** | **Consent & Privacy Management** | P0 (MVP) | Granular permission switches per modality; clear explanation of data storage; links to privacy policy; instant revocation triggers. |
| **MOD-03** | **Personal Profile & Preferences** | P0 (MVP) | Configuration of wake/sleep target windows, notification prompt times (morning/evening), baseline calibration status indicators. |
| **MOD-04** | **Daily Well-Being Check-ins** | P0 (MVP) | Rapid Likert sliders for momentary stress, valence, arousal, energy, and motivation. Completed in $<25$ seconds. |
| **MOD-05** | **Optional Text Journal** | P0 (MVP) | Distraction-free rich-text reflection editor with AES-256 local encrypted storage; client-side safety keyword interceptor. |
| **MOD-06** | **Sleep Tracking** | P0 (MVP) | Manual bedtime/wake-up entry dialog with automatic fallback sync from Health Connect / HealthKit if authorized. |
| **MOD-07** | **Workload Tracking** | P0 (MVP) | Daily sliders for mental demand, subjective effort, completed tasks, and upcoming deadline counters. |
| **MOD-08** | **Optional Voice Recording** | P1 (Phase 3) | 20–30 second audio recorder with real-time audio waveform visualizer; on-device acoustic feature extraction; automatic audio purge. |
| **MOD-09** | **Optional Activity Tracking** | P1 (Phase 3) | Passive daily step count and active minutes sync via Health Connect / Apple HealthKit; manual step entry fallback. |
| **MOD-10** | **Personalized Dashboard** | P0 (MVP) | Home screen displaying current daily check-in status, calibration progress ring, current balance state, and quick-action buttons. |
| **MOD-11** | **Historical Trend Visualization** | P0 (MVP) | Interactive multi-week charts displaying personal baseline bands ($\pm 1.5\sigma$) and historical modality correlations. |
| **MOD-12** | **AI-Generated Observations** | P0 (MVP) | Plain-language, factor-attributed narrative cards explaining which features contributed to detected shifts without alarmist scores. |
| **MOD-13** | **Well-Being Recommendations** | P0 (MVP) | Evidence-grounded, non-clinical psychoeducational micro-practices (e.g., box breathing, sleep hygiene tips, cognitive reframing prompts). |
| **MOD-14** | **Data Export & Deletion** | P0 (MVP) | Single-tap "Export My Data (JSON)" and cryptographic "Purge All Data & Reset Account" fulfilling DPDP Act 2023 requirements. |
| **MOD-15** | **Safety & Professional Support** | P0 (MVP) | Persistent, permanently accessible top-bar emergency button opening verified national mental health helplines with direct phone dialers. |

---

## 3. Non-Functional Requirements (NFR)

1. **Security & Cryptography:** All relational databases stored locally must be encrypted using SQLCipher with AES-256-GCM.
2. **Performance & Responsiveness:** Cold application launch time must not exceed 2.0 seconds on mid-range Android devices (e.g., Snapdragon 680 or equivalent). Frame render rate must maintain 60 FPS across core dashboard scrolls.
3. **Offline-First Resilience:** The mobile application must function completely offline. All baseline computations, feature extractions, local storage queries, and insights must generate locally without an active internet connection.
4. **Battery Efficiency:** Daily background and foreground CPU battery impact must be $<1.5\%$ of total battery discharge per 24 hours.
5. **Accessibility (a11y):** Compliance with WCAG 2.1 Level AA: minimum 4.5:1 text contrast ratio, dynamic font scaling support, and full screen-reader semantic labels (TalkBack on Android, VoiceOver on iOS).

