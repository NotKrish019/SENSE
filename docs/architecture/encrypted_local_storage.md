# Encrypted Local Storage: SQLCipher and Android Keystore (Milestone J, Stage 2)

Status: **infrastructure implemented, security-hardened (review findings M1–M4, L1, L3–L6), and verified on the Android emulator only.**
Milestone K1 (section 15) adds the app's single storage owner and repository-backed consent preferences. In a normal build nothing is opened; only a debug build with `--dart-define=SENSE_DEV_STORAGE=1` opens an isolated **development** namespace. The participant database is never opened by the app. Not approved for participant data: physical-device validation is outstanding (section 14).

This implements ADR-009 Decision J (SQLCipher-protected storage with Android
Keystore-backed key management, after a compatibility and security review). It
does not change any accepted decision, so `docs/decisions.md` is unchanged.

What this milestone does **not** do:

- Production Save handlers (Check-in, Sleep, Workload) and Settings Export/Erase are still not connected to any database. Since Milestone K1 the Consent screen saves preferences **only** to development storage, and only when that is explicitly enabled (section 15).
- `main.dart` creates the storage owner but, by default, opens nothing. Registering the native channel creates nothing. Only a debug build with the explicit development define opens the development namespace; the participant database is never opened by the app.
- Raw journal text is never persisted.
- No microphone, Health Connect or location permission was added. The release manifest declares no permissions.

---

## 1. SQLCipher version and dependency provenance

| Component | Version | Source | Integrity checked |
|---|---|---|---|
| SQLCipher for Android (engine, `net.zetetic.database.sqlcipher`) | **4.20.0** (`PRAGMA cipher_version` = `4.20.0 community`) | Maven Central `net.zetetic:sqlcipher-android:4.20.0` | AAR SHA-256 **`1e57857adfd29e2f5ddb4686e1e5ec6659920220d4bf182fdb5ef085b5577100`**, equal to Maven Central's published `.aar.sha256` and pinned in `android/gradle/verification-metadata.xml`. `.module` SHA-256 `92a4483933d8406e4de4698e28091c58845579895f897fc522d3ff05df6b37f8` (also equal to the published value). SHA-1 `0d7349d770f2a093a19b6772c440442f7a8ed5e2`. A PGP signature (`.asc`) is published but **not verified** (section 12). |
| `androidx.sqlite:sqlite` / `sqlite-android` | 2.7.0 | Google Maven | Version declared by the 4.20.0 POM; SHA-256 pinned in the verification metadata. |
| `sqflite_sqlcipher` (Dart API and Android channel glue) | **3.4.1**, pinned exactly | pub.dev; publisher **unverified**; MIT; repository `github.com/davidmartos96/sqflite_sqlcipher` | Reviewed source version **3.4.1**. Archive SHA-256 **`50d05fe0495ed96a85503d9850a49c0936502f44fdba96f403c97e4c9c7043e7`** equals pub.dev's `archive_sha256` and the hash in `pubspec.lock` (pub verifies it on download). The pub-cache copy is byte-identical to the audited source. |

### Why this combination

The data layer is written against sqflite's platform-independent `DatabaseFactory`/`Database` API: `SenseDatabase`, `LocalDataStore`, the repositories, the migrations and `LocalDataService`. `sqflite_sqlcipher` provides exactly that API over a SQLCipher engine. Using it means **no repository, schema or migration was rewritten**. `SenseDatabase.options()` was extracted so the encrypted opener reuses the exact schema-v2 callbacks.

`sqflite_sqlcipher` 3.4.1 declares `net.zetetic:sqlcipher-android:4.10.0@aar` (its 3.3.0 changelog entry; 3.4.x did not update the engine). It already uses the **current** library and namespace (`net.zetetic.database.sqlcipher`), not the legacy `net.sqlcipher` library. Moving to 4.20.0 is therefore a minor update of the same artifact, not an API migration:

- A `javap` diff of the public API used by the plugin (`SQLiteDatabase`, `SQLiteConnection`, `SQLiteDatabaseHook`, `DatabaseErrorHandler`, `DefaultDatabaseErrorHandler`) between 4.10.0 and 4.20.0 shows **no removed or changed members**. Only two read-only transaction methods were added.
- `mobile/android/build.gradle.kts` resolves every configuration of every Gradle project to 4.20.0 with `resolutionStrategy.eachDependency`. That includes the **plugin's own compile classpath**, so the plugin is compiled against 4.20.0, not swapped at runtime.
- The same block fails the build if the legacy `net.zetetic:android-database-sqlcipher` ever appears, so only one SQLCipher implementation can be packaged.

Verified packaging (debug and release):

- **Resolution:** `:app:debugRuntimeClasspath`, `:app:releaseRuntimeClasspath` and `:sqflite_sqlcipher:debugCompileClasspath` all resolve `net.zetetic:sqlcipher-android:4.10.0 -> 4.20.0` and `androidx.sqlite:sqlite:2.5.2 -> 2.7.0`.
- **Native libraries:** the release APK contains exactly one `libsqlcipher.so` per ABI (arm64-v8a, armeabi-v7a, x86_64).
- **Dex:** 0 `net/sqlcipher` (legacy) classes, 65 `net/zetetic/database` classes.

### Audited behaviour of the plugin, and how SENSE guards against it

| Plugin behaviour | Risk | Guard |
|---|---|---|
| If an open fails (**any** exception: wrong key, plaintext file, I/O), `Database.openWithFlags` retries with a hook running `PRAGMA cipher_migrate` and rethrows the original error if migration does not succeed. It also logs `"Opening db in <path> with PRAGMA cipher_migrate"` at debug level, unconditionally (no SQL, no key). | `cipher_migrate` only rewrites a file that decrypts under SQLCipher 1–3 settings **with the same passphrase**; SENSE databases are created by 4.x with a fresh random 256-bit passphrase, so it cannot apply. A plaintext file cannot be decrypted, so it is not rewritten either. | SENSE never passes the legacy path or any plaintext file to the driver: native and Dart both check the header first. On-device tests (L1): after a wrong-key open of the encrypted database **and** a keyed open of a plaintext file, the storage directory has exactly the same files with the same SHA-256 (no new, temporary, `-migrated` or changed files). The logged path is the app-private `no_backup` path, which contains no personal data; logcat is readable only by the app and privileged tools. The driver is **not** modified (residual risk: low; a patched fork could drop the retry and log). |
| An empty or null password opens with an empty key, which in SQLCipher means **unencrypted**. | A missing passphrase would silently create a plaintext database. | The provider accepts only a 64-character lowercase hex passphrase. After opening it requires a non-empty `PRAGMA cipher_version` **and** no plaintext header on disk; otherwise it closes the connection and returns `notEncrypted`. |
| Writable opens use the default `DatabaseErrorHandler`, which can delete database files on corruption. | A wrong key (`SQLITE_NOTADB`) could delete the database. | In 4.20.0, `DefaultDatabaseErrorHandler.onCorruption` returns early when `SQLiteDatabase.hasCodec()` (always true in SQLCipher), before any delete (bytecode inspected). Verified on device: wrong and empty keys leave the file present and unchanged. |
| `singleInstance` (the default) returns an already-open instance for a path and ignores new parameters, including the password. Native connections live in a **static map that outlives the Flutter engine**. | A second open of an open path does not re-check the key. | Resolved by the lifecycle owner (section 2a): one connection per database; every open runs the native policy and key gate first; while a connection is open, further opens are refused (`databaseAlreadyOpen` / `lifecycleBusy`) instead of returning the cached handle; and the key cannot be destroyed while any lease exists. `singleInstance` is kept **true** deliberately: with `false`, a connection left by a detached engine could never be found again. Only `secure_key_platform_io.dart` may import the driver (enforced by a test). |
| SQL statements and rows are logged only after `setDebugModeOn` / log level `sql` or `verbose`. The password is never logged. | SQL/row logging if debug mode is turned on. | SENSE never enables debug mode. Tests grep the app's logcat for the passphrase and sentinels: none found. |
| Its example's ProGuard rule `-keep class net.sqlcipher.**` targets the legacy namespace. | Obsolete rule. | Not copied. See section 11. |

The plugin package contains no binaries (`.so`, `.jar`, `.aar`). Its Android manifest is empty (no permissions).

---

## 2. Android Keystore key architecture

`android/app/src/main/kotlin/org/sense/mindpulse/security/`:

| File | Role |
|---|---|
| `SecureDatabaseKeyManager.kt` | Key generation (StrongBox with narrow fallback), wrapping/unwrapping, the fail-closed state machine with setup-marker recovery, the production-eligibility gate, security-level assessment, legacy classification, destruction. |
| `BuildPolicy.kt` | Explicit build policy from `BuildConfig.BUILD_TYPE` and `FLAG_DEBUGGABLE` (section 6). |
| `DatabaseLifecycleRegistry.kt` | Process-wide lifecycle owner: leases, open/destroy mutual exclusion, orphaned connections (section 2a). |
| `KeyEnvelope.kt` | Versioned envelope encoding and decoding. |
| `SecureDatabaseChannel.kt` | Method channel `org.sense.mindpulse/secure_database`: `inspect`, `openKey`, `commitOpen`, `release`, `destroy`. One instance per Flutter engine; all instances share **one process-wide worker thread** and the registry. |
| `MainActivity.kt` | Registers the channel; on `cleanUpFlutterEngine` marks that engine's leases orphaned. |

Wrapping key (alias `sense_db_wrapping_key_v1`), provider `AndroidKeyStore`:

- AES, 256-bit, `PURPOSE_ENCRYPT | PURPOSE_DECRYPT`, block mode GCM, padding none, transformation `AES/GCM/NoPadding`, 128-bit tag.
- Non-exportable: Android Keystore keys never leave the Keystore; only `Cipher` operations are possible.
- `setRandomizedEncryptionRequired(true)`: **the Keystore generates a fresh random 12-byte IV for every encryption** (an app-supplied IV is refused), and decryption uses `GCMParameterSpec(128, iv)` with the stored IV. On-device test: 25 encryptions produced 25 distinct IVs and ciphertexts.
- StrongBox is requested when `FEATURE_STRONGBOX_KEYSTORE` is advertised. The key falls back to the default (TEE) Keystore **only** when (a) `StrongBoxUnavailableException` appears in the cause chain (`strongBoxUnavailable`), or (b) a `ProviderException` wraps the Keystore's own `android.security.KeyStoreException` (`strongBoxProviderRejected`; matched by class name, because the class is public only from API 33). Any other error (invalid parameters, missing algorithm, I/O, unexpected runtime errors) fails initialization without a fallback. A failed StrongBox attempt leaves no alias. The fallback reason is reported (`strongBoxFallback`), and the resulting key's **real** level (KeyInfo) is what the release gate evaluates, so a fallback can never produce a software key for the participant database. StrongBox is optional, never assumed; a successful StrongBox key has **not** been validated (no compatible hardware tested).
- No user-authentication or unlocked-device binding (the database must open without a prompt). See limitations.

## 2a. Lifecycle ownership (hardening M1, L2)

One authoritative owner coordinates key initialization, key unwrapping, database opening, connection registration, closing and destruction.

**Native (process-wide): `DatabaseLifecycleRegistry`.** One lease per storage directory (participant, or one test namespace), shared by every Flutter engine in the process:

```
(none) --openKey: beginOpen--> OPENING --commitOpen--> OPEN --release--> (none)
                                   \--release (failed open)--> (none)
```

- The lease is taken **before** the key is resolved or generated; a key failure releases it.
- `destroy` is refused while any lease exists (`openInProgress`, `databaseOpen`, `orphanedConnection`); while a destroy runs, opens are refused (`destroyInProgress`).
- When an engine is detached (`cleanUpFlutterEngine`), its leases become **orphaned, never released**: the driver keeps native connections in a static map, so the connection may still be open. Destruction stays refused. A later engine may **adopt** the lease only after the full policy and key gate succeeds again; a failed adoption restores the orphaned lease. An orphaned lease cannot be released by anyone.
- Only the owning engine (channel instance) can commit or release its lease; repeated release is a no-op.

**Dart (per isolate): the provider's lifecycle owner.** Every `EncryptedDatabaseProvider` for the same platform and namespace shares one owner, which serialises `open`, `close` and `destroyKeyAndDatabase` (FIFO). The owner:

- Registers the connection (native `commitOpen`) before the serialised section ends.
- On every failure after the key was issued, closes any partial connection and releases the lease.
- Returns `databaseAlreadyOpen` (no second handle, no gate-free reuse) while its connection is open.
- Reconciles a connection that a caller closed directly: the lease is released on the next lifecycle call.
- `close()` is idempotent.

**Known edge:** a Dart hot restart (debug only) keeps the native lease of the old isolate; the test namespace then reports `lifecycleBusy` until the app process restarts. This fails safe.

## 3. Passphrase generation and wrapping

- 32 bytes from `java.security.SecureRandom`, generated **once**, at first initialization.
- Persisted only inside the envelope, encrypted under the wrapping key. Never in SharedPreferences, SQLite, JSON, Dart source, logs, analytics or Git.
- Sent to Dart only in the `openKey` success reply, as a 64-character **lowercase hex String**. The driver passes it to `SQLiteDatabase.openDatabase(path, String password, ...)`, which converts it with `String.getBytes("UTF-8")` (verified in 4.20.0 bytecode) and keys SQLCipher with it as a **passphrase**: SQLCipher 4 key derivation, PBKDF2-HMAC-SHA512, `PRAGMA kdf_iter` = 256000 (observed).
- Verified on device: the uppercase form, the raw-key form `x'<hex>'`, a trailing space or a single dropped character all fail. Only the exact bytes open the database.
- After initialization the envelope is read back and unwrapped, and compared with the generated passphrase (constant-time) before success is reported.

## 4. Envelope format and storage

`sense_db_key_v1.envelope`, 70 bytes, big-endian:

| Offset | Bytes | Field |
|---|---|---|
| 0 | 4 | magic `SNKE` |
| 4 | 1 | format version `1` |
| 5 | 1 | algorithm `1` (AES-256-GCM, Android Keystore key) |
| 6 | 1 | IV length `12` |
| 7 | 1 | tag length `16` |
| 8 | 2 | ciphertext length including tag `48` |
| 10 | 12 | IV |
| 22 | 48 | ciphertext (32-byte passphrase) followed by the GCM tag |

- The 10-byte header is GCM additional authenticated data. Decoding accepts only this exact header, so a new format needs explicit migration code.
- The wrapping key is never in the envelope.
- Writes use `android.util.AtomicFile` (`startWrite` → `finishWrite`, which fsyncs and replaces atomically; `failWrite` on error), followed by a best-effort fsync of the directory (`Os.open` + `Os.fsync`) so the rename is durable.
- An interrupted write's `.new` file is not treated as an envelope.

### Setup marker (hardening L3)

`sense_db_setup_v1.pending` (same directory, AtomicFile + directory fsync): magic `SNSU`, version `1`, creation time (ms), key alias. It is written **before** the key is generated and removed only when the lifecycle owner commits a successfully opened and verified database (or by `destroy`). It proves which interrupted setup created what:

| Killed after | State left | Next open |
|---|---|---|
| marker write | marker | marker removed, fresh initialization |
| key generation | marker + alias | alias deleted **only if** its Keystore creation date is not older than the marker (2 s tolerance) and the marker names this alias, then fresh initialization; otherwise `orphanedKey` |
| envelope write | marker + alias + envelope | the same key and envelope are reused: `firstInitialization: true`, **not** reported as `recoveredMissingDatabase` |
| initial database creation | marker + alias + envelope + (partial) database | the same key opens the database; SQLite rolls back the interrupted transaction and the schema is created; marker removed on commit |

A marker never permits deleting a key while a database exists or replacing a key for an existing database; with a database present the normal table applies. A corrupt marker is treated as absent.

## 5. Database path and backup exclusion

| File | Location |
|---|---|
| `sense_encrypted_v1.db` (+ `-wal`, `-shm`, `-journal`) | `Context.noBackupFilesDir` |
| `sense_db_key_v1.envelope` | `Context.noBackupFilesDir` |

- Paths are computed from `noBackupFilesDir` each time. No absolute device path is stored.
- On the emulator, files are mode `0600`, owned by the app UID, under `/data/user/0/org.sense.mindpulse.dev/no_backup/`.
- `noBackupFilesDir` and the cache directories are outside every backup domain (platform behaviour per the Android documentation; **not** yet physically verified for SENSE).
- Debug builds (only) accept a **test namespace**: alias `sense_db_wrapping_key_v1__<ns>`, directory `no_backup/test_namespaces/<ns>/`, legacy path `<that dir>/legacy/mindpulse_secure.db`. Profile and release builds reject it (natively `invalidArgument`; in Dart `testNamespaceUnavailable`). Tests therefore never touch the real key or files.

### Backup and data-extraction policy (hardening M3)

Target SDK 36. No app data leaves the device:

| Setting | Effect |
|---|---|
| `android:allowBackup="false"` | Disables cloud backup and `adb backup` of the app. For apps targeting API 31+ it does **not** stop device-to-device transfer by itself. |
| `android:dataExtractionRules="@xml/data_extraction_rules"` (Android 12+) | `<cloud-backup disableIfNoEncryptionCapabilities="true">` and `<device-transfer>` each exclude **every** domain with `path="."`: `root`, `file`, `database`, `sharedpref`, `external`, `device_root`, `device_file`, `device_database`, `device_sharedpref`, plus the legacy `mindpulse_secure.db` and its `-journal`/`-wal`/`-shm` explicitly. No `<include>`. |
| `android:fullBackupContent="@xml/full_backup_content"` (Android 11 and earlier) | The same exclusions, as a second line of defence. |

Because whole domains are excluded, storage added in the future is excluded by default. Verification status:

| Check | Status |
|---|---|
| Configuration implemented | Done |
| Source configuration test (`test/android_security_config_test.dart`) | Passing |
| Merged manifest of the built debug, profile and release APKs (`aapt2 dump xmltree`) | Verified: `allowBackup=false` and both rule resources present in all three |
| Physical cloud-backup test | **Not done** |
| Physical device-to-device transfer test | **Not done** |

Physical verification plan (a device signed into a Google account, Android 12+ and one Android ≤ 11 device): install a release build, create test files in `files/`, `databases/`, `shared_prefs/` and `no_backup/`; `adb shell bmgr enable true`; `adb shell bmgr backupnow org.sense.mindpulse.dev` (expect: backup not allowed / nothing transported); `adb shell bmgr list transports`, and confirm in Settings › Google › Backup that the app has no data; then a device-to-device transfer (Android 12+ setup wizard or `adb shell bmgr` D2D test transport) to a second device and confirm that no SENSE files arrive and the restored install starts clean.

## 6. Hardware security-level detection

`KeyInfo` from `SecretKeyFactory.getKeySpec`:

- API ≥ 31: `getSecurityLevel()` → `STRONGBOX`, `TRUSTED_ENVIRONMENT`, `UNKNOWN_SECURE` (reported as `hardwareUnspecified`), `SOFTWARE`; anything else → `unknown`.
- API < 31 (minSdk 24): `isInsideSecureHardware()` → `hardwareUnspecified` or `software`.
- An exception → `unknown`.

This is the **Keystore's self-report, not attestation**. An emulator's Keystore implementation can report a hardware level. So:

- `hardwareBackedEvidence = reportsSecureHardware && !emulator`. The emulator is recognised from `Build.HARDWARE` (`ranchu`/`goldfish`), fingerprint, product and model.

### Production-eligibility policy (hardening M2)

`FLAG_DEBUGGABLE` alone is not the decision: Flutter's `profile` build type is created with `initWith(debug)`, so profile APKs are debuggable. `BuildPolicy` combines `BuildConfig.BUILD_TYPE` (`buildFeatures.buildConfig = true`) with `FLAG_DEBUGGABLE`:

| Build | Participant database | Test namespaces |
|---|---|---|
| `debug` (debuggable) | **refused**: `buildNotProductionEligible`, before any file or key is touched | allowed (software keys allowed; never production eligible) |
| `profile` (debuggable or not) | **refused** | refused |
| `release`, debuggable | **refused** | refused |
| `release`, not debuggable | only with hardware evidence from the key's **real KeyInfo**, checked at creation **and on every open**; otherwise `insecureKeyStorage` (a new key is rolled back; an existing key, envelope and database are left untouched) | refused |
| unknown build type | **refused** | refused |

`productionEligible` is true only for the participant database in an eligible build with hardware evidence. The Dart provider enforces the same policy independently: it uses Flutter's compile-time mode (`kReleaseMode`/`kProfileMode`) and refuses the participant database outside release mode **before any native call**, and in release mode it opens a database only if the native reply says `productionEligible`, reports hardware evidence and a hardware level, and is not an emulator. A successful key operation alone is never enough. There is no software-key fallback.

**Emulator result (emulator-5554, Android 16 / API 36, `sdk_gphone64_arm64`): `SOFTWARE`, emulator = true, hardwareBackedEvidence = false, productionEligible = false.** In a release build on this emulator, `openKey` returned `insecureKeyStorage` with no passphrase, and afterwards no database, envelope or key existed. This is an emulator-only result; hardware backing has **not** been validated.

## 7. Fail-closed states

Checked in this order (after the lifecycle lease was granted):

1. Build policy (participant database) → `buildNotProductionEligible`. Nothing is touched.
2. A plaintext SQLite header at the encrypted path → `plaintextDatabaseAtEncryptedPath`. Nothing is created.
3. A valid setup marker for this alias → the interrupted-setup table in section 4.
4. Then the table below. "Database present" means the main file **or** its `-wal`/`-journal` exists.

| Database | Envelope | Keystore alias | Result |
|---|---|---|---|
| Absent | Absent | Absent | First-time initialization. On any failure, removes only what it created, and only while no database exists (`initializationFailed`). |
| Present | Present | Present | Unwrap and open. |
| Present | Absent | Present | `envelopeMissingForExistingDatabase`. Never regenerated. |
| Present | Present | Absent | `keyMissingForExistingDatabase`. No key is generated. |
| Present | Absent | Absent | `keyAndEnvelopeMissingForExistingDatabase`. Needs investigation. |
| Absent | Present | Present | (No setup marker: setup had completed.) Unwrapped first. If it authenticates, continues with `recoveredMissingDatabase: true` (a new empty database is created with the **existing** key); otherwise fails. Callers must treat this flag as an alert. |
| Absent | Present | Absent | `envelopeWithoutKey`. |
| Absent | Absent | Present | `orphanedKey` unless the setup marker proves the alias came from the interrupted setup (section 4). Otherwise the alias is not overwritten (same creation date, still unwraps its original envelope). |

Other failures:

| Code | Cause |
|---|---|
| `envelopeMalformed` | Wrong length, header or version. |
| `envelopeAuthenticationFailed` | GCM tag failure: tampering, or a different key under the alias. |
| `buildNotProductionEligible` | Debug, profile, debuggable-release or unknown build asking for the participant database. |
| `testNamespaceUnavailable` | A test namespace outside a debug build (Dart). |
| `insecureKeyStorage` | Participant database without hardware evidence (SOFTWARE, UNKNOWN, emulator, or a reply that is not production eligible). |
| `databaseAlreadyOpen` | This database already has an open connection (one owner). |
| `lifecycleBusy` | The native registry refused (`refusal`: `openInProgress`, `databaseOpen`, `orphanedConnection`, `destroyInProgress`). |
| `keystoreError` | Keystore failure. |
| `invalidKeyMaterial` | Bad passphrase format or unexpected path in the native reply. |
| `malformedReply` | A native reply of the wrong shape or types (missing/unknown status, non-string failure, missing or malformed lease id). |
| `storageError` | The database file could not be inspected (file-system error). |
| `databaseKeyRejected` | SQLCipher reported "file is not a database". |
| `databaseOpenFailed` | Any other open failure, including `Error`s thrown by the driver. |
| `notEncrypted` | Not a SQLCipher engine, a plaintext header after opening, or a failing post-open verification. The connection is closed. |
| `unsupportedPlatform` | Not Android. |
| `platformError` | The channel failed or threw (including `StateError` for an empty reply). |

`open()` never throws: every failure is an `EncryptedDatabaseFailed`, and every failure after a key was issued closes any partial connection and releases the lease. `inspect()`, `close()` and `destroyKeyAndDatabase()` throw only typed errors: `EncryptedStoragePlatformException(code)` or `EncryptedDatabaseLifecycleError(reason)` (a `StateError`). No error carries native exception messages, key material or the passphrase.

None of these regenerates a key, resets or deletes a database, or retries as a fresh initialization. Results, errors and `toString()` never contain the passphrase.

## 8. Legacy plaintext database

`mindpulse_secure.db` (legacy name; **not** encrypted) is located with `context.getDatabasePath`.

- It is classified from at most its first 16 bytes, read-only, as `absent`, `plaintextSqlite`, `empty` or `unrecognized`, and reported in every result.
- It is never opened with SQLCipher, never passed to `cipher_migrate`, never renamed, moved, overwritten or deleted, and its content is never migrated.
- Verified on device: a plaintext legacy database holding a row was byte-for-byte unchanged (SHA-256 and mtime) after the encrypted database was created beside it. Its row is absent from the encrypted files, and no `legacy_v1_*` tables were created.
- Any future plaintext-to-encrypted migration needs its own design and verification.

## 9. Key destruction

`EncryptedDatabaseProvider.destroyKeyAndDatabase()`:

1. Runs inside the lifecycle owner. Throws `EncryptedDatabaseLifecycleError` (a `StateError`) and changes nothing if a connection from **any** provider, isolate or engine of the process is open or opening, or an orphaned connection may exist; natively the registry refuses with `busy`. Debug/profile builds cannot destroy the participant key.
2. Deletes the envelope.
3. Deletes the Keystore alias.
4. Deletes the database and its `-wal`, `-shm` and `-journal` files and the setup marker (best effort).
5. Returns a report: `envelopeDeleted`, `keyDeleted`, files deleted and remaining.

This is **cryptographic erasure**. Once the alias is gone, the passphrase cannot be recovered from any copy of the envelope, so any remaining copy of the ciphertext is unreadable. Verified on device:

- A retained copy of the envelope can no longer be unwrapped.
- A retained copy of the database written back to the path fails closed (`keyAndEnvelopeMissingForExistingDatabase`) and no key is generated for it.
- A new key created afterwards cannot open the retained copy.

It is **not** physical sanitization. Flash wear-levelling, filesystem journals and snapshots, earlier copies and device backups outside `noBackupFilesDir` may still hold old ciphertext blocks. Those blocks are unreadable without the destroyed key, but are not guaranteed to be overwritten. The operation is not connected to Settings or to `LocalDataService.eraseAllUserData` (logical, row-level erase), and wiring the two together is future work.

## 10. Known limitations

- **Passphrase exposure in memory.** The driver API takes a `String`, so the passphrase crosses the platform channel as an immutable Dart `String` and Java `String`, plus channel codec buffers. Native byte and char buffers are zeroed. **Immutable Strings cannot be reliably zeroed**, and copies may persist in the Dart and Java heaps until garbage collection. The Dart provider keeps no reference after opening. Avoiding this would need a driver that unwraps the key natively.
- **No attestation.** Hardware backing is the Keystore's self-report, plus an emulator heuristic. Verifying the key-attestation chain against Google's hardware attestation root is future work.
- **No user-authentication binding.** Anyone who can run code as the app on an unlocked or booted device can unwrap the key. This is inherent to an app that must open its database without a prompt.
- **PGP signatures are not verified.** Gradle verification uses SHA-256 only (section 12). Maven Central publishes a signature for the SQLCipher AAR; trusting it needs Zetetic's signing-key fingerprint obtained out of band, which has not been done.
- **Plugin publisher is unverified on pub.dev.** It is mitigated by the exact version pin, the lockfile hash, the source audit and the engine pin. A future plugin update must be re-audited.
- **Driver retry and log** (`cipher_migrate`, path log line) remain in the unmodified driver (section 1, residual risk low).
- **Hot restart** (debug) leaves a native lease held until the app restarts (section 2a; fails safe).
- **Running Gradle directly** (for example `./gradlew :app:connectedDebugAndroidTest`) makes Flutter's Gradle plugin add a synthetic CMake build. AGP then auto-installed **CMake 3.22.1** into the Android SDK on the development machine (2026-11-09). Builds through the `flutter` tool do not.
- **Instrumented-test dependencies** are pinned to `androidx.test:runner:1.3.0`, the line the `integration_test` dev plugin already uses. `androidx.test:core` 1.3.0 cannot merge at targetSdk 36.

## 11. R8 / ProGuard

No app-level rules were added. `sqlcipher-android` 4.20.0 ships consumer rules (`proguard.txt` inside the AAR) that apply automatically:

```
-keep,includedescriptorclasses class net.zetetic.database.** { *; }
-keep,includedescriptorclasses interface net.zetetic.database.** { *; }
-keepclasseswithmembernames class net.zetetic.database.** { native <methods>; }
-dontwarn net.zetetic.database.**
-keepattributes *Annotation*
```

Release build checks:

- R8 ran (`mapping.txt`, 42,091 lines). All 65 `net.zetetic.database` classes keep their names.
- All 30 `native*` methods on `SQLiteConnection` are present. The JNI callback classes `SQLiteCustomFunction` and `SQLiteDebug$PagerStats` are present.
- SENSE's key-manager classes are renamed. That is safe: they are referenced directly, never by reflection.
- The legacy `-keep class net.sqlcipher.**` rule would not apply to this library and was not added.

Release **runtime** check:

- An R8-shrunk release build of a scratch copy (probe entry point; release signing was not configured in the project, and the scratch APK was signed locally with the debug keystore) was installed on the emulator.
- `libsqlcipher.so` loaded with no `UnsatisfiedLinkError` or `NoSuchMethodError`. `cipher_version` returned `4.20.0 community`.
- The file on disk had no plaintext header and no sentinel. Reopening read the sentinel, `integrity_check` returned `ok`, and a wrong key was rejected with the file kept.
- A test namespace was rejected, and `openKey` failed closed with `insecureKeyStorage` and rolled back.
- The real SENSE release APK, signed the same way in scratch, launched and completed Splash → Onboarding → Consent → Home with no fatal errors.

## 12. Gradle dependency verification (hardening M4)

`android/gradle/verification-metadata.xml` (`verify-metadata` true, `verify-signatures` false) pins the **SHA-256 of every artifact and metadata file** the build resolves: 745 components, 1,374 artifacts. It was generated with `./gradlew --write-verification-metadata sha256` for `:app:assembleDebug`, `:app:assembleProfile`, `:app:assembleRelease` and `:app:assembleDebugAndroidTest` (Flutter `--config-only` regenerated per mode, so release/profile exclude the `integration_test` dev plugin), first on the warm development cache and again on an empty `GRADLE_USER_HOME` (+5 entries). A cold-cache `flutter build` then still needed 3 BOM files that only the very first settings-plugin resolution fetches (`org.jetbrains.kotlin:kotlin-gradle-plugins-bom:2.2.20` `.pom`/`.module`, `org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.8.0` `.pom`); they were found with Gradle's lenient mode on another empty cache, checked against Maven Central's `.sha1`, and added by hand. It applies to `flutter build` and `flutter test` on Android as well, because Flutter runs this Gradle build. No `trusted-artifacts` rules.

Review of the entries (2026-11-09): each artifact's hash in the metadata was recomputed from the Gradle cache, and the cached file was compared with what its upstream repository publishes. Of the first 1,366: 1,326 matched the published `.sha1` (Maven Central, Google Maven, Gradle Plugin Portal), 8 Kotlin 1.9.20 files matched the published `.md5` (no `.sha1` published), 8 Kotlin-multiplatform/AAR variant files matched the `.sha1` at the URL declared in their `.module`, and the 24 Flutter engine artifacts (`download.flutter.io` publishes no checksums) were re-downloaded and are byte-identical. The 8 later additions all matched Maven Central's `.sha1`. **0 mismatches.** The only SQLCipher entry is `net.zetetic:sqlcipher-android:4.20.0` (AAR SHA-256 `1e57857a…7100`, equal to Maven Central's own `.sha256`); `android-database-sqlcipher` is absent.

Negative checks (scratch copy of the project, same Gradle cache):

| Change | Result |
|---|---|
| SQLCipher AAR SHA-256 altered in the metadata | build fails: `Dependency verification failed … sqlcipher-android-4.20.0.aar` |
| Gradle pin changed to an unreviewed 4.10.0 | build fails: verification failed for `sqlcipher-android-4.10.0.aar` / `.module` |
| Legacy `net.zetetic:android-database-sqlcipher` requested | build fails: `Legacy SQLCipher … is not allowed` |
| Unchanged | passes |

Clean resolution: `flutter build apk` in release, debug and profile mode of a scratch copy with an **empty `GRADLE_USER_HOME`** (strict verification) downloaded every artifact afresh and passed verification. The first such attempt, before the 3 BOM entries were added, failed closed with `Dependency verification failed`.

Maintenance: any dependency, plugin, AGP, Kotlin or **Flutter SDK** change (the engine artifacts are versioned by engine hash) makes verification fail until the metadata is regenerated with `./gradlew --write-verification-metadata sha256 <the tasks above>` and the new entries are reviewed the same way. Running other Gradle tasks (for example `lint`) needs the same. Limitations: SHA-256 only, no PGP; the first recording trusted the local cache, which the upstream comparison above then confirmed.

## 13. Test evidence (2026-11-09, emulator-5554, Android 16 / API 36, arm64)

| Suite | Where | Result |
|---|---|---|
| A. Key manager, real Android Keystore: `SecureDatabaseKeyManagerTest.kt` | emulator | **20 / 20 passed** |
| Build policy (M2), manager and channel paths: `BuildPolicyTest.kt` | emulator | **18 / 18 passed** |
| Lifecycle registry and two-engine channel tests (M1): `DatabaseLifecycleTest.kt` | emulator | **9 / 9 passed** |
| Interrupted first initialization (L3): `InitializationRecoveryTest.kt` | emulator | **10 / 10 passed** |
| StrongBox fallback (L4): `StrongBoxFallbackTest.kt` | emulator | **10 / 10 passed** |
| B, C and D. SQLCipher, on-disk encryption, hardening on device: `integration_test/encrypted_database_test.dart` | emulator | **21 / 21 passed** |
| Restart across a new app process: `integration_test/encrypted_restart_test.dart`, phases 1 and 2 | emulator | **passed** |
| Dart provider: fail-closed logic, lifecycle owner, build-mode policy, typed errors: `test/encrypted_database_provider_test.dart` | host VM | **76 / 76 passed** |
| Backup policy and dependency-verification configuration: `test/android_security_config_test.dart` | host VM | **8 / 8 passed** |
| Real **profile** APK (scratch probe): participant database and test namespaces | emulator | refused in Dart (`buildNotProductionEligible`, `testNamespaceUnavailable`) and natively (`buildNotProductionEligible`, `invalidArgument`); nothing created |
| Real **release** APK (scratch probe, signed locally with the debug keystore) | emulator | participant database refused on real key metadata (`insecureKeyStorage`, level `software`, emulator) and rolled back; test namespaces refused |
| Web boundary, provider in Chrome (scratch copy, Stage 2) | Chrome | passed: `unsupportedPlatform` |

Emulator key evidence: `reportedSecurityLevel=SOFTWARE emulator=true hardwareBackedEvidence=false sdk=36`; the real StrongBox request on this emulator falls back with `strongBoxUnavailable`, level `SOFTWARE`. **No test here is hardware-backed validation.**

Group A covers:

- First initialization, and reopening with the same passphrase.
- The envelope contains no form of the passphrase.
- 25 distinct IVs.
- Tampering with any IV or ciphertext byte → `envelopeAuthenticationFailed`; any header byte → `envelopeMalformed`. Nothing is deleted.
- A different key under the alias fails closed.
- Every row of the state table, including a WAL-only database.
- A plaintext file at the path is rejected unchanged.
- Legacy classification, with the file unchanged.
- Destruction and retained copies.
- The release policy, with rollback.
- No key material in logcat.

Groups B and C cover:

- `4.20.0 community`; schema v2; `integrity_check` = `ok`; `cipher_integrity_check` empty.
- Wrong and empty keys rejected, with the file unchanged.
- The exact passphrase interpretation.
- Close and reopen.
- v1 → v2 migration over SQLCipher.
- Consent-gated writes, transaction commit and rollback, append-only history, export, and erase (fresh identity, preferences OFF).
- Plaintext files refused unchanged; no automatic plaintext migration.
- The legacy database preserved.
- In both rollback-journal and WAL modes: a sentinel absent from the main file, `-wal`, `-shm` and `-journal` in UTF-8, UTF-16LE and UTF-16BE, both while open and after checkpoint and close. No plaintext header. The correct key reads it and a wrong key cannot.
- Destruction.
- Neither the passphrase nor a sentinel in logcat.

Hardening tests cover:

- **M1 lifecycle:** destroy during an open (Dart: queued and then refused; native: `openInProgress`), destroy while open, destroy through a second provider and through a second engine (separate channel instances), simultaneous opens (exactly one connection; 50 rounds of 16 threads on the registry), simultaneous open and destroy (never both proceed; 200 rounds), open immediately after destroy, failed opens release the lease, repeated close, directly closed connections reconciled, a live connection's key and envelope never deleted, orphaned leases (engine detached) block destruction and are adopted only through the gate, malformed lease ids rejected. Concurrency uses barriers and completers, not sleeps.
- **M2 policy:** debug, profile, debuggable-release and unknown builds refused for the participant database even with a hardware level; release accepted with TEE, StrongBox and unspecified-secure metadata and refused with SOFTWARE, UNKNOWN, emulator-TEE and non-eligible replies, both at creation and on reopen; the real KeyInfo path; test namespaces refused outside debug; a cached connection never handed out without the gate; the channel path with the real `BuildConfig` and with injected profile/release policies.
- **L3 recovery:** simulated process death after the setup marker, after key generation and after the envelope write, and during initial database creation (on device, with a schema-creation failure and with an empty file); an alias older than the marker, a marker for another alias and a corrupt marker never permit deletion; a key is never replaced for an existing database.
- **L4 StrongBox:** used when available; `StrongBoxUnavailableException` (direct or wrapped) and a genuine Keystore provider rejection fall back; other errors and a TEE failure after fallback fail initialization and roll back; the release gate still applies to the fallback key; the real StrongBox request on this emulator.
- **L5 errors:** `StateError` from the channel, malformed replies (status, failure type, lease id), file-system errors before and after opening, an `Error` from the opener and from post-open verification, a failing lease release during cleanup, and typed `inspect`/`destroy` failures; every failed open closes its connection and releases its lease.
- **L1 driver:** after a wrong-key open and a keyed open of a plaintext file, the storage directory's files and SHA-256 hashes are unchanged.

## 14. Outstanding before any participant data

1. **Physical-device validation.** Run the instrumented and integration suites on at least one physical Android device with a TEE, and one with StrongBox if available. Confirm a hardware security level, `hardwareBackedEvidence = true`, a successful StrongBox key, that a signed non-debuggable release build opens the participant database (and a profile build does not), restart persistence and wrong-key rejection on real hardware.
2. **Physical backup verification** (cloud backup and device-to-device transfer, section 5).
3. Decide on key attestation (recommended) and on user-authentication binding.
4. Verify the SQLCipher AAR's PGP signature against an out-of-band key fingerprint and add it to the verification metadata.
5. Connect production Save handlers and Settings Export/Erase (including combining logical erase with key destruction, through the lifecycle owner). The storage owner and persisted consent exist since Milestone K1 (section 15); the Save handlers are the next milestone. Enabling participant storage at startup is a separate, explicit decision after items 1 to 4.
6. Decide whether to migrate any legacy plaintext database. This needs a separate design.

---

## 15. Application storage owner and development storage (Milestone K1, 2026-11-10)

**Storage owner.** `mobile/lib/data/local/sense_storage.dart` defines `SenseStorage`, a `ChangeNotifier` created once by `SenseApp` (`lib/main.dart`; not a global or static) and passed down with `SenseStorageScope` (an `InheritedNotifier`, `lib/presentation/widgets/sense_storage_scope.dart`). It is the only code outside `encrypted/` that uses `EncryptedDatabaseProvider` (enforced by a static test). It:

- opens through `EncryptedDatabaseProvider`, so the existing per-isolate lifecycle owner, the native lease, the native build policy, the Keystore checks and the plaintext-header checks all apply unchanged; it adds no second lifecycle system;
- binds the existing repositories with `LocalDataStore` (schema v2 through `SenseDatabase.options()`), then calls `LocalProfileRepository.ensureActive()`;
- holds the one connection and exposes `StorageReady { target, database, store, profile, productionEligible, cipherVersion, security }`; a second open of the same target returns the same state, and an independent provider for the same database gets `databaseAlreadyOpen` from the lifecycle owner;
- serialises open and close; `close()` releases the lease and is repeatable; the app closes it when the engine detaches (`AppLifecycleListener.onDetach`) and on dispose;
- reports typed states: `StorageUnavailable(reason, failureCode)` with reasons `developmentStorageDisabled`, `participantStorageNotEnabled`, `buildNotEligible`, `unsupportedPlatform` (expected policy states) and `openFailed`, `profileUnavailable` (failures); `StorageOpening`; `StorageReady`; `StorageClosed`. Failure detail is never shown to people;
- never falls back: no plaintext SQLite, no retry with another engine, no reset of a database that fails to open, and no access to the legacy `mindpulse_secure.db`.

This is the one top-level file in `lib/data/local/` that imports Flutter, and only `package:flutter/foundation.dart` (for `ChangeNotifier`); the records, schema, repositories, store and export/erase service remain pure Dart (enforced by a static test).

**Startup policy (unchanged build policy, nothing weakened).**

| Build | `SENSE_DEV_STORAGE` | Startup opens | State |
|---|---|---|---|
| debug | not set (default) | nothing | `developmentStorageDisabled`; preferences in memory, as before |
| debug | `1` | the development namespace | `StorageReady(development)`, `productionEligible = false` |
| profile | any | nothing | `buildNotEligible` (also refused by the provider and natively) |
| release | any | nothing | `participantStorageNotEnabled` (participant data collection is not connected) |

`open(StorageTarget.participant)` exists for later milestones: in debug and profile builds it is refused by the provider before any key call (`buildNotProductionEligible`) and by the native gate; in a release build it still requires a hardware-backed key.

**Development namespace.** `--dart-define=SENSE_DEV_STORAGE=1` (`kSenseDevStorageDefine`) is honoured only in a debug build (`SenseStoragePolicy.developmentStorageEnabled = debug && define`). The namespace `dev_storage` reuses the existing debug-only test-namespace mechanism, so it has its own directory (`no_backup/test_namespaces/dev_storage/`), its own Keystore alias (`sense_db_wrapping_key_v1__dev_storage`), its own lifecycle lease and setup marker, and its own destroy. It is never production eligible (the provider forces `productionEligible = false` for namespaces, and the owner checks it again). Profile and release builds reject it in Dart (owner and provider) and natively (`BuildPolicy.testNamespacesAllowed`). While it is enabled every route shows the persistent label **"DEVELOPMENT DATA — NOT FOR PARTICIPANTS"**. Development data is for development only: on an emulator its key is software-backed.

**Persisted consent.** `ConsentPreferences` (`lib/core/state/consent_preferences.dart`) keeps its shared instance and its six modalities (M1 to M6, mapping unchanged) and gains an optional connection to the owner (`attach`):

- By default, and whenever storage is disabled by policy, it is `memoryOnly`, with the original wording ("kept only while the app is open").
- When storage is ready it loads the `ConsentRepository` snapshot, which replaces whatever was in memory (the database is authoritative), and becomes `persisted`. While loading, changes are refused (`notReady`).
- In `persisted`, each change appends exactly one event through `ConsentRepository.recordChange` (append-only; nothing is updated or deleted) and the new value is shown **only after** that write succeeded. Turning a preference off appends the OFF event first. Repeating the current value records nothing. Changes are applied in order. A failed write changes nothing and is reported (`ConsentChangeResult.failed`; the screen says the choice could not be saved).
- If storage fails it is `storageUnavailable`: choices are in memory and labelled as not saved. Saved values are never carried into memory.
- There is no consent "revision" field in the schema or decisions: ordering is the existing `consent_events` AUTOINCREMENT id, with a UTC timestamp, and the latest event per modality wins.
- These values never authorize a write: the repositories check the persisted events inside each write transaction. Revocation blocks later writes and keeps earlier records (unchanged ADR-009 Milestone B rule).
- Onboarding records nothing by itself: it only opens the Consent screen. Unanswered modalities stay OFF, and only an explicit toggle appends an event.

The Consent screen, Settings and the Voice screen state where choices are kept: "kept only while the app is open" (in memory, unchanged), "secure storage unavailable", "saved to development storage", or "saved on this device" (participant storage, not enabled in this milestone).

**Host test strategy.** Host tests cannot reach the Keystore or SQLCipher. `test/support/fake_secure_key_platform.dart` (test code only) answers the channel and opens disposable plain-SQLite files through `sqflite_common_ffi`, so the real provider, owner, repositories and consent model run on the host. A static test keeps `sqflite_common_ffi` out of `lib/` and keeps the SQLCipher driver import in `secure_key_platform_io.dart` only. On the emulator, `integration_test/sense_storage_test.dart` (run with `--dart-define=SENSE_DEV_STORAGE=1`) exercises the real development namespace and the native refusal of participant storage in a debug build, then destroys the namespace.

**Still not connected:** the Check-in, Sleep and Workload Save handlers (their "not saved" messages remain accurate), Export and Erase, journal text, voice, activity sync and any participant storage.
