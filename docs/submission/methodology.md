# SENSE: Methodology

This document explains what SENSE observes and how the Insights screen turns saved observations into a within-person comparison. It separates the **implemented calculation** (the existing engine, used unchanged) from **experimental presentation conventions** (choices about wording on screen). Code references: `mobile/lib/domain/baseline_engine.dart` (engine), `mobile/lib/domain/personal_insights.dart` (mapping and states), `mobile/lib/core/state/insights_controller.dart` (data path). Decision record: ADR-009 Decision L and its Milestone E implementation record in `../decisions.md`.

---

## 1. Observations

All observations are voluntary self-reports entered by hand. Nothing is read from sensors, wearables or other apps.

| Modality (consent) | Variable | Stored field | Scale | Default on screen |
|---|---|---|---|---|
| Check-in (M1) | Mood rating | `mood_rating` | 1 to 5, ordinal | 3 |
| Check-in (M1) | Motivation and energy (one combined item) | `motivation_energy_rating` | 1 to 5, ordinal | 3 |
| Check-in (M1) | Perceived stress | `perceived_stress_rating` | 1 to 5, ordinal | 2 |
| Sleep (M3) | Sleep duration | `duration_minutes` | 240 to 720 minutes in 30-minute steps; analysed in hours | 450 (7.5 h) |
| Sleep (M3) | Rest quality | `rest_quality` | 1 to 5, ordinal | 4 |
| Workload (M4) | Mental demand | `mental_demand` | 1 to 5, ordinal | 3 |
| Workload (M4) | Effort | `effort` | 1 to 5, ordinal | 3 |
| Workload (M4) | Deadlines in the next 48 hours | `deadlines_48h` | count 0 to 20 | 1 |

Bedtime and wake time are stored (`HH:MM`) but are not analysed. Each record also stores which fields the person changed and which stayed at their starting value (provenance); the baseline currently uses the values only.

**Dates.** Each record belongs to one local calendar day (one record per person per day; a second save that day updates it). A sleep record belongs to the date of **wake-up**: bedtime 23:30 on 10 November and wake-up 07:00 on 11 November is the 11 November record.

## 2. Observation window and minimum

The engine's configuration (`BaselineConfig`) is used unchanged:

- **Window:** the last 14 local calendar days, ending today (`windowSize = 14`).
- **Minimum:** at least 7 valid observations of a variable in that window (`minCalibrationPoints = 7`).

Each variable is assessed independently, so different variables can have different numbers of observations (for example 9 check-ins but 5 sleep entries). For each variable the 14 days form a series in date order; a day without a record is `null` (missing), never zero. A count of zero deadlines is a real value and is counted.

## 3. Baseline calculation (implemented)

For each variable, `PersonalBaselineEngine.computeRollingMadBaseline` is applied to the 14-day series. At the last day of the window, with at least 7 valid values, it returns:

- **location**: the median of the valid values;
- **scale**: from `computeMad`: `1.4826 × MAD` (the median absolute deviation scaled to be comparable with a standard deviation), with a fallback described in section 4;
- **z-score** of the latest observation: `(latest − median) / max(scale, 1e-4)`.

The window includes the latest observation. These numbers come directly from the engine; SENSE does not re-implement them.

## 4. Degenerate dispersion safeguard (implemented)

The engine's `computeMad` uses its MAD-based scale only when `1.4826 × MAD > 1e-4`. Otherwise it falls back to the window's plain (population) standard deviation plus 1e-4. That is exactly 1e-4 when every value is identical.

MAD is zero whenever more than half of the values equal the median, which is common for 1 to 5 ratings. Running the engine on deterministic fixtures shows what the fallback does:

| Window (valid values) | Engine scale | Latest z |
|---|---|---|
| eight values of 3 | 0.0001 (floor) | 0.0 |
| thirteen 3s, then a 4 | 0.258 (fallback SD) | 3.88 |
| thirteen 3s, then a 5 | 0.515 (fallback SD) | 3.88 |
| 2, 3, 4, 3, 2, 4, 5 | 1.4826 (MAD scale) | 1.35 |

With zero MAD, the z-score mainly says that the latest entry is the outlier, not how far it moved: a one-point and a two-point change get the same z. SENSE therefore classifies each variable using the engine's **own** branch condition. No new threshold is introduced:

| State | Condition | Shown on screen |
|---|---|---|
| Insufficient observations | fewer than 7 valid values | "Insufficient observations: n of 7 required in the last 14 days. No baseline is shown yet." |
| Degenerate dispersion | 7 or more values, but `1.4826 × MAD ≤ 1e-4` (the engine fell back) | the observation count, the personal baseline (median) and the latest entry, with "Most of your entries in this period are the same, so there is not enough variation to compare the latest entry with your baseline." No usual range and no direction. |
| Usable | 7 or more values and `1.4826 × MAD > 1e-4` | the count, the personal baseline, a usual range (median ± scale, clipped to the field's range) and the latest entry described as within, above or below (section 5) |

A unit test pins that the engine still behaves this way (`mobile/test/personal_insights_test.dart`, group "Degenerate dispersion (zero MAD)").

## 5. Experimental presentation convention: the ±1.0 band

For a **usable** result only, the latest entry is described as "within your usual range" when |z| < 1.0, "above your personal baseline" when z ≥ 1.0 and "below your personal baseline" when z ≤ −1.0. **This band is an experimental display convention, not a validated threshold.** It only chooses the words on screen. No alert, score or decision is derived from it, and it has not been validated in research.

## 6. Missing data and consent

- Missing days and missing measurements are excluded (`null`), never imputed or replaced by zero.
- A modality is read only when its persisted consent is on (M1 for check-ins, M3 for sleep, M4 for workload). The consent snapshot is read in the same database transaction as the records. If consent is off, that modality is not analysed and the screen says so. Its records are not deleted.
- Only committed records are used: never unsaved form values and never sample data. Results are cleared before every read and whenever storage becomes unavailable.

## 7. What is not presented, and why

- **EWMA and CUSUM.** The engine contains an EWMA baseline and a one-sided CUSUM persistence filter. They are not shown. ADR-009 Decision L allows descriptive within-person observations only, with no alerts, and a CUSUM signal would be an alert. Their parameters (EWMA α = 0.15; CUSUM k = 0.5, h = 3.5) have not been validated on real users.
- **Multimodal fusion.** The late-fusion engine (`late_fusion_engine.dart`, ADR-006) is not connected to any screen. Its prior weights and alert threshold were evaluated only on synthetic data, and Decision M requires independent validation and an approved non-clinical output definition before any use.
- **No combined score.** Each variable stands alone. There is no overall stress score, risk level or prediction.

## 8. Interpreting ordinal ratings

Most variables are 1 to 5 ordinal ratings. A median is appropriate for ordinal data. Differences, spreads and z-scores, however, assume that the steps between ratings are equal, which is not established. The usual range and the z-score for ratings should therefore be read as approximate, descriptive summaries of the person's own entries, not as measurements. Sleep duration (minutes) and the deadline count are numeric, but they are still self-reported.

## 9. Validity statement

Reaching 7 observations allows a baseline to be shown; it does not make it reliable. The baseline interpretation has not been validated with real users, and SENSE makes no claim about the clinical meaning of any result. The on-screen footnote says that results are descriptive only, compare the person with their own recent entries, and do not assess health or predict anything.
