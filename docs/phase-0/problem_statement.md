# MindPulse (SENSE) — Formal Problem Statement
## Mathematical & Conceptual Formulation of Longitudinal Stress-Pattern Detection

---

## 1. Scientific Context: Allostatic Load & Stress Dynamics

Stress is an adaptive physiological and psychological reaction to acute environmental, academic, professional, or interpersonal demands. When an individual encounters a stressor, the sympathetic-adreno-medullar (SAM) axis and hypothalamic-pituitary-adrenal (HPA) axis activate, producing transient elevations in cortisol, heart rate, and cognitive arousal. In healthy dynamics, this acute response rapidly recovers to a homeostatic baseline once the demand subsides.

However, repeated, unmitigated stressors or inadequate recovery lead to **Allostatic Load** (McEwen, 1998)—the cumulative wear and tear on physiological and cognitive systems. Over time, elevated allostatic load manifests longitudinally across multiple observable modalities:
1. Deterioration of sleep duration and consistency.
2. Escalation of perceived workload and cognitive fatigue.
3. Shifting affective valence and emotional arousal in self-reports.
4. Lexical alterations in reflective writing (increased negative emotion words, elevated cognitive tentativeness).
5. Acoustic changes in speech production (decreased pitch variability, increased jitter/shimmer, slower speaking rate).
6. Disruption of circadian physical activity rhythms.

Because these manifestations emerge gradually and are experienced asynchronously, individuals often fail to recognize the transition from healthy acute stress to debilitating chronic stress until significant functional impairment (burnout) occurs.

---

## 2. The Core Failure of Population-Level Thresholds

Conventional digital health applications and clinical cutoff scales (such as PSS-10 $> 26$ or fixed step/sleep goals) apply static population-level thresholds:

$$\hat{y}_t = \mathbb{I}(s_t > \theta_{\text{population}})$$

This paradigm fails in longitudinal ambulatory monitoring due to two primary statistical phenomena:

### 2.1 High Inter-Individual Heterogeneity
Different individuals exhibit fundamentally different baseline set-points:
- Participant $A$ may naturally sleep 6.5 hours per night with high restorative efficiency and report an average perceived stress of 14/40.
- Participant $B$ may naturally require 8.5 hours of sleep and report an average perceived stress of 24/40 due to habitual dispositional traits (e.g., higher baseline neuroticism).
A static population threshold $\theta = 22$ classifies Participant $B$ as continuously "stressed" (generating continuous false alarms and alarm fatigue) while completely missing acute degradation in Participant $A$ even if Participant $A$'s stress doubles from 14 to 21.

### 2.2 Response Style & Cultural Reporting Biases
Subjective Likert-scale responses are vulnerable to individual reporting styles (e.g., central tendency bias vs. extreme response style). A score of "4/5" on a stress item means different things to different users. Fixed models treat these as identical interval scales across users, introducing severe systematic measurement error.

---

## 3. Mathematical Problem Formulation for MindPulse

Let $U = \{u_1, u_2, \dots, u_N\}$ denote the set of registered participants.

For a given user $u$, time is discretized into daily epochs $t \in \{1, 2, \dots, T\}$.

At each day $t$, user $u$ may voluntarily submit observations across a subset of the $M = 6$ modalities:

$$\mathcal{M} = \{M_1, M_2, M_3, M_4, M_5, M_6\}$$

Let $\mathbf{x}_{u,t}^{(m)} \in \mathbb{R}^{d_m}$ denote the extracted feature vector for modality $m$ at day $t$.

Let $O_{u,t} \subseteq \mathcal{M}$ denote the set of observed modalities for user $u$ on day $t$. The feature set for day $t$ is:

$$\mathcal{X}_{u,t} = \{\mathbf{x}_{u,t}^{(m)} \mid m \in O_{u,t}\}$$

### 3.1 Personal Baseline Representation
For each modality $m$, we define a personalized historical reference distribution computed over a rolling lookback window of length $W$ (where $W \ge 14$ days):

$$\mathcal{H}_{u,t}^{(m)} = \{\mathbf{x}_{u,\tau}^{(m)} \mid \tau \in [t - W, t - 1], \, m \in O_{u,\tau}\}$$

The baseline estimator computes time-varying baseline parameters:

$$\boldsymbol{\mu}_{u,t}^{(m)} = \text{Loc}(\mathcal{H}_{u,t}^{(m)}), \quad \boldsymbol{\Sigma}_{u,t}^{(m)} = \text{Scale}(\mathcal{H}_{u,t}^{(m)})$$

where $\text{Loc}(\cdot)$ and $\text{Scale}(\cdot)$ represent robust estimators of location and scale (e.g., median and median absolute deviation, or exponentially weighted moving average and variance).

### 3.2 Modality-Specific Normalized Deviation
For each observed modality $m \in O_{u,t}$, the normalized anomaly or deviation vector is computed:

$$\mathbf{z}_{u,t}^{(m)} = g\left(\mathbf{x}_{u,t}^{(m)}, \, \boldsymbol{\mu}_{u,t}^{(m)}, \, \boldsymbol{\Sigma}_{u,t}^{(m)}\right)$$

Scalar stress deviation score for modality $m$:

$$s_{u,t}^{(m)} = f_m(\mathbf{z}_{u,t}^{(m)}) \in [0, 1]$$

### 3.3 Asynchronous Multimodal Late Fusion
Because $|O_{u,t}|$ varies daily (e.g., voice or journal may be unrecorded), the composite daily stress change score $S_{u,t}$ is computed via dynamic reliability-weighted late fusion:

$$S_{u,t} = \frac{\sum_{m \in O_{u,t}} w_m \cdot r_{u,t}^{(m)} \cdot s_{u,t}^{(m)}}{\sum_{m \in O_{u,t}} w_m \cdot r_{u,t}^{(m)}}$$

where:
- $w_m \in [0, 1]$ is the prior modality importance weight.
- $r_{u,t}^{(m)} \in (0, 1]$ is the contemporaneous data quality and confidence metric for modality $m$.
- If $O_{u,t} = \emptyset$, $S_{u,t}$ is unobserved (treated neutrally, zero imputed alert).

### 3.4 Temporal Persistence & Anomaly Trigger
A stress pattern alert $A_{u,t} \in \{0, 1\}$ is triggered if and only if the composite deviation demonstrates sustained persistence over a multi-day temporal kernel $K$:

$$A_{u,t} = \mathbb{I}\left( \frac{1}{|K|} \sum_{k \in K} S_{u,t-k} > \tau_{\text{alert}} \quad \text{AND} \quad \text{TrendSlope}(S_{u,t-K:t}) \ge 0 \right)$$

where $\tau_{\text{alert}}$ is an individualized alert threshold calibrated to bound the participant false-alert rate $\mathbb{E}[\text{FAR}] \le \alpha$.

---

## 4. Formal Research Problem Statement

> **Given a sparse, asynchronous stream of voluntarily provided daily multimodal indicators $\mathcal{X}_{u,t}$ from an individual $u$, how can an adaptive algorithm accurately detect sustained deviations from $u$'s personal reference distribution $\mathcal{H}_{u,t}$ with high sensitivity ($>75\%$) and low false-alarm frequency ($<1.0$ alert/month), while generating factor-attributed natural language explanations without compromising user privacy or assuming diagnostic clinical authority?**

