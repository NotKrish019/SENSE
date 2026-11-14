# SENSE: Testing and Validation Report

This report records only results that were actually executed. The final full verification run completed on **2026-11-11** on the working tree described below, and every command in section 2 was run in that single sequential run. The source tree was check-summed immediately before and after the run and did not change during it.

**Evidence location.** The raw command logs of that run (one log per command, with exit codes) were written to a local, session-only working directory outside the repository. They are **not committed** to this repository. The commands below can be re-run to regenerate the evidence; results may differ on other machines.

**Code under test.** Branch `main` at commit `fe8cd77619f559a2ac35009627beb3737424ee4c` (three commits ahead of `origin/main`) plus uncommitted changes: Workload inline save feedback, and the Insights / personal-baseline integration with its degenerate-dispersion safeguard and tests.

**Environment.** macOS host; Flutter 3.47.9 (stable); JDK 21 (`jdk-21.0.13+9`) for Android builds; Android emulator `emulator-5554` (AVD `SENSE_API_36`, Android 16 / API 36, arm64). On the emulator the Keystore keys are **software-backed**: no result below establishes hardware-backed key protection.

---

## 1. Summary

| # | Check | Command (from `mobile/` unless noted) | Result | Exit code |
|---|---|---|---|---|
| 1 | Flutter host test suite | `flutter test` | **1,004 passed**, 0 failed | 0 |
| 2 | Plain-Dart assertion runner | `dart run test/run_all_tests.dart` | **17 passed**, 0 failed | 0 |
| 3 | Static analysis | `flutter analyze` | 5 issues (2 warnings, 3 infos), all pre-existing, none new | 1 |
| 4 | Web build | `flutter build web` | built `build/web` | 0 |
| 5 | Android debug build | `flutter build apk --debug` | built `app-debug.apk` | 0 |
| 6 | Android profile build | `flutter build apk --profile` | built `app-profile.apk` (95.9 MB) | 0 |
| 7 | Android release build | `flutter build apk --release` | built `app-release.apk` (58.0 MB) | 0 |
| 8 | Android instrumented tests (Kotlin, native key/lifecycle layer) | `cd android && ./gradlew connectedDebugAndroidTest` | **67 tests** finished, BUILD SUCCESSFUL | 0 |
| 9 | Encrypted database integration | `flutter test integration_test/encrypted_database_test.dart -d emulator-5554` | **21 passed** | 0 |
| 10 | Encrypted restart, phase 1 | `flutter test integration_test/encrypted_restart_test.dart -d emulator-5554 --no-uninstall --dart-define=SENSE_RESTART_PHASE=1` | 1 passed | 0 |
| 11 | Encrypted restart, phase 2 (after `adb shell am force-stop`) | `… --dart-define=SENSE_RESTART_PHASE=2` | 1 passed | 0 |
| 12 | K1 storage owner, development namespace and consent | `flutter test integration_test/sense_storage_test.dart -d emulator-5554 --dart-define=SENSE_DEV_STORAGE=1` | **6 passed** | 0 |
| 13 | K2 Workload persistence, phase 1 / phase 2 (process restart between) | `integration_test/workload_persistence_test.dart` with `SENSE_K2_PHASE=1` / `2` | 1 passed / 1 passed | 0 / 0 |
| 14 | K3 Check-in persistence, phase 1 / phase 2 | `integration_test/check_in_persistence_test.dart` with `SENSE_K3_PHASE=1` / `2` | 1 passed / 1 passed | 0 / 0 |
| 15 | K4 Sleep persistence, phase 1 / phase 2 | `integration_test/sleep_persistence_test.dart` with `SENSE_K4_PHASE=1` / `2` | 1 passed / 1 passed | 0 / 0 |
| 16 | End-to-end Insights, phase 1 / phase 2 | `integration_test/insights_end_to_end_test.dart` with `SENSE_E2E_PHASE=1` / `2` | 1 passed / 1 passed | 0 / 0 |
| 17 | Python research pipeline (repository root) | `python3 -m pytest` | **24 passed** | 0 |
| 18 | Whitespace check (repository root) | `git diff --check` | clean | 0 |

All device tests use `--dart-define=SENSE_DEV_STORAGE=1` where storage is needed (the isolated development namespace), run phase 1 with `--no-uninstall`, force-stop the app (`adb -s emulator-5554 shell am force-stop org.sense.mindpulse.dev`, exit 0 each time) and then run phase 2 in a new process. Each phase-2 test destroys the development namespace at the end and checks that no participant database, key envelope or Keystore alias exists.

Focused runs on the same tree, before the full run:

| Focused set | Command | Result |
|---|---|---|
| Insights and baseline | `flutter test test/personal_insights_test.dart test/insights_persistence_test.dart test/insights_screen_baseline_test.dart` | **37 passed** |
| Workload | `flutter test test/workload_save_integrity_test.dart test/workload_screen_persistence_test.dart test/workload_controller_test.dart test/workload_persistence_test.dart` | **61 passed** |

## 2. What the main suites cover

**Host tests (`flutter test`, 1,004).** Widget, accessibility and layout tests for every screen; consent gating and persisted consent; the encrypted-database provider (with a test-only fake key platform and disposable plain SQLite files through `sqflite_common_ffi`, which is confined to test code); the storage owner and its build policy. Also:
- **Controllers:** Check-in, Sleep and Workload controller tests (defaults, ranges, field mapping, provenance, same-day updates, consent denial, storage unavailable, failed saves, save locking, midnight handling).
- **Persistence:** repository-backed persistence tests through the real storage owner.
- **Insights:** the Insights mapping, data-sufficiency, consent and degenerate-dispersion tests.
- **Static guards:** analyzer-based tests that keep presentation code away from the database and repositories.

**Encrypted database integration (21, device).** The real Android Keystore and SQLCipher 4.20.0 path: key creation and wrapping, envelope handling, wrong-key and plaintext-file rejection, lifecycle leases, and the build policy refusing the participant database in a debug build.

**Persistence phases (K2 to K4, device).** Each drives the real controllers (K3 and K4 through the real screens) against the encrypted development database:
- before consent, a save is denied and nothing is written;
- after consent, the save is committed;
- after a force-stop, a new process finds the identical record (id, timestamps, provenance, values, date);
- an edit updates the same record;
- after revocation, the next save is denied and the earlier record remains.

K4 also checks that a night crossing midnight is stored under the wake-up date.

**End-to-end Insights (device).** The real app (`SenseApp`) on the development namespace, with reduced motion enabled for deterministic frames.
- **Phase 1:**
  - onboarding, then the Consent screen with M1, M3 and M4 turned on through the UI;
  - a check-in, a sleep entry and a workload entry saved through their screens;
  - a second Workload save tapped immediately after the first, which succeeds (the button is not covered);
  - a few earlier days written as labelled **synthetic development fixtures** through the same consent-gated repositories, so the sufficient-data state can be shown.
- **Phase 2 (new process):** the saved entries reach Insights.
  - The window is labelled "(development data)", and the sample charts are separate.
  - Mood (9 of 14 days) and mental demand (8 of 14) have baselines; sleep (5 of 7, including today's wake-up-date entry) shows insufficient observations.
  - Turning M1, M3 and M4 off one at a time hides only that modality, and turning each back on restores it.
  - The records remain after revocation.

## 3. Static analysis

`flutter analyze` reports exactly five issues, all present before the persistence and Insights work and all in files that this work did not change:

| Severity | Location | Rule |
|---|---|---|
| warning | `lib/domain/baseline_engine.dart:130` | `unnecessary_non_null_assertion` |
| warning | `lib/presentation/screens/design_showcase_screen.dart:10` | `unused_import` |
| info | `lib/presentation/screens/design_showcase_screen.dart:328` | `deprecated_member_use` (`withOpacity`) |
| info | `lib/presentation/widgets/calibration_progress_card.dart:28` | `deprecated_member_use` |
| info | `lib/presentation/widgets/insight_narrative_card.dart:20` | `deprecated_member_use` |

They are left unchanged on purpose: the baseline engine is used unchanged, and the others are unrelated UI files.

## 4. Mutation checks of the architecture guards

During development, deliberate violations were injected into real source files to confirm that the static guards detect them. Examples: a screen calling an access interface's `save` directly; a controller importing the consent preferences; the storage owner re-exporting a repository type or exporting without a `show` list; an unconnected screen referencing a storage controller; an FFI import in `lib/`. Each was caught by its intended guard, and the files were restored from verified backups with checksums. In the K3 milestone, one early attempt failed to take backups, and the injected lines were removed by exact text and re-verified (recorded in that milestone's review). These runs were exploratory and are not part of the automated suite. The guard-helper behaviour they rely on is pinned by `test/dart_source_guard_test.dart`.

## 5. Not tested or not established

- **Physical-device security.** No test ran on a physical device. Emulator keys are software-backed, so hardware-backed (TEE or StrongBox) key protection, key attestation and physical backup exclusion are **not verified** (see `../architecture/encrypted_local_storage.md`, section 14).
- **Profile build at runtime.** Its rejection of development storage is covered by host tests and native policy. The K1 milestone exercised the profile APK on the emulator only partially (UI evidence).
- **Rust CLI.** `cargo test --manifest-path backend-rust/Cargo.toml` was not run: `backend-rust/.cargo/config.toml` forces a Windows target.
- **Users.** No user study, usability evaluation or validation of the baseline interpretation was carried out.
- **Accessibility.** Covered by automated semantics tests only; no session with a real screen reader.
- **Platforms.** iOS was not built or tested (the repository has no iOS project). The web build is a preview without encrypted storage: the platform is unsupported, so the screens keep their prototype "not saved" behaviour and nothing is stored.

None of these results indicates production readiness or clinical validity.
