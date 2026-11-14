# SENSE: Live Demonstration Guide (3 to 5 minutes)

Use **development data only**. Never enter personal data.

## The development-data banner

When the app is run as a debug build with `--dart-define=SENSE_DEV_STORAGE=1`, it stores entries in an isolated, encrypted **development namespace** on the device. It has its own database file and its own Keystore key, and it can never be used as participant storage. While it is enabled, every screen shows the red banner **"DEVELOPMENT DATA — NOT FOR PARTICIPANTS"**. Without the define, the app saves nothing and shows its prototype "not saved" behaviour.

## Preparation (before the session)

```bash
cd mobile
flutter devices                                   # an Android emulator, e.g. emulator-5554
flutter run -d emulator-5554 --dart-define=SENSE_DEV_STORAGE=1
```

A brand-new development namespace has no history, so Insights will show "Insufficient observations" for every variable. That is the correct behaviour and is worth demonstrating. To also show a baseline, pre-load **synthetic development fixtures** before the session by running phase 1 of the end-to-end test. It starts from an empty development namespace, turns on consent and writes about a week of labelled synthetic entries plus today's entries, and leaves them in place:

```bash
flutter test integration_test/insights_end_to_end_test.dart -d emulator-5554 \
  --no-uninstall --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_E2E_PHASE=1
flutter run -d emulator-5554 --dart-define=SENSE_DEV_STORAGE=1   # same app id: the data is kept
```

Tell the evaluators that these earlier days are synthetic test fixtures. Because phase 1 also saves today's check-in, sleep and workload, saving them again during the demonstration shows the **update** messages ("Check-in updated", "Today's sleep entry was updated.", "Today's workload entry was updated.") instead of the first-save messages. Afterwards you can remove all development data by running phase 2 of the same test (it destroys the namespace at the end) or by uninstalling the debug app.

## Sequence

| # | Time | Do | Observe |
|---|---|---|---|
| 1 | 0:00 | App starts: splash, then onboarding. Tap **Skip** (or step through and tap **Get Started**). | The red development banner at the top. Onboarding appears on every launch. |
| 2 | 0:20 | On **Choose what you would like to share**, tap **M1 · Structured check-ins**, **M3 · Sleep** and **M4 · Workload**, then **Continue to SENSE**. | Each preference turns on only after it is saved; the screen says choices are saved to development storage. Everything starts off. |
| 3 | 0:45 | Tap the round **New daily check-in** button. Choose a mood (e.g. **Great**), tap **Continue to stress rating**, adjust stress, tap **Finish check-in**. | "Check-in saved" appears only after the database write (before finishing, **Back** returns to step 1 with the answers kept). **Return to Home**. |
| 4 | 1:25 | On Home, scroll to **Sleep**. Change **Bedtime** to a time before midnight and **Wake time** to this morning; pick a rest quality; tap **Save Sleep Record**. | The header reads "Last night's sleep (woke today, …)". The status line above the button confirms the save; "Your last 7 days" shows the night on **today**, the wake-up date. Days without entries show "–", not zero. Tap **Back**. |
| 5 | 2:05 | Open **Workload**. Tap **Save Workload Rating**, then immediately tap **One more deadline** and **Save Workload Rating** again. | First "Today's workload entry was saved…", then "Today's workload entry was updated." The message is inline above the button, which is never covered. |
| 6 | 2:35 | Restart: stop the app (press `q` in the terminal or swipe it away), then run `flutter run … --dart-define=SENSE_DEV_STORAGE=1` again. Skip onboarding; on the consent screen the three choices are still on; **Continue to SENSE**. | The data and the choices survived a process restart. |
| 7 | 3:05 | Open the **Insights** tab. | "Your personal baseline", "Last 14 days: … (development data)". For each variable, either "Insufficient observations: n of 7 required…", or (with fixtures) a personal baseline with a usual range and the latest entry. Variables whose entries are mostly identical show "not enough variation to compare". Below, **Examples of future charts** are clearly labelled sample data. |
| 8 | 3:50 | Open **Profile**, then **Review data and consent preferences**. Turn **M3 · Sleep** off, tap **Done**, and return to **Insights**. | Only Sleep changes, to "Sleep is off in your data and consent preferences, so it is not analysed." Check-ins and Workload are unchanged. Turn Sleep back on: its results return, because the records were never deleted. |
| 9 | 4:30 | Close. | Summarise: local-only, encrypted, consent per input, honest data-sufficiency. Not clinical, not predictive, development data only. |

## Points to state

- Results compare the person only with their own recent entries (14 days, 7 entries minimum), one variable at a time.
- "Above" or "below" uses an experimental display band (|z| ≥ 1.0), not a validated threshold; it is withheld when the data have too little variation.
- The emulator's Keystore is software-backed; hardware-backed protection on a physical device has not yet been verified.

## Fallback plan

| Problem | Fallback |
|---|---|
| Emulator slow or not booting | Start it before the session (`flutter emulators --launch <id>`), or use a cold-booted snapshot. If it still fails, show the end-to-end test output: run phase 1 and phase 2 of `integration_test/insights_end_to_end_test.dart` and walk through the steps it asserts (section 2 of `testing_and_validation.md`). |
| No baseline appears in Insights | Expected with fewer than 7 entries per variable. Explain the "n of 7 required" state, or pre-load the synthetic fixtures (Preparation). |
| Saving says "not saved" | The app was started without `--dart-define=SENSE_DEV_STORAGE=1`, or not as a debug build. Restart with the define. The banner must be visible. |
| Save denied | The matching consent is off. Turn it on in **Profile → Review data and consent preferences** (this itself demonstrates the consent boundary). |
| A date change near midnight | Saving after midnight writes nothing and asks for review of the new day. Avoid demonstrating close to midnight, or present this as a feature. |
| No device at all | Use `flutter test` (host suite) and the architecture and methodology documents; state clearly that this is not a device demonstration. |
