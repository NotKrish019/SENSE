# MindPulse (SENSE) — Research Methodology
## Experimental Design, Validation Protocols & Bias Mitigation

---

## 1. Longitudinal Methodological Paradigm

MindPulse adopts a **Within-Person Longitudinal Observational Design**. In psychological and behavioral research, analyzing human stress trajectories through cross-sectional or between-person pooling introduces severe ecological fallacy and Simpson's Paradox:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Between-Person Pooling (Flawed Conventional ML Paradigm)               │
│ - Mixes low-stress individuals with high-stress individuals           │
│ - Learns static personality traits (e.g., neuroticism) rather than      │
│   dynamic state changes                                                │
│ - High false positives and poor cross-subject generalization           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ REPLACED BY
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Within-Person Baseline Modeling (MindPulse Paradigm)                   │
│ - Each individual u serves as their own longitudinal control           │
│ - Features are normalized as personal standardized deviations (z_u)    │
│ - Tracks temporal trajectory relative to personal dynamic equilibrium  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Cross-Validation & Data Leakage Prevention

Data leakage is the single most pervasive flaw in mobile health ML literature. MindPulse mandates a strict **Nested Participant-Isolated & Chronological Temporal Split Protocol**:

```text
Full Longitudinal Cohort (N Participants, T Days)
 │
 ├── Outer Cross-Validation (Leave-K-Participants-Out)
 │    │
 │    ├── Training Participants (N - K) ───► Model Training & Hyperparameter Tuning
 │    │    │
 │    │    └── Inner Temporal Split (Chronological Order Preserved)
 │    │         ├── Days 1 to 14: Personal Baseline Calibration Window
 │    │         └── Days 15 to T: Within-person Sequential Evaluation
 │    │
 │    └── Test Participants (K) ───────────► Zero-Leakage Generalization Testing
 │         ├── Evaluated strictly chronologically (No future leakage!)
 │         └── Baseline calibrated only on past individual history
```

### 2.1 Anti-Leakage Rules
1. **No Random Shuffling Across Time:** Randomly splitting daily records into train/test folds is strictly prohibited because adjacent days exhibit strong autoregressive correlation, falsely inflating accuracy.
2. **No Participant Mixing:** Test participants never appear in training folds during cross-validation of global priors or fusion weight initializations.
3. **Causal Calibration:** A personal baseline at day $t$ can only utilize historical observations $\tau < t$. Future data points $\tau \ge t$ are completely masked.

---

## 3. Confounding Variable Mitigation

| Confounder | Mechanism of Confounding | MindPulse Mitigation Control |
| :--- | :--- | :--- |
| **Day-of-Week Effect** | Weekend sleep and activity patterns naturally differ from weekday patterns without reflecting distress. | Implement dual-baseline stratification: Weekday Baseline (Mon–Fri) vs. Weekend Baseline (Sat–Sun). |
| **Acute Physical Illness** | Viral infections (fever, colds) alter sleep duration, vocal acoustics, and activity, mimicking stress. | Include a single-tap "Physical Illness / Sick Day" self-report tag that suppresses cognitive stress alerts. |
| **Holidays / Vacations** | Extended leave causes sudden lifestyle shifts unrelated to chronic burnout. | User-configurable "Vacation / Travel Mode" pausing baseline drift updates. |
| **Environmental Noise** | Ambient background noise distorts vocal jitter and shimmer calculations in acoustic analysis. | Signal-to-Noise Ratio (SNR) thresholding: Voice recordings with $\text{SNR} < 15\text{ dB}$ are automatically discarded from acoustic analysis with user notification. |

---

## 4. Formal Evaluation Metrics

Depending on whether an experiment evaluates continuous stress estimation or binary multi-day shift detection, the following metrics are computed:

### 4.1 Continuous Stress Estimation (Regression)
- **Mean Absolute Error (MAE):** $\text{MAE}_u = \frac{1}{T_u} \sum_{t=1}^{T_u} |y_{u,t} - \hat{y}_{u,t}|$
- **Root Mean Squared Error (RMSE):** $\text{RMSE}_u = \sqrt{\frac{1}{T_u} \sum_{t=1}^{T_u} (y_{u,t} - \hat{y}_{u,t})^2}$
- **Within-Person Pearson Correlation ($r_{\text{within}}$):** Evaluates whether daily ups and downs track the user's ground-truth ratings, independent of scale offset.

### 4.2 Multi-Day Stress Shift Detection (Classification)
- **Precision:** $\frac{\text{TP}}{\text{TP} + \text{FP}}$
- **Recall (Sensitivity):** $\frac{\text{TP}}{\text{TP} + \text{FN}}$
- **F1-Score:** $2 \cdot \frac{\text{Precision} \cdot \text{Recall}}{\text{Precision} + \text{Recall}}$
- **Precision-Recall AUC ($\text{PR-AUC}$):** Primary classification metric due to the inherent class imbalance of persistent stress shifts ($\sim 15\%$ of days).
- **False Alert Rate ($\text{FAR}$):** $\text{FAR} = \frac{\text{False Positives}}{\text{Participant-Months}}$. Must remain $<1.0$ false alert per participant-month to prevent alert fatigue.

### 4.3 Statistical Hypothesis Testing
All algorithm comparisons (e.g., Personalized Baseline vs. Population Threshold, Multimodal vs. Unimodal) must be verified using:
- **Two-tailed paired Wilcoxon signed-rank test** for non-normally distributed paired performance metrics across participants.
- **Holm-Bonferroni correction** for multiple comparisons across research questions (controlling Family-Wise Error Rate at $\alpha = 0.05$).

