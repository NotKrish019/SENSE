# MindPulse (SENSE) — Architecture Decisions & Design Patterns
## Core Design Patterns, Boundary Segregation & Structural Blueprints

---

## 1. Architectural Patterns

MindPulse implements three core software engineering patterns:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 1. CLEAN ARCHITECTURE (Mobile Client)                                  │
│ Presentation Layer (Widgets / BLoC) ──► Domain Layer (Entities / UCs)  │
│                                                │                       │
│                                                ▼                       │
│                               Data Layer (Repositories / Local DB)     │
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│ 2. OFFLINE-FIRST REPOSITORY PATTERN                                    │
│ UI strictly observes reactive Streams from local encrypted SQLite;    │
│ zero UI blocking on remote network or heavy background compute.       │
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│ 3. MODULAR 4-STAGE PIPELINE PATTERN (ML Engine)                        │
│ Raw Ingestion ──► Feature Extract ──► Personal Baseline ──► Late Fusion │
│ (Each stage is an independently testable, decoupled interface).        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Summary Index of Approved Architecture Decision Records

Detailed ADR specifications are maintained in [`docs/decisions.md`](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md):

- **[ADR-001: Selection of Flutter as the Cross-Platform Mobile Framework](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-001-selection-of-flutter-as-the-cross-platform-mobile-framework)**  
  *Rationale:* Impeller pixel-perfect rendering across iOS/Android, unified audio streaming (`record`), reliable Health Connect / HealthKit bridge, and hardware-backed SQLCipher encryption at rest.
- **[ADR-002: Modular Tiered Architecture for Multimodal Machine Learning](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-002-modular-tiered-architecture-for-multimodal-machine-learning)**  
  *Rationale:* Decouples preprocessing, personal baselining, temporal filtering, and decision-level fusion, allowing independent scientific ablation and missing-modality resilience.
- **[ADR-003: On-Device Feature Extraction for Highly Sensitive Voice & Text](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-003-on-device-feature-extraction-for-highly-sensitive-voice--text)**  
  *Rationale:* Eliminates network leak vectors and complies with DPDP Act 2023 by extracting acoustic prosody in RAM and immediately purging raw audio.
- **[ADR-004: Decoupled Independent Crisis Safety Pathway](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-004-decoupled-independent-crisis-safety-pathway)**  
  *Rationale:* Isolates emergency helpline routing (Tele-MANAS, KIRAN) from probabilistic ML inference to guarantee user safety without relying on model state.
- **[ADR-005: Within-Person Statistical Baselines vs. Population Norms as Primary Engine](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-005-within-person-statistical-baselines-vs-population-norms-as-primary-engine)**  
  *Rationale:* Addresses high between-person heterogeneity and subjective Likert response biases by computing deviations relative to personal rolling historical equilibrium.
- **[ADR-006: Decision-Level Late Fusion for Asynchronous Modality Data](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-006-decision-level-late-fusion-for-asynchronous-modality-data)**  
  *Rationale:* Supports asynchronous user logging where modalities are missing at random without corrupting remaining signals.
- **[ADR-007: Phased Modular MVP Scoping (Prioritizing M1, M3, M4, M2 before M5, M6)](file:///c:/Users/krish/Desktop/SENSE/docs/decisions.md#adr-007-phased-modular-mvp-scoping-prioritizing-m1-m3-m4-m2-before-m5-m6)**  
  *Rationale:* Minimizes technical and permission friction in early user validation by proving the core baseline engine on survey and text data before integrating audio and health platform APIs.

