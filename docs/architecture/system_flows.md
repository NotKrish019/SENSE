# MindPulse (SENSE) — Detailed System Flows & Sequence Diagrams
## End-to-End Dynamic Interaction Flows & State Transitions

---

## 1. Daily User Check-in & Inference Sequence

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Participant)
    participant UI as Flutter Mobile UI
    participant Sec as KeyStore / Cipher
    participant DB as SQLCipher Encrypted DB
    participant Engine as Personal Baseline Engine
    participant Fusion as Late Fusion & XAI Engine

    User->>UI: Opens App for Evening Check-in
    UI->>DB: Query User Calibration Status
    DB-->>UI: Return Calibration Status (e.g., Day 18, Calibrated)
    
    User->>UI: Submits M1 (Check-in), M3 (Sleep), M4 (Workload)
    UI->>Sec: Request Active Cryptographic Context
    Sec-->>UI: Encryption Cipher Initialized
    UI->>DB: Store Raw Daily Records (Encrypted at Rest)
    
    UI->>Engine: Trigger Local Baseline Update (User ID, Current Date)
    Engine->>DB: Fetch 14-Day Rolling History H_{u,t}
    DB-->>Engine: Historical Observations Array
    Engine->>Engine: Compute Location (EWMA) and Scale (MAD)
    Engine->>Engine: Calculate Standardized Deviation z-scores
    Engine->>Engine: Run CUSUM Sequential Persistence Filter
    
    Engine->>Fusion: Pass Modality Deviations & Data Quality Indices
    Fusion->>Fusion: Compute Dynamic Reliability-Weighted Late Fusion
    Fusion->>Fusion: Calculate Epistemic Uncertainty & Shapley Contributions
    Fusion->>Fusion: Generate Factor-Attributed Natural Language Narrative
    
    Fusion->>DB: Save Daily Inference & Attribution Record
    Fusion-->>UI: Return Composite Balance State & Narrative Card
    UI-->>User: Display Evidence-Linked Dashboard Insight
```

---

## 2. Baseline Calibration State Transition Flow

```mermaid
stateDiagram-v2
    [*] --> Uncalibrated : Account Initialized (Day 1)
    
    state Uncalibrated {
        [*] --> DataAccumulation : Daily Interactions
        DataAccumulation --> DataAccumulation : Days 1 to 13
        note right of DataAccumulation
            Alerts Suppressed.
            UI displays "Calibrating Baseline (Day X of 14)".
            Only raw reflection logs displayed.
        end note
    }
    
    Uncalibrated --> Calibrated : Valid Days >= 14
    
    state Calibrated {
        [*] --> NormalEquilibrium : |z| <= 1.5
        NormalEquilibrium --> TransientDeviation : |z| > 1.5 (Day 1)
        
        state TransientDeviation {
            [*] --> HomeostaticRecovery : Day 2 Returns to Baseline
            HomeostaticRecovery --> NormalEquilibrium : Alert Suppressed (Acute Event)
            
            [*] --> PersistentDrift : Day 2 & 3 Deviation Continues
        }
        
        PersistentDrift --> SustainedAlert : CUSUM > Threshold (Days >= 3)
        note right of SustainedAlert
            Trigger Non-Alarmist Alert Card.
            Display Factor Attribution & Supportive Habits.
        end note
        
        SustainedAlert --> NormalEquilibrium : Post-Recovery Re-stabilization
    }
```

---

## 3. On-Device Text Journal & Safety Interceptor Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Participant)
    participant Editor as Journal Editor UI
    participant Interceptor as On-Device Safety Regex
    participant SafetyModal as Emergency Crisis Modal
    participant DB as SQLCipher Encrypted DB

    User->>Editor: Writes Reflective Journal Entry (M2)
    Editor->>Interceptor: Scan Text Buffer for Crisis Markers
    
    alt Crisis Expression Detected (e.g., Self-Harm Language)
        Interceptor-->>SafetyModal: Trigger Emergency Dialogue
        SafetyModal-->>User: Present Empathetic Dialog & Direct Helpline Links (Tele-MANAS / KIRAN)
        note over User,SafetyModal: User can call immediately or dismiss dialog safely.
    else No Crisis Markers Detected
        Interceptor-->>Editor: Clean Safety Status
    end
    
    User->>Editor: Taps "Save Entry"
    Editor->>DB: Encrypt & Store Entry Locally (AES-256)
    DB-->>Editor: Confirm Secure Local Storage
    Editor-->>User: Visual Checkmark Confirmation
```

---

## 4. Ephemeral Voice Processing & Zero-Storage Flow (Modality M5)

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Participant)
    participant UI as Voice Recorder Widget
    participant RAM as Volatile RAM Buffer
    participant Extractor as On-Device eGeMAPS Engine
    participant DB as SQLCipher Encrypted DB
    participant Flash as Mobile Disk Storage

    User->>UI: Taps "Record 20s Check-in" (Explicit Consent)
    UI->>RAM: Stream 16kHz 16-bit Mono PCM Audio to RAM
    Note over RAM: Audio resides ONLY in temporary RAM
    
    User->>UI: Recording Completed (or 20s Timer Expires)
    UI->>Extractor: Pass RAM Audio Buffer
    Extractor->>Extractor: Compute 88 eGeMAPS Acoustic Parameters (F0, Jitter, Shimmer, HNR)
    Extractor-->>UI: Return 88-Dimensional Numeric Vector
    
    UI->>RAM: ZERO & OVERWRITE PCM Buffer Memory
    Note over RAM: Raw audio completely erased from RAM!
    
    UI->>DB: Insert Acoustic Feature Vector
    Note over Flash,DB: Zero audio files ever touched disk or network!
    UI-->>User: Display "Acoustic Features Extracted Safely"
```

