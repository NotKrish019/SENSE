# SENSE: Limitations and Future Work

This document separates what is implemented from what is deferred. Nothing in the "Future work" section exists in the current application.

---

## 1. Implemented scope

- Encrypted local storage (SQLCipher 4.20.0 with an Android Keystore-wrapped key), a single storage owner, fail-closed opening and a debug-only development namespace.
- Persisted, append-only consent per input (M1 to M6), enforced inside each database write transaction.
- Check-in (M1), Sleep (M3) and Workload (M4) persistence with field-level provenance, same-day updates, locked inputs while saving, and date-change protection.
- Inline save feedback for Workload and Sleep. Check-in uses a completion page shown only after a successful save.
- A consent-aware, read-only Insights integration: the existing personal baseline engine (14-day window, 7-observation minimum, rolling median/MAD) applied to each variable, with insufficient-data and degenerate-dispersion states.

## 2. Limitations

### Scientific and statistical
- **No clinical validation.** SENSE has not been evaluated with users or clinicians. It does not diagnose, screen for or assess any condition and must not be used to make health decisions.
- **No predictive accuracy.** Nothing is predicted, and no accuracy, sensitivity or specificity has been measured.
- **Experimental ±1.0 band.** The words "within", "above" and "below" for a usable result use |z| < 1.0 as a display convention. It is not a validated threshold.
- **Baseline interpretation not validated.** Reaching 7 observations allows a baseline to be shown; it does not make it reliable. Fourteen days is a short window.
- **Ordinal ratings.** Seven of the eight analysed variables are 1 to 5 ratings. Medians suit them, but spreads and z-scores assume equal steps between ratings, so they are approximate.
- **Degenerate dispersion is frequent.** Rating data often have a zero median absolute deviation (most entries equal). The screen then shows the baseline and the latest entry without any direction, which is correct but means directional wording will often be absent.
- **Insufficient data.** Until a variable has 7 entries in the last 14 days, no baseline is shown for it. Each variable needs its own 7.
- **Self-report only.** All values are entered by hand and reflect the person's own judgement.
- **EWMA, CUSUM and fusion are not presented.** They exist in code but are not validated and would produce alert-like output (ADR-009 Decisions L and M).

### Security and deployment
- **Hardware-backed key protection not verified.** All device testing used an emulator with software-backed keys. Physical-device validation (TEE or StrongBox, attestation, physical backup exclusion) is outstanding; see `../architecture/encrypted_local_storage.md`, section 14.
- **Development storage only.** Saving works only in a debug build with `--dart-define=SENSE_DEV_STORAGE=1`, into an isolated development namespace. The participant database is never opened by this version. The app is not ready for participant data.
- **Android only for real data.** There is no iOS project. The web build is a preview that stores nothing.

### Functional
- **Export and Erase** from Settings are not connected. The data-layer export and transactional erase service exists, but it is not wired to the UI or combined with key destruction.
- **Journal (M2)** text is deliberately not persisted (ADR-009 Decision F). The on-device crisis-phrase check in the journal screen works without storing text.
- **Voice (M5)** and **Activity (M6)** are not implemented. No microphone, Health Connect or location permission is requested.
- **No multimodal fusion** and no combined stress score.
- **Sample content remains** on the Home dashboard and the Insight detail screen. It is labelled as sample data.
- **No live refresh.** Insights reads again when its tab is shown or after the consent preferences are closed, but not while it stays open.
- **Analyzer.** Five pre-existing analyzer findings in unrelated files remain (`testing_and_validation.md`, section 3).
- **Rust CLI** tests were not run in this environment, because the Cargo configuration targets Windows.

## 3. Future work (not implemented)

1. **Physical-device security validation:** run the encrypted-storage and persistence suites on Android devices with a TEE and with StrongBox; confirm hardware-backed keys, decide on key attestation and verify backup exclusion physically.
2. **Export and Erase in the UI**, combining logical erase with key destruction through the lifecycle owner.
3. **Research validation of the baseline presentation:** evaluate the window length, the minimum observation count and the display band with users, under an approved protocol. Consider methods designed for ordinal data.
4. **A live refresh** of Insights when entries or consent change, and replacing the remaining sample content on Home and Insight detail with saved-data views or clear empty states.
5. **Journal persistence** only after encryption, consent, retention and erase requirements for text are met (ADR-009 Decision F).
6. **Voice and Activity**, only with on-device processing, separate consent and an approved design.
7. **Multimodal fusion**, only after independent validation and an approved non-clinical output definition (ADR-009 Decision M).
8. **Participant deployment** (release builds with participant storage), only after items 1 and 2 and the relevant ethical approvals.
