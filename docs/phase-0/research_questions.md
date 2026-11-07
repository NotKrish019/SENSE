# MindPulse (SENSE) — Research Questions & Hypotheses
## Formal Experimental Formulation & Quantitative Evaluation Metrics

This document formalizes the scientific research questions, testable hypotheses, experimental variables, and evaluation metrics guiding MindPulse.

---

## 1. Research Questions Matrix

```text
┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐
│   RQ1   │      │   RQ2   │      │   RQ3   │      │   RQ4   │      │   RQ5   │      │   RQ6   │
│Baseline │      │Multimod │      │Modality │      │Temporal │      │Explain- │      │ Missing │
│Personal-│ ───► │ Incre-  │ ───► │ Contri- │ ───► │Persist- │ ───► │ ability │ ───► │ Modality│
│ ization │      │ mental  │      │ bution  │      │  ence   │      │ Compre- │      │ Robust- │
│ vs Fixed│      │  Value  │      │ Ranking │      │Dynamics │      │ hension │      │  ness   │
└─────────┘      └─────────┘      └─────────┘      └─────────┘      └─────────┘      └─────────┘
```

---

### RQ1: Personalized Baseline Modeling vs. Fixed Population Thresholds
- **Question:** Does within-person baseline modeling provide statistically significant reductions in false-positive stress alerts and superior sensitivity to within-person stress shifts compared to fixed population-level thresholds?
- **Hypothesis 1 (H1):** Adaptive within-person baseline normalization (e.g., dynamic $z$-score, rolling median absolute deviation, or personalized anomaly detection) achieves at least a $30\%$ reduction in false-positive alert rate ($\text{FAR}$) while preserving or improving detection sensitivity compared to population-norm cutoffs.
- **Independent Variable:** Baseline modeling approach (Global population threshold vs. Within-person rolling window vs. Personalized hierarchical Bayesian / multitask model).
- **Dependent Variables:** False Alert Rate per participant-month ($\text{FAR}$), Area Under the Precision-Recall Curve ($\text{PR-AUC}$), Within-Person Sensitivity (True Positive Rate).
- **Evaluation Protocol:** Longitudinal split per participant ($T_{\text{train}} = 14$ days, $T_{\text{test}} = 30$ days); nested cross-validation with participant-level isolation to prevent cross-subject leakage.

---

### RQ2: Multimodal Integration vs. Structured Check-ins Alone
- **Question:** Does the integration of multimodal signals (sleep, workload, text, voice, physical activity) improve the accuracy and timeliness of stress-shift detection compared with structured self-report check-ins (M1) alone?
- **Hypothesis 2 (H2):** Multimodal feature fusion yields a statistically significant increase ($p < 0.05$, paired Wilcoxon signed-rank test) in detection F1-score ($\ge 15\%$ relative gain) and earlier shift detection (mean lead time $\Delta t \ge 1.5$ days) compared to unimodal daily self-report check-ins.
- **Independent Variable:** Input modality subset ($\{M_1\}$ alone vs. $\{M_1, M_3, M_4\}$ vs. full set $\{M_1, \dots, M_6\}$).
- **Dependent Variables:** F1-score, Precision, Recall, Early Detection Lead Time (days prior to peak subjective distress), Brier Score (calibration error).
- **Evaluation Protocol:** Ablation experiments systematically adding modality subsets; comparing time-to-detection of sustained multi-day stress episodes.

---

### RQ3: Incremental Modality Information Gain
- **Question:** What is the relative incremental predictive value and information gain provided by each individual modality when integrated into the stress monitoring pipeline?
- **Hypothesis 3 (H3):** Modalities directly capturing biological recovery (M3: Sleep) and acute cognitive demands (M4: Workload) contribute the highest incremental Shapley values ($\phi_m$), whereas acoustic prosody (M5) and text journals (M2) provide contextual modulation during high-ambiguity transitions.
- **Independent Variable:** Feature sets grouped by modality $M_m$.
- **Dependent Variables:** Modality Shapley Value ($\text{SHAP}$ importance), Permutation Feature Importance, Drop-in-F1 when modality $m$ is ablated.
- **Evaluation Protocol:** Shapley Additive Explanations (SHAP) across cross-modal models; leave-one-modality-out (LOMO) feature ablation benchmarks.

---

### RQ4: Temporal Persistence vs. Acute Fluctuations
- **Question:** Can temporal time-series modeling distinguish transient, benign acute stress fluctuations (e.g., single-day deadline spikes) from maladaptive, sustained multi-day shifts in well-being?
- **Hypothesis 4 (H4):** Autoregressive temporal modeling and sequential change-point detection (e.g., CUSUM, EWMA with persistence filter) can differentiate isolated single-day deviations from chronic shifts spanning $\ge 5$ consecutive days with a specificity $>85\%$.
- **Independent Variable:** Temporal aggregation algorithm (Static snapshot vs. Moving Average filter vs. Sequential CUSUM / Change-Point Detection vs. 1D-CNN/GRU temporal kernel).
- **Dependent Variables:** Specificity on transient single-day spikes, Mean Time to Detection (MTTD) on persistent shifts, Alert Stability Index.
- **Evaluation Protocol:** Synthetic and real multi-day challenge scenarios containing isolated 1-day acute spikes vs. simulated 7-day allostatic drift.

---

### RQ5: Explainable AI & User Comprehension
- **Question:** Do evidence-grounded, factor-attributed natural language explanations improve user comprehension, subjective trust, and actionable self-reflection compared to unexplained numerical stress scores?
- **Hypothesis 5 (H5):** Participants presented with factor-attributed explanations report significantly higher scores on the System Usability Scale (SUS $\ge 80$), higher perceived agency, and reduced anxiety compared to participants presented with an unexplained numerical stress index.
- **Independent Variable:** Presentation format (Raw numerical score vs. Visual bar chart vs. Factor-attributed natural language narrative with historical comparison).
- **Dependent Variables:** Explanation Satisfaction Scale (Hoffman et al., 2018), System Usability Scale (SUS), User Trust Index, Self-Reported Anxiety Impact (STAI-6).
- **Evaluation Protocol:** Within-subjects counterbalanced user study with qualitative interview coding and validated Likert questionnaires.

---

### RQ6: Robustness Under Missing Modalities
- **Question:** How does sporadic, asynchronous, and missing modality engagement influence detection performance, and which fusion architecture maintains the highest graceful degradation?
- **Hypothesis 6 (H6):** Decision-level late fusion with dynamic quality weighting exhibits superior robustness (F1-score degradation $<10\%$ when $50\%$ of modalities are missing at random) compared to early feature concatenation with mean/MICE imputation (F1-score degradation $>30\%$).
- **Independent Variable:** Missing Data Mechanism (Missing Completely at Random [MCAR] from $10\%$ to $70\%$ vs. Modality dropout) and Fusion Strategy (Early concatenation + KNN imputation vs. Intermediate autoencoder vs. Dynamic Late Decision Fusion).
- **Dependent Variables:** Relative F1-score retention, Calibration curve slope, Prediction variance under missingness.
- **Evaluation Protocol:** Controlled synthetic dropout injection benchmarking performance curves across varying levels of modality attrition.

