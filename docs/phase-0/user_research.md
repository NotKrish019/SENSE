# MindPulse (SENSE) — User Research & Target Population
## User Personas, Interaction Ergonomics & Longitudinal Adherence Modeling

---

## 1. Target Population Demarcation

The intended broad product population encompasses diverse adult demographics (aged 18 and above) experiencing variable cognitive, occupational, and lifestyle stressors.

### 1.1 Study Cohort vs. Broad Product Population
In adherence to the research constitution, MindPulse explicitly distinguishes between:
1. **The Intended Product Population:** Adults across diverse occupations, age brackets, cultural backgrounds, and digital literacy levels.
2. **The Phase 1 & 4 Experimental Cohorts:** A clearly bounded, consenting sample of adults ($N=30$ to $N=60$) recruited from university student bodies and knowledge-worker environments. Findings from this sample will be explicitly bounded as representative of young-to-mid career adult knowledge workers rather than generalized universally to all humans.

---

## 2. User Personas

### Persona A: The Overwhelmed University Graduate Student ("Aarav", 23)
- **Profile:** Final-year Master's engineering student with thesis deadlines, exam pressure, and job interviews.
- **Stress Manifestation:** Erratic sleep schedule (irregular bedtimes ranging from 1:00 AM to 4:30 AM), high subjective cognitive workload, deteriorating diet, elevated self-reported stress spikes near deadlines.
- **Interaction Constraints:** Needs check-ins that take $<20$ seconds. High smartphone usage, but easily annoyed by nagging notifications.
- **Privacy Sensitivity:** Highly sensitive to academic evaluation; terrified that stress records might be visible to faculty or prospective employers.

### Persona B: The Corporate Knowledge Worker ("Priya", 31)
- **Profile:** Senior software product analyst at a multinational tech firm, balancing high-stakes sprint deliverables, corporate politics, and family responsibilities.
- **Stress Manifestation:** Chronic mental fatigue, prolonged sedentary bouts, flat vocal prosody during late evening check-ins, high subjective effort ratings.
- **Interaction Constraints:** Needs check-ins scheduled around corporate meetings (e.g., morning 8:30 AM before standup, evening 8:00 PM during wind-down).
- **Privacy Sensitivity:** Extreme concern regarding enterprise surveillance; will reject the application immediately if corporate email or workplace network integration is requested.

### Persona C: The Freelance Creative / Gig Entrepreneur ("Vikram", 28)
- **Profile:** Independent UI/UX consultant and digital freelancer managing fluctuating client revenue and unpredictable project demands.
- **Stress Manifestation:** Severe day-to-day workload variance, periods of insomnia alternating with exhaustion, high emotional variability in text journals.
- **Interaction Constraints:** Highly values visual self-reflection, aesthetic dashboard design, and historical correlation heatmaps.

---

## 3. Interaction Ergonomics & Adherence Modeling

A primary cause of failure in digital well-being apps is survey fatigue and engagement drop-off after 7–10 days. MindPulse mitigates this through deliberate ergonomic constraints:

```text
Daily User Journey (Total Interaction Time: < 90 seconds)
┌───────────────────────────────────────────────┐
│ Morning Check-in (30 seconds, 8:00–9:30 AM)   │
│ - Sleep duration & quality rating (1 tap)     │
│ - Morning mood & energy slider (2 taps)       │
│ - Anticipated daily workload (1 tap)          │
└───────────────────────┬───────────────────────┘
                        ▼
┌───────────────────────────────────────────────┐
│ Evening Reflection (60 seconds, 8:00–9:30 PM) │
│ - Evening perceived stress rating (1 tap)     │
│ - Optional: 2-sentence journal entry (M2)     │
│ - Optional: 20-second voice check-in (M5)     │
│ - Instant visual feedback on daily balance    │
└───────────────────────────────────────────────┘
```

### 3.1 Ergonomic Constraints
- **Time Cap:** Active mandatory interaction must never exceed 30 seconds for morning check-ins and 60 seconds for evening check-ins.
- **Zero Interruption Philosophy:** No intrusive mid-day pop-ups or random chime alerts during working hours. Notifications are restricted to two configurable windows: a morning wake-up window and an evening wind-down window.
- **Neutral Missingness:** If a user misses a check-in, the app does not send guilt-inducing notifications (*"You forgot to check in!"*). It silently marks the day as unobserved and resumes calibration upon the next voluntary entry.

---

## 4. Privacy Perception Across Demographics

| Demographic Segment | Primary Privacy Concern | Required System Guarantee |
| :--- | :--- | :--- |
| **Students (18–24)** | Fear of academic or parental surveillance. | Standalone local account; no institutional Single-Sign-On (SSO); zero university data linkages. |
| **Corporate Employees (25–45)** | Fear of performance appraisal bias or employer snooping. | Local encrypted storage (SQLCipher); zero connection to enterprise tools (Slack, Teams, Workday). |
| **Older Adults (45+)** | Suspicion of biometric data theft and cloud AI surveillance. | On-device voice feature extraction; explicit display that raw voice recordings are deleted instantly after extraction. |

