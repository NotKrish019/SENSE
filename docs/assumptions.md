# MindPulse (SENSE) — Assumptions Register
## Epistemological Audit & Assumptions Tracking Log

This document tracks all assumptions underpinning the MindPulse research framework. To maintain scientific integrity, assumptions are categorized into **Verified Facts (VF)**, **Research Interpretations (RI)**, **Proposed Design Decisions (PD)**, and **Unresolved Assumptions (UA)**.

---

## 1. Epistemological Classification Matrix

| ID | Category | Summary | Evidence / Grounding | Risk if Invalid | Validation Strategy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **VF-01** | Verified Fact | Subjective stress produces measurable alterations in sleep architecture and heart rate variability. | Established psychophysiological literature (e.g., McEwen 1998, Cohen et al. 1983). | None (Empirical fact). | Established baseline. |
| **VF-02** | Verified Fact | Population-level fixed cutoff thresholds for mood/stress fail to capture individual baseline variations. | Taylor et al. (2017), Umematsu et al. (2019). | High if ignored. | Core justification for RQ1. |
| **VF-03** | Verified Fact | Missing data is ubiquitous in longitudinal ambulatory mobile health studies (often 30–60%). | Wang et al. (2014) StudentLife, Mundnich et al. (2020) TILES. | Catastrophic failure if early fusion is used. | Drives ADR-006 (Late Fusion). |
| **RI-01** | Research Interpretation | Changes in vocal prosodic variability (e.g., $F_0$ standard deviation, jitter) correlate with acute cognitive stress. | Eyben et al. (2016), Scherer (2003). | Voice model may reflect transient physical states (fatigue, colds) rather than stress. | Laboratory benchmark testing on acoustic datasets before clinical rollout. |
| **RI-02** | Research Interpretation | Lexical affective valence and self-referential pronoun density in short journals reflect psychological allostatic load. | Pennebaker et al. (2003), Tausczik & Pennebaker (2010). | Language style differences across cultural groups may confound sentiment scores. | Evaluate multilingual and socio-cultural linguistic sensitivity. |
| **PD-01** | Proposed Decision | A 7-to-14 day warm-up period is sufficient to calibrate an initial personal baseline. | Industry practice in wearable baselining (Whoop, Oura, Garmin). | False alerts during early user journey or user churn during calibration. | Implement a visible "Baseline Calibrating (Day X of 14)" state in UI. |
| **PD-02** | Proposed Decision | Flutter + SQLite (SQLCipher) provides sufficient mobile performance for on-device inference and encrypted storage. | Flutter benchmark evaluations and production mHealth apps. | Performance bottlenecks on entry-level Android devices. | Measure latency, frame drops, and database transaction times in Phase 1. |
| **PD-03** | Proposed Decision | Non-clinical, factor-attributed explanations increase user self-reflection without inducing hypochondriasis or alarm. | HCI well-being literature (e.g., Epstein et al. 2020). | Users might misinterpret explanations as medical diagnoses or fixate anxiously. | Usability testing with user feedback protocols in Phase 4. |
| **UA-01** | Unresolved Assumption | Consenting adults will regularly submit voluntary 20-second voice recordings in daily life. | Unknown compliance rate; audio collection has high perceived privacy barriers. | Modality M5 might suffer severe data sparsity ($<15\%$ compliance). | Test voice compliance in pilot feasibility study; keep M5 strictly optional. |
| **UA-02** | Unresolved Assumption | Self-reported daily workload (NASA-TLX subscale) correlates meaningfully with objective stress markers. | Theoretical assumption based on cognitive load theory; unverified in MindPulse cohort. | Workload feature may introduce noise if users report tasks inconsistently. | Correlate subjective workload ratings with daily PSS scores in Phase 1. |
| **UA-03** | Unresolved Assumption | Android Health Connect and Apple HealthKit can be queried seamlessly across disparate smartphone manufacturers. | Vendor-specific battery managers (MIUI, ColorOS, OneUI) frequently kill background processes. | Missing step count and sleep data on specific Android OEM devices. | Rely primarily on active morning check-in prompts, using passive OS sync as fallback. |
| **UA-04** | Unresolved Assumption | Late decision fusion can outperform single-modality structured check-ins when $>40\%$ of multimodal data is missing. | Theoretical hypothesis (H2/H6); needs empirical proof. | Multimodal pipeline might offer negligible gain over a simple 15-second daily survey. | Core focus of Research Question RQ2 and RQ6 in Phase 1 experimentation. |

---

## 2. Assumption Management Protocol

1. **Continuous Verification:** Every assumption categorized as *Unresolved Assumption (UA)* must have an assigned empirical experiment in Phase 1 or Phase 2.
2. **Failure Fallback:** If an assumption is refuted (e.g., UA-01 is refuted because voice recording compliance is $<10\%$), the modular architecture must allow the system to gracefully retire or relegate that modality without destabilizing the broader application.
3. **Traceability:** No model shall be promoted to production without updating this register to reflect verified vs. refuted status.

