# SENSE: Project Overview

**SENSE: Stress Estimation through Networked Signals and Emotions** (working name *MindPulse*, still used in some identifiers such as the Dart package `mindpulse`).

Status of this document: academic submission, 2026-11-11. It describes what is implemented in the repository at commit `fe8cd77` plus the uncommitted Workload feedback and Insights work in the working tree. Planned work is labelled as planned.

---

## Abstract

SENSE is a local-first, non-clinical mobile application that helps a person notice changes in their own stress-related patterns over time. The person voluntarily records short daily self-reports (a check-in of mood, motivation/energy and perceived stress; last night's sleep; and the day's workload). The entries are stored only on the device, in an SQLCipher-encrypted database whose key is protected by the Android Keystore, and every write requires the person's persisted, per-input consent. An Insights screen compares each variable only with the person's own recent entries, using an existing within-person baseline engine (rolling median and median absolute deviation over 14 days, with at least seven observations). It reports how much data supports each result, and it withholds directional wording when the data do not support it. SENSE does not diagnose, predict or assess health.

## Problem statement

Stress-related changes appear gradually across several everyday indicators (mood, sleep, workload) that people record, if at all, in separate places. Population thresholds (for example a fixed sleep target or a questionnaire cut-off) do not account for individual differences. The research question set in Phase 0 (`docs/phase-0/problem_statement.md`) is how voluntarily provided indicators can be used to show a person how their own patterns change over time, compared with their own history, in an understandable and privacy-preserving way.

## Motivation and objectives

1. **Within-person comparison.** Compare a person only with their own recent entries, not with population norms (ADR-005; ADR-009 Decision L).
2. **Privacy by design.** Keep all data on the device, encrypted, with no account, cloud service or synchronisation (ADR-009 Decisions H, I and J).
3. **Consent per input.** Let the person choose each input separately; nothing is collected or analysed without the matching persisted preference (ADR-009 Decision G).
4. **Honest presentation.** Show only what the data support, say when there is not enough data, and avoid clinical or predictive language.
5. **Verifiable engineering.** Back every claim with automated tests, including on-device encrypted-storage and restart tests.

## Intended users and use case

Adults who want a private, reflective view of their own day-to-day stress-related patterns (for example students around assessment periods). A typical use is a short daily routine: a check-in, a sleep entry in the morning, and a workload entry, followed by an occasional look at Insights. SENSE is **not** intended for clinical screening, for monitoring other people, or for crisis support (an on-device crisis-phrase check and signposting exist in the journal screen; see `docs/phase-0/safety_requirements.md`).

## Proposed solution

A Flutter application (Android is the real-data platform) with:

- three implemented daily inputs (Check-in M1, Sleep M3, Workload M4) with field-level provenance and one record per person per local day;
- persisted, append-only consent per input (M1 to M6), enforced inside the database write transaction;
- an encrypted local database (SQLCipher 4.20.0, Android Keystore-wrapped key), owned by a single application-level storage owner;
- an Insights screen that reads saved entries through a read-only, consent-aware interface and applies the existing personal baseline engine to each variable independently.

## Major functional modules (implemented)

| Module | What it does | Main code |
|---|---|---|
| Encrypted storage | SQLCipher database, Keystore-wrapped key, lifecycle lease, fail-closed opening, debug-only development namespace | `mobile/lib/data/local/encrypted/`, `mobile/android/` |
| Storage owner | Opens storage according to the build policy; exposes only narrow typed interfaces | `mobile/lib/data/local/sense_storage.dart` |
| Consent | Append-only consent events; preferences screen; repository-level authorization | `consent.dart`, `sqlite_repositories.dart`, `consent_preferences.dart`, `consent_screen.dart` |
| Check-in (M1) | Two-step check-in, save and same-day update | `check_in_controller.dart`, `check_in_records.dart`, `check_in_screen.dart` |
| Sleep (M3) | Duration, bedtime, wake time, rest quality; wake-up-date records; 7-day saved history | `sleep_controller.dart`, `sleep_records.dart`, `sleep_screen.dart` |
| Workload (M4) | Mental demand, effort, deadlines in 48 hours; inline save feedback | `workload_controller.dart`, `workload_records.dart`, `workload_screen.dart` |
| Insights | Personal baseline per variable from saved entries, with data-sufficiency and dispersion states | `insights_records.dart`, `personal_insights.dart`, `insights_controller.dart`, `insights_screen.dart` |
| Baseline engine | Rolling median/MAD, EWMA and CUSUM implementations (existing; only median/MAD is presented) | `mobile/lib/domain/baseline_engine.dart` |

## Main technical contributions

1. **A consent boundary at the data layer.** Every daily write checks the persisted consent event inside the same SQLite transaction as the write; in-memory preferences never authorize a write. Insights reads the consent snapshot in the same transaction as the records it governs.
2. **Single-owner encrypted storage with an isolated development namespace.** Development data can be exercised on an emulator through the real encryption path without ever touching the participant database, which debug and profile builds cannot open.
3. **Integrity of everyday saves.** Field-level provenance, same-day updates that keep the record identity, locked inputs during a save, and protection against writing answers under the wrong date after midnight.
4. **Honest within-person statistics.** The existing engine is applied per variable with explicit data-sufficiency reporting and a safeguard that suppresses directional wording when the engine's robust scale is unavailable (zero median absolute deviation).
5. **Architecture enforced by tests.** Analyzer-based (AST) static guards keep presentation code away from the database and repositories, and keep each screen on its own narrow interface.

## Scope and exclusions

Implemented: everything in the module table above.

Not implemented (see `limitations_and_future_work.md`): Journal persistence (M2; raw journal text is deliberately not stored), Voice (M5), Activity (M6), Export and Erase from the Settings screen, multimodal fusion and any combined score, alerts, participant-data deployment, and validation with real users. The Home dashboard and the Insight detail screen still show labelled sample content.

SENSE makes no clinical claim. It does not diagnose, screen for or predict any condition, and it is not a medical device.

## Related documents

- `system_architecture.md`: the implemented architecture and data flows.
- `methodology.md`: observations and the baseline method.
- `testing_and_validation.md`: what was tested and the results.
- `limitations_and_future_work.md`: limitations and deferred work.
- `demonstration_guide.md`: a 3 to 5 minute live demonstration.
- `../decisions.md`: the architecture decision records (ADR-009 and its implementation records).
- `../architecture/encrypted_local_storage.md`: encryption and storage details.
