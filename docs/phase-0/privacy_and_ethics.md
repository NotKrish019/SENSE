# MindPulse (SENSE) — Privacy, Ethics & Data Governance
## Regulatory Compliance, Cryptographic Architecture & Ethical Research Principles

---

## 1. Regulatory Governance Framework

MindPulse is engineered to adhere strictly to the highest standards of data protection and human participant research ethics:

1. **Digital Personal Data Protection Act, 2023 (DPDP Act 2023, India):**
   - *Section 6 (Notice & Consent):* Explicit, unbundled, itemized notice presented in clear, plain language before processing any personal data.
   - *Section 7 (Legitimate Uses):* Research and personal well-being processing grounded exclusively in unambiguous user consent.
   - *Section 12 (Right to Correction & Erasure):* Full self-service capabilities allowing participants to delete any specific day, modality, or their entire historical dataset with zero residue.
   - *Data Minimization:* Processing is restricted strictly to features necessary for well-being trend modeling; zero background eavesdropping or secondary commercial monetization.

2. **ICMR National Ethical Guidelines for Biomedical and Health Research (2017):**
   - *Principle of Non-Maleficence:* Mitigation of psychological distress; absolute prohibition against alarmist medical labeling.
   - *Principle of Autonomy:* Voluntary enrollment with unconditional, penalty-free right to withdraw at any time.
   - *Protection of Vulnerable Individuals:* Immediate independent crisis routing for any individual exhibiting severe distress.

---

## 2. Granular Tiered Consent Model

Informed consent in MindPulse is not a monolithic "Agree to All Terms" checkbox. Instead, it utilizes an **Interactive Tiered Consent Console**:

```text
┌────────────────────────────────────────────────────────┐
│ MINDPULSE PRIVACY & PERMISSION CONSOLE                 │
├────────────────────────────────────────────────────────┤
│ [Required for App]                                     │
│ [X] Core Account & Local Baseline Engine               │
│     (Stores pseudonymous ID and encrypted local DB)    │
│                                                        │
│ [Optional Modality Switches - Granular & Revocable]    │
│ [X] M1: Daily Structured Check-in Prompts              │
│ [X] M2: Private Encrypted Text Journal                 │
│ [X] M3: Sleep Tracking (Manual log or Health Connect)  │
│ [ ] M4: Subjective Workload Rating                     │
│ [ ] M5: 20-Second Voice Acoustic Check-in (Opt-In)     │
│ [ ] M6: Physical Step Count (Health Connect)           │
│                                                        │
│ [Data Deletion & Rights]                               │
│ [ Export My Data (JSON) ]   [ Permanently Wipe All ]   │
└────────────────────────────────────────────────────────┘
```

- **Independent Modality Consent:** A user can enable Check-ins and Sleep while permanently disabling Voice and Activity without any degradation in remaining app capabilities.
- **Revocability:** Disabling a modality instantly stops data ingestion for that channel and prompts the user whether past records for that channel should be purged.

---

## 3. Cryptographic & Security Safeguards

```text
USER DEVICE BOUNDARY
┌────────────────────────────────────────────────────────────────────────┐
│ User UI & Input Widgets                                                │
│       │                                                                │
│       ▼                                                                │
│ Hardware Keystore / iOS Keychain ───► AES-256-GCM Encryption Key       │
│                                              │                         │
│                                              ▼                         │
│ Local Database Engine (SQLCipher) ──► Encrypted SQLite Database on Disk│
│ - Raw text journal encrypted at rest                                   │
│ - Raw voice audio NEVER stored (extracted acoustic vectors only)       │
│ - Zero unencrypted biometric records                                   │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Encryption at Rest:** All local relational tables are encrypted via **SQLCipher (AES-256-GCM)**. The encryption key is dynamically derived using PBKDF2/Argon2 from a random secret securely stored in the Android KeyStore or iOS Keychain.
2. **Ephemeral Voice Processing:** When a user completes an optional voice check-in, the audio stream is buffered in volatile RAM, processed through the on-device acoustic feature extractor (eGeMAPS), and the raw PCM audio buffer is immediately overwritten and zeroed out. **Raw audio is never written to flash storage or transmitted over any network interface.**
3. **Zero-Knowledge Pseudonymization:** Participants are identified solely by a randomly generated UUIDv4 Subject Identifier. No phone numbers, real names, email addresses, or government identifiers are stored in the research database or linked to feature vectors.

