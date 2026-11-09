package org.sense.mindpulse.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.system.Os
import android.system.OsConstants
import android.util.AtomicFile
import androidx.annotation.RequiresApi
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.nio.ByteBuffer
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.security.MessageDigest
import java.security.ProviderException
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

/**
 * What the Android Keystore reports about where the wrapping key lives.
 *
 * This is the Keystore's own report (KeyInfo). It is NOT verified by key
 * attestation, and an emulator's Keystore can report a hardware level for a
 * software implementation; see [KeySecurityAssessment].
 */
enum class KeySecurityLevel(val wireName: String, val reportsSecureHardware: Boolean) {
    STRONGBOX("strongBox", true),
    TRUSTED_ENVIRONMENT("trustedEnvironment", true),

    /** Secure hardware of an unspecified kind (API < 31, or UNKNOWN_SECURE). */
    HARDWARE_UNSPECIFIED("hardwareUnspecified", true),
    SOFTWARE("software", false),
    UNKNOWN("unknown", false),
}

/**
 * The reported level together with what can actually be concluded from it.
 * [hardwareBackedEvidence] requires a secure-hardware report on a device that
 * is not recognised as an emulator. It is still not attestation-verified.
 */
class KeySecurityAssessment(val reportedLevel: KeySecurityLevel, val emulator: Boolean) {
    val hardwareBackedEvidence: Boolean get() = reportedLevel.reportsSecureHardware && !emulator
}

/** Classification of the legacy `mindpulse_secure.db` file. It is never opened or modified. */
enum class LegacyDatabaseState(val wireName: String) {
    ABSENT("absent"),
    PLAINTEXT_SQLITE("plaintextSqlite"),
    EMPTY("empty"),

    /** Exists but has no plaintext SQLite header (could be anything; not assumed encrypted). */
    UNRECOGNIZED("unrecognized"),
}

/** Which database a manager serves. */
enum class StoragePurpose {
    /** The real participant database. Release builds with a hardware-backed key only. */
    PARTICIPANT,

    /** An isolated on-device test namespace. Debug builds only; never production eligible. */
    TEST_NAMESPACE,
}

/** Why the key was created outside StrongBox although the device advertises StrongBox. */
enum class StrongBoxFallback(val wireName: String) {
    /** The platform threw StrongBoxUnavailableException. */
    UNAVAILABLE("strongBoxUnavailable"),

    /** The Keystore provider rejected the StrongBox generation (ProviderException from Keystore). */
    PROVIDER_REJECTED("strongBoxProviderRejected"),
}

/** Typed, non-sensitive reasons why the key cannot be provided. */
enum class KeyFailure(val wireName: String) {
    /** The build is not allowed to open this database (debug/profile asking for the participant database). */
    BUILD_NOT_PRODUCTION_ELIGIBLE("buildNotProductionEligible"),

    /** Database present, key alias present, envelope missing. Never regenerated. */
    ENVELOPE_MISSING_FOR_EXISTING_DATABASE("envelopeMissingForExistingDatabase"),

    /** Database and envelope present, Keystore alias missing: the key is unavailable. */
    KEY_MISSING_FOR_EXISTING_DATABASE("keyMissingForExistingDatabase"),

    /** Database present with neither envelope nor alias: needs investigation. */
    KEY_AND_ENVELOPE_MISSING_FOR_EXISTING_DATABASE("keyAndEnvelopeMissingForExistingDatabase"),

    /** No database, envelope present, alias missing. */
    ENVELOPE_WITHOUT_KEY("envelopeWithoutKey"),

    /** No database, no envelope, but a Keystore alias not provably created by an interrupted setup. */
    ORPHANED_KEY("orphanedKey"),

    /** The envelope is not a valid format-1 envelope (truncated, unknown header...). */
    ENVELOPE_MALFORMED("envelopeMalformed"),

    /** GCM authentication failed: the envelope was altered, or the wrapping key is a different key. */
    ENVELOPE_AUTHENTICATION_FAILED("envelopeAuthenticationFailed"),

    /** Participant database and no evidence that the key is hardware-backed. */
    INSECURE_KEY_STORAGE("insecureKeyStorage"),

    /** The encrypted-database path holds a plaintext SQLite file. It is not opened or converted. */
    PLAINTEXT_DATABASE_AT_ENCRYPTED_PATH("plaintextDatabaseAtEncryptedPath"),
    KEYSTORE_ERROR("keystoreError"),

    /** First-time initialization failed; any partial key/envelope/marker created by it was rolled back. */
    INITIALIZATION_FAILED("initializationFailed"),
}

/** Presence of each persistent component. Contains no key material. */
class StorageState(
    val databasePresent: Boolean,
    val envelopePresent: Boolean,
    val keyAliasPresent: Boolean,
    val setupPending: Boolean,
    val legacyDatabase: LegacyDatabaseState,
)

sealed class KeyOpenResult {
    /**
     * The unwrapped SQLCipher passphrase (32 random bytes). The caller owns
     * [passphrase] and must overwrite it with zeros when done.
     */
    class Ready(
        val passphrase: ByteArray,
        val security: KeySecurityAssessment,
        val productionEligible: Boolean,
        val firstInitialization: Boolean,
        val recoveredMissingDatabase: Boolean,
        val legacyDatabase: LegacyDatabaseState,
        val strongBoxFallback: StrongBoxFallback? = null,
    ) : KeyOpenResult() {
        override fun toString(): String =
            "Ready(level=${security.reportedLevel}, emulator=${security.emulator}, " +
                "productionEligible=$productionEligible, first=$firstInitialization, " +
                "recoveredMissingDatabase=$recoveredMissingDatabase, legacy=$legacyDatabase, " +
                "strongBoxFallback=$strongBoxFallback)"
    }

    class Failed(
        val failure: KeyFailure,
        val legacyDatabase: LegacyDatabaseState,
        val security: KeySecurityAssessment? = null,
    ) : KeyOpenResult() {
        override fun toString(): String = "Failed($failure, legacy=$legacyDatabase)"
    }
}

/** Outcome of [SecureDatabaseKeyManager.destroy]. File names only, never contents. */
class DestroyReport(
    val envelopeDeleted: Boolean,
    val keyDeleted: Boolean,
    val databaseFilesDeleted: List<String>,
    val databaseFilesRemaining: List<String>,
)

/** Points in first-time initialization where tests simulate the process being killed. */
enum class InitStage { AFTER_SETUP_MARKER, AFTER_KEY_GENERATION, AFTER_ENVELOPE_WRITE }

/**
 * Thrown only by test fault injection to model abrupt process death: it is an
 * [Error], so the normal rollback (which catches [Exception]) does not run.
 */
class SimulatedProcessDeath(stage: InitStage) : Error("simulated process death at $stage")

/**
 * Creates, unwraps and destroys the SQLCipher database passphrase (Milestone J).
 *
 * - The passphrase is 32 bytes from [SecureRandom], generated once.
 * - It is persisted only inside a [KeyEnvelope], encrypted with a
 *   non-exportable AES-256-GCM key in the Android Keystore.
 * - The database, its WAL/SHM/journal, the envelope and the setup marker live
 *   in `Context.noBackupFilesDir`.
 * - Every inconsistent state fails closed; a key is never regenerated for an
 *   existing database, and nothing is deleted except by [destroy], by the
 *   rollback of a first-time initialization, or by resuming a setup that the
 *   setup marker proves was interrupted before any database existed.
 * - Production eligibility is explicit: [StoragePurpose.PARTICIPANT] requires
 *   a release, non-debuggable [BuildPolicy] AND hardware-backed key metadata.
 *
 * Instances are cheap and stateless between calls; all state is on disk and in
 * the Keystore. Callers serialise access (the channel runs every call on one
 * process-wide thread, under [DatabaseLifecycleRegistry]).
 */
class SecureDatabaseKeyManager internal constructor(
    private val storageDir: File,
    private val legacyDatabaseFile: File,
    private val keyAlias: String,
    val purpose: StoragePurpose,
    val buildPolicy: BuildPolicy,
    private val strongBoxAvailable: Boolean,
    private val emulator: Boolean,
    private val random: SecureRandom = SecureRandom(),
    /** Test seam: replaces the KeyInfo security-level lookup. */
    private val securityLevelProbe: ((SecretKey) -> KeySecurityLevel)? = null,
    /** Test seam: replaces Keystore key generation (argument: StrongBox requested). */
    private val keyGeneration: ((Boolean) -> SecretKey)? = null,
    /** Test seam: called at each [InitStage]; may throw [SimulatedProcessDeath]. */
    private val faultInjector: ((InitStage) -> Unit)? = null,
) {
    companion object {
        const val DATABASE_FILE_NAME = "sense_encrypted_v1.db"
        const val ENVELOPE_FILE_NAME = "sense_db_key_v1.envelope"
        const val SETUP_MARKER_FILE_NAME = "sense_db_setup_v1.pending"
        const val KEY_ALIAS = "sense_db_wrapping_key_v1"
        const val LEGACY_DATABASE_FILE_NAME = "mindpulse_secure.db"
        val DATABASE_SIDECAR_SUFFIXES = listOf("-wal", "-shm", "-journal")

        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private val SQLITE_PLAINTEXT_HEADER = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)
        private val NAMESPACE_PATTERN = Regex("^[a-z0-9_]{1,40}$")
        private val MARKER_MAGIC = byteArrayOf(0x53, 0x4E, 0x53, 0x55) // "SNSU"
        private const val MARKER_VERSION: Byte = 1

        /** Keystore creation dates can be second-granular; allow that much before the marker time. */
        private const val CREATION_TOLERANCE_MS = 2_000L
        internal const val KEYSTORE_EXCEPTION_CLASS = "android.security.KeyStoreException"

        /**
         * The manager for this app. [testNamespace] isolates on-device tests
         * from the real key and files (own alias, own directory, own legacy
         * path). It is accepted only when [policy] allows test namespaces
         * (debuggable debug builds); otherwise this throws
         * IllegalArgumentException.
         */
        fun forApp(
            context: Context,
            testNamespace: String? = null,
            policy: BuildPolicy = BuildPolicy.current(context),
        ): SecureDatabaseKeyManager {
            val noBackup = context.noBackupFilesDir
            val strongBox =
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                    context.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
            if (testNamespace == null) {
                return SecureDatabaseKeyManager(
                    storageDir = noBackup,
                    legacyDatabaseFile = context.getDatabasePath(LEGACY_DATABASE_FILE_NAME),
                    keyAlias = KEY_ALIAS,
                    purpose = StoragePurpose.PARTICIPANT,
                    buildPolicy = policy,
                    strongBoxAvailable = strongBox,
                    emulator = isProbablyEmulator(),
                )
            }
            require(policy.testNamespacesAllowed) { "test namespaces are only available in debug builds" }
            require(NAMESPACE_PATTERN.matches(testNamespace)) { "invalid test namespace" }
            val dir = File(File(noBackup, "test_namespaces"), testNamespace)
            return SecureDatabaseKeyManager(
                storageDir = dir,
                legacyDatabaseFile = File(File(dir, "legacy"), LEGACY_DATABASE_FILE_NAME),
                keyAlias = "${KEY_ALIAS}__$testNamespace",
                purpose = StoragePurpose.TEST_NAMESPACE,
                buildPolicy = policy,
                strongBoxAvailable = strongBox,
                emulator = isProbablyEmulator(),
            )
        }

        /**
         * Heuristic: the Android Emulator's system properties. An emulator's
         * Keystore is never treated as hardware evidence, whatever it reports.
         */
        fun isProbablyEmulator(): Boolean =
            Build.HARDWARE == "ranchu" ||
                Build.HARDWARE == "goldfish" ||
                Build.FINGERPRINT.startsWith("generic") ||
                Build.FINGERPRINT.contains("emulator") ||
                Build.PRODUCT.startsWith("sdk_") ||
                Build.MODEL.startsWith("sdk_gphone")

        /**
         * Whether a StrongBox key-generation failure means "StrongBox cannot
         * do this here" (fall back to TEE) rather than a real failure (do
         * not fall back). Deliberately narrow:
         * - StrongBoxUnavailableException anywhere in the cause chain;
         * - a ProviderException whose cause chain contains the Keystore's own
         *   android.security.KeyStoreException (the provider rejected the
         *   StrongBox operation).
         * Anything else (invalid parameters, missing algorithm, I/O, ...) is
         * rethrown and initialization fails.
         */
        internal fun strongBoxFallbackFor(e: Throwable): StrongBoxFallback? {
            if (causeChain(e).any { it is StrongBoxUnavailableException }) return StrongBoxFallback.UNAVAILABLE
            // Matched by name: the class is public only from API 33 (hidden before), and a
            // type check against it would not link on older releases.
            if (e is ProviderException && causeChain(e).drop(1).any { it.javaClass.name == KEYSTORE_EXCEPTION_CLASS }) {
                return StrongBoxFallback.PROVIDER_REJECTED
            }
            return null
        }

        private fun causeChain(e: Throwable): List<Throwable> {
            val out = mutableListOf<Throwable>()
            var t: Throwable? = e
            while (t != null && out.size < 16 && t !in out) {
                out += t
                t = t.cause
            }
            return out
        }
    }

    val databaseFile: File get() = File(storageDir, DATABASE_FILE_NAME)
    val envelopePath: File get() = File(storageDir, ENVELOPE_FILE_NAME)
    val setupMarkerPath: File get() = File(storageDir, SETUP_MARKER_FILE_NAME)
    val legacyDatabasePath: File get() = legacyDatabaseFile
    val storageDirectory: File get() = storageDir

    /** Key for [DatabaseLifecycleRegistry]: one lifecycle per storage directory. */
    val lifecycleKey: String get() = storageDir.absolutePath

    private val envelope: AtomicFile get() = AtomicFile(envelopePath)
    private val setupMarker: AtomicFile get() = AtomicFile(setupMarkerPath)

    private val requiresHardwareEvidence: Boolean get() = purpose == StoragePurpose.PARTICIPANT

    private fun productionEligible(security: KeySecurityAssessment): Boolean =
        purpose == StoragePurpose.PARTICIPANT && buildPolicy.participantDatabaseAllowed && security.hardwareBackedEvidence

    // ---- State -----------------------------------------------------------------------------

    fun inspect(): StorageState =
        StorageState(
            databasePresent = databasePresent(),
            envelopePresent = envelopePresent(),
            keyAliasPresent = aliasPresent(),
            setupPending = readSetupMarker() != null,
            legacyDatabase = classifyLegacyDatabase(),
        )

    /**
     * Returns the database passphrase, creating it on the very first call.
     * See the tables in docs/architecture/encrypted_local_storage.md.
     */
    fun openOrInitialize(): KeyOpenResult {
        val legacy = classifyLegacyDatabase()
        // Policy first: a build that may not open this database touches nothing.
        if (purpose == StoragePurpose.PARTICIPANT && !buildPolicy.participantDatabaseAllowed) {
            return KeyOpenResult.Failed(KeyFailure.BUILD_NOT_PRODUCTION_ELIGIBLE, legacy)
        }
        val dbPresent = databasePresent()
        if (dbPresent && hasPlaintextSqliteHeader(databaseFile)) {
            return KeyOpenResult.Failed(KeyFailure.PLAINTEXT_DATABASE_AT_ENCRYPTED_PATH, legacy)
        }
        val envPresent = envelopePresent()
        val keyPresent =
            try {
                aliasPresent()
            } catch (e: GeneralSecurityException) {
                return KeyOpenResult.Failed(KeyFailure.KEYSTORE_ERROR, legacy)
            }
        readSetupMarker()?.let { marker ->
            resumeInterruptedSetup(marker, legacy, dbPresent, envPresent, keyPresent)?.let { return it }
        }
        return when {
            !dbPresent && !envPresent && !keyPresent -> initialize(legacy)
            dbPresent && envPresent && keyPresent -> unwrapExisting(legacy, firstInitialization = false, recoveredMissingDatabase = false)
            dbPresent && !envPresent && keyPresent ->
                KeyOpenResult.Failed(KeyFailure.ENVELOPE_MISSING_FOR_EXISTING_DATABASE, legacy)
            dbPresent && envPresent && !keyPresent ->
                KeyOpenResult.Failed(KeyFailure.KEY_MISSING_FOR_EXISTING_DATABASE, legacy)
            dbPresent && !envPresent && !keyPresent ->
                KeyOpenResult.Failed(KeyFailure.KEY_AND_ENVELOPE_MISSING_FOR_EXISTING_DATABASE, legacy)
            // Database missing but key and envelope intact, after a completed
            // setup: safe to continue only if the envelope authenticates under
            // the key (checked in unwrapExisting). Reported, never silent.
            !dbPresent && envPresent && keyPresent ->
                unwrapExisting(legacy, firstInitialization = false, recoveredMissingDatabase = true)
            !dbPresent && envPresent && !keyPresent -> KeyOpenResult.Failed(KeyFailure.ENVELOPE_WITHOUT_KEY, legacy)
            else -> KeyOpenResult.Failed(KeyFailure.ORPHANED_KEY, legacy)
        }
    }

    /**
     * A setup marker exists: a first-time initialization started and its
     * database was never confirmed. Returns null to fall through to the normal
     * (fail-closed) state table.
     */
    private fun resumeInterruptedSetup(
        marker: SetupMarker,
        legacy: LegacyDatabaseState,
        dbPresent: Boolean,
        envPresent: Boolean,
        keyPresent: Boolean,
    ): KeyOpenResult? {
        if (marker.alias != keyAlias) return null
        return when {
            // Killed during (or right after) initial database creation: continue
            // with the existing key; SQLite recovers or recreates the schema.
            dbPresent && envPresent && keyPresent -> unwrapExisting(legacy, firstInitialization = true, recoveredMissingDatabase = false)
            dbPresent -> null
            // Killed before the key existed.
            !envPresent && !keyPresent -> {
                deleteSetupMarker()
                initialize(legacy)
            }
            // Killed after key generation, before the envelope: nothing can
            // depend on this key (no database, no envelope), and the marker
            // proves this setup created it. Remove it and start again.
            !envPresent && keyPresent ->
                if (aliasCreatedAfter(marker.createdAtMillis)) {
                    try {
                        keyStore().deleteEntry(keyAlias)
                    } catch (e: Exception) {
                        return KeyOpenResult.Failed(KeyFailure.KEYSTORE_ERROR, legacy)
                    }
                    deleteSetupMarker()
                    initialize(legacy)
                } else {
                    null
                }
            // Killed after the envelope was written, before the database:
            // continue the same first initialization with the existing key.
            envPresent && keyPresent -> unwrapExisting(legacy, firstInitialization = true, recoveredMissingDatabase = false)
            else -> null
        }
    }

    private fun aliasCreatedAfter(markerMillis: Long): Boolean =
        try {
            val created = keyStore().getCreationDate(keyAlias)
            created != null && created.time >= markerMillis - CREATION_TOLERANCE_MS
        } catch (_: Exception) {
            false
        }

    private class GeneratedKey(val key: SecretKey, val strongBoxFallback: StrongBoxFallback?)

    private fun initialize(legacy: LegacyDatabaseState): KeyOpenResult {
        var wroteMarker = false
        var createdKey = false
        var wroteEnvelope = false
        var passphrase: ByteArray? = null
        try {
            if (!storageDir.exists() && !storageDir.mkdirs()) throw java.io.IOException("cannot create storage directory")
            writeSetupMarker()
            wroteMarker = true
            faultInjector?.invoke(InitStage.AFTER_SETUP_MARKER)

            val generated = generateWrappingKey()
            createdKey = true
            faultInjector?.invoke(InitStage.AFTER_KEY_GENERATION)

            val security = assess(generated.key)
            if (requiresHardwareEvidence && !security.hardwareBackedEvidence) {
                rollbackInitialization(createdKey, wroteEnvelope = false, wroteMarker)
                return KeyOpenResult.Failed(KeyFailure.INSECURE_KEY_STORAGE, legacy, security)
            }
            passphrase = ByteArray(KeyEnvelope.PASSPHRASE_BYTES).also(random::nextBytes)
            writeEnvelope(wrap(generated.key, passphrase))
            wroteEnvelope = true
            faultInjector?.invoke(InitStage.AFTER_ENVELOPE_WRITE)

            // Prove the stored envelope round-trips before reporting success.
            val check = unwrap(generated.key, readEnvelope())
            val matches = MessageDigest.isEqual(check, passphrase)
            check.fill(0)
            if (!matches) throw GeneralSecurityException("envelope round-trip mismatch")

            // The setup marker stays until the database is confirmed (completeSetup).
            return KeyOpenResult.Ready(
                passphrase = passphrase,
                security = security,
                productionEligible = productionEligible(security),
                firstInitialization = true,
                recoveredMissingDatabase = false,
                legacyDatabase = legacy,
                strongBoxFallback = generated.strongBoxFallback,
            )
        } catch (e: Exception) {
            passphrase?.fill(0)
            rollbackInitialization(createdKey, wroteEnvelope, wroteMarker)
            return KeyOpenResult.Failed(KeyFailure.INITIALIZATION_FAILED, legacy)
        }
    }

    /**
     * Removes only what this initialization created, and only while no
     * database exists that could depend on it.
     */
    private fun rollbackInitialization(createdKey: Boolean, wroteEnvelope: Boolean, wroteMarker: Boolean) {
        if (databasePresent()) return
        try {
            if (wroteEnvelope) envelope.delete()
            if (createdKey) keyStore().deleteEntry(keyAlias)
            if (wroteMarker) deleteSetupMarker()
        } catch (_: Exception) {
            // Best effort: the marker (if still present) lets the next call resume safely.
        }
    }

    /**
     * Called once the database has been created and verified (the lifecycle
     * owner's commit). Ends the first-time initialization.
     */
    fun completeSetup() {
        if (setupMarkerPath.exists() && databaseFile.exists()) deleteSetupMarker()
    }

    private fun unwrapExisting(
        legacy: LegacyDatabaseState,
        firstInitialization: Boolean,
        recoveredMissingDatabase: Boolean,
    ): KeyOpenResult {
        val key =
            try {
                loadWrappingKey()
            } catch (e: GeneralSecurityException) {
                return KeyOpenResult.Failed(KeyFailure.KEYSTORE_ERROR, legacy)
            } ?: return KeyOpenResult.Failed(KeyFailure.KEY_MISSING_FOR_EXISTING_DATABASE, legacy)

        // The hardware gate runs on the real key metadata on EVERY open, before
        // the envelope is read and before any database can be opened.
        val security = assess(key)
        if (requiresHardwareEvidence && !security.hardwareBackedEvidence) {
            return KeyOpenResult.Failed(KeyFailure.INSECURE_KEY_STORAGE, legacy, security)
        }
        val parsed =
            try {
                readEnvelope()
            } catch (e: FileNotFoundException) {
                return KeyOpenResult.Failed(KeyFailure.ENVELOPE_MISSING_FOR_EXISTING_DATABASE, legacy)
            } catch (e: EnvelopeFormatException) {
                return KeyOpenResult.Failed(KeyFailure.ENVELOPE_MALFORMED, legacy)
            } catch (e: java.io.IOException) {
                return KeyOpenResult.Failed(KeyFailure.ENVELOPE_MALFORMED, legacy)
            }
        val passphrase =
            try {
                unwrap(key, parsed)
            } catch (e: AEADBadTagException) {
                return KeyOpenResult.Failed(KeyFailure.ENVELOPE_AUTHENTICATION_FAILED, legacy)
            } catch (e: GeneralSecurityException) {
                return KeyOpenResult.Failed(KeyFailure.KEYSTORE_ERROR, legacy)
            }
        if (passphrase.size != KeyEnvelope.PASSPHRASE_BYTES) {
            passphrase.fill(0)
            return KeyOpenResult.Failed(KeyFailure.ENVELOPE_MALFORMED, legacy)
        }
        return KeyOpenResult.Ready(
            passphrase = passphrase,
            security = security,
            productionEligible = productionEligible(security),
            firstInitialization = firstInitialization,
            recoveredMissingDatabase = recoveredMissingDatabase,
            legacyDatabase = legacy,
        )
    }

    // ---- Destruction -----------------------------------------------------------------------

    /**
     * Cryptographic erasure. Only the lifecycle owner may call this, after
     * [DatabaseLifecycleRegistry.beginDestroy] confirmed that no connection is
     * open or opening. Removes the envelope, deletes the Keystore alias, then
     * deletes the database, its WAL/SHM/journal files and the setup marker
     * (best effort).
     *
     * Without the alias the envelope can never be unwrapped again, so any
     * copy of the old database bytes is unreadable. This is NOT a guarantee of
     * physical sanitization of the storage medium.
     */
    fun destroy(): DestroyReport {
        val envelopeDeleted =
            try {
                envelope.delete()
                !envelopePresent()
            } catch (_: Exception) {
                false
            }
        val keyDeleted =
            try {
                val ks = keyStore()
                if (ks.containsAlias(keyAlias)) ks.deleteEntry(keyAlias)
                !ks.containsAlias(keyAlias)
            } catch (_: Exception) {
                false
            }
        val deleted = mutableListOf<String>()
        val remaining = mutableListOf<String>()
        for (f in databaseFiles()) {
            if (!f.exists()) continue
            if (f.delete()) deleted += f.name else remaining += f.name
        }
        try {
            deleteSetupMarker()
        } catch (_: Exception) {
        }
        return DestroyReport(envelopeDeleted, keyDeleted, deleted, remaining)
    }

    // ---- Keystore --------------------------------------------------------------------------

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    internal fun aliasPresent(): Boolean = keyStore().containsAlias(keyAlias)

    private fun loadWrappingKey(): SecretKey? = keyStore().getKey(keyAlias, null) as? SecretKey

    private fun generateWrappingKey(): GeneratedKey {
        if (strongBoxAvailable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                return GeneratedKey(generate(strongBox = true), strongBoxFallback = null)
            } catch (e: Exception) {
                val reason = strongBoxFallbackFor(e) ?: throw e
                // A failed StrongBox attempt must not leave an alias behind.
                if (aliasPresent()) keyStore().deleteEntry(keyAlias)
                return GeneratedKey(generate(strongBox = false), strongBoxFallback = reason)
            }
        }
        return GeneratedKey(generate(strongBox = false), strongBoxFallback = null)
    }

    private fun generate(strongBox: Boolean): SecretKey = keyGeneration?.invoke(strongBox) ?: generateKeystoreKey(strongBox)

    private fun generateKeystoreKey(strongBox: Boolean): SecretKey {
        val spec =
            KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                // The Keystore generates a fresh random IV for every encryption.
                .setRandomizedEncryptionRequired(true)
                .apply { if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) requestStrongBox(this) }
                .build()
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        generator.init(spec)
        return generator.generateKey()
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun requestStrongBox(builder: KeyGenParameterSpec.Builder) {
        builder.setIsStrongBoxBacked(true)
    }

    internal fun assess(key: SecretKey): KeySecurityAssessment =
        KeySecurityAssessment(securityLevelProbe?.invoke(key) ?: securityLevelOf(key), emulator)

    private fun securityLevelOf(key: SecretKey): KeySecurityLevel =
        try {
            val factory = SecretKeyFactory.getInstance(key.algorithm, KEYSTORE_PROVIDER)
            val info = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                when (info.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> KeySecurityLevel.STRONGBOX
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> KeySecurityLevel.TRUSTED_ENVIRONMENT
                    KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE -> KeySecurityLevel.HARDWARE_UNSPECIFIED
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> KeySecurityLevel.SOFTWARE
                    else -> KeySecurityLevel.UNKNOWN
                }
            } else {
                @Suppress("DEPRECATION")
                if (info.isInsideSecureHardware) KeySecurityLevel.HARDWARE_UNSPECIFIED else KeySecurityLevel.SOFTWARE
            }
        } catch (_: Exception) {
            KeySecurityLevel.UNKNOWN
        }

    // ---- Envelope crypto -------------------------------------------------------------------

    /** Encrypts [passphrase] under [key] with a Keystore-generated IV. */
    internal fun wrap(key: SecretKey, passphrase: ByteArray): ByteArray {
        val header = KeyEnvelope.header()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(header)
        val ciphertext = cipher.doFinal(passphrase)
        return KeyEnvelope.encode(cipher.iv, ciphertext)
    }

    internal fun unwrap(key: SecretKey, parsed: KeyEnvelope.Parsed): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(KeyEnvelope.TAG_BITS, parsed.iv))
        cipher.updateAAD(parsed.header)
        return cipher.doFinal(parsed.ciphertext)
    }

    /** Test seam: wrap with the current alias. */
    internal fun wrapWithCurrentKey(passphrase: ByteArray): ByteArray =
        wrap(loadWrappingKey() ?: throw GeneralSecurityException("no wrapping key"), passphrase)

    /** Test seam: unwrap arbitrary envelope bytes with the current alias. */
    internal fun unwrapWithCurrentKey(envelopeBytes: ByteArray): ByteArray =
        unwrap(loadWrappingKey() ?: throw GeneralSecurityException("no wrapping key"), KeyEnvelope.decode(envelopeBytes))

    // ---- Files -----------------------------------------------------------------------------

    /** AtomicFile: write a temporary file, fsync it, rename over the target; then fsync the directory. */
    private fun atomicWrite(file: AtomicFile, bytes: ByteArray) {
        val out = file.startWrite()
        try {
            out.write(bytes)
            file.finishWrite(out)
        } catch (e: Exception) {
            file.failWrite(out)
            throw e
        }
        syncDirectory()
    }

    /** Best effort: makes the rename/unlink durable. Not every filesystem supports it. */
    private fun syncDirectory() {
        try {
            val fd = Os.open(storageDir.absolutePath, OsConstants.O_RDONLY, 0)
            try {
                Os.fsync(fd)
            } finally {
                Os.close(fd)
            }
        } catch (_: Exception) {
        }
    }

    private fun writeEnvelope(bytes: ByteArray) = atomicWrite(envelope, bytes)

    private fun readEnvelope(): KeyEnvelope.Parsed = KeyEnvelope.decode(envelope.readFully())

    /** Base file, or AtomicFile's legacy backup left by an interrupted write. */
    private fun envelopePresent(): Boolean =
        envelopePath.exists() || File(storageDir, "$ENVELOPE_FILE_NAME.bak").exists()

    internal class SetupMarker(val alias: String, val createdAtMillis: Long)

    private fun writeSetupMarker() {
        val alias = keyAlias.toByteArray(Charsets.UTF_8)
        val bytes =
            ByteBuffer.allocate(4 + 1 + 8 + 2 + alias.size)
                .put(MARKER_MAGIC)
                .put(MARKER_VERSION)
                .putLong(System.currentTimeMillis())
                .putShort(alias.size.toShort())
                .put(alias)
                .array()
        atomicWrite(setupMarker, bytes)
    }

    /** The marker, or null when absent or not a valid format-1 marker (then treated as absent). */
    internal fun readSetupMarker(): SetupMarker? {
        if (!setupMarkerPath.exists() && !File(storageDir, "$SETUP_MARKER_FILE_NAME.bak").exists()) return null
        return try {
            val b = ByteBuffer.wrap(setupMarker.readFully())
            val magic = ByteArray(4).also { b.get(it) }
            if (!magic.contentEquals(MARKER_MAGIC) || b.get() != MARKER_VERSION) return null
            val created = b.long
            val len = b.short.toInt()
            if (len <= 0 || len != b.remaining()) return null
            SetupMarker(String(ByteArray(len).also { b.get(it) }, Charsets.UTF_8), created)
        } catch (_: Exception) {
            null
        }
    }

    private fun deleteSetupMarker() {
        setupMarker.delete()
        syncDirectory()
    }

    private fun databaseFiles(): List<File> =
        listOf(databaseFile) + DATABASE_SIDECAR_SUFFIXES.map { File(storageDir, DATABASE_FILE_NAME + it) }

    /** The main file or any WAL/journal: a sidecar alone still means "a database existed". */
    private fun databasePresent(): Boolean =
        databaseFile.exists() ||
            File(storageDir, "$DATABASE_FILE_NAME-wal").exists() ||
            File(storageDir, "$DATABASE_FILE_NAME-journal").exists()

    /** Reads at most 16 bytes, read-only. Never opens the file as a database. */
    private fun hasPlaintextSqliteHeader(file: File): Boolean {
        if (!file.isFile || file.length() < SQLITE_PLAINTEXT_HEADER.size) return false
        val header = ByteArray(SQLITE_PLAINTEXT_HEADER.size)
        FileInputStream(file).use { input ->
            var read = 0
            while (read < header.size) {
                val n = input.read(header, read, header.size - read)
                if (n < 0) return false
                read += n
            }
        }
        return header.contentEquals(SQLITE_PLAINTEXT_HEADER)
    }

    internal fun classifyLegacyDatabase(): LegacyDatabaseState {
        val f = legacyDatabaseFile
        if (!f.exists()) return LegacyDatabaseState.ABSENT
        if (f.length() == 0L) return LegacyDatabaseState.EMPTY
        return try {
            if (hasPlaintextSqliteHeader(f)) LegacyDatabaseState.PLAINTEXT_SQLITE else LegacyDatabaseState.UNRECOGNIZED
        } catch (_: Exception) {
            LegacyDatabaseState.UNRECOGNIZED
        }
    }
}
