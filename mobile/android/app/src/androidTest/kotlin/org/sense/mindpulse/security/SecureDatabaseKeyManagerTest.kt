package org.sense.mindpulse.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.KeyGenerator

/**
 * Milestone J, test group A: the real Android Keystore key lifecycle on a
 * device or emulator. Every test uses its own Keystore alias and its own
 * directory under noBackupFilesDir, so the app's real key and files are never
 * touched. Database files here are stand-ins (random bytes): the key manager
 * only checks their presence and header. SQLCipher itself is tested from Dart
 * (integration_test/).
 */
class SecureDatabaseKeyManagerTest {
    private lateinit var context: Context
    private lateinit var dir: File
    private lateinit var alias: String
    private val emulator = SecureDatabaseKeyManager.isProbablyEmulator()

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        val id = UUID.randomUUID().toString().replace("-", "").take(12)
        dir = File(File(context.noBackupFilesDir, "android_test"), id)
        alias = "sense_db_wrapping_key_v1__androidtest_$id"
    }

    @After
    fun tearDown() {
        try {
            keyStore().deleteEntry(alias)
        } catch (_: Exception) {
        }
        dir.deleteRecursively()
    }

    /**
     * [allowWithoutHardwareEvidence] = true: a debug-build test namespace
     * (software keys allowed, never production eligible). false: the
     * participant database under a release, non-debuggable build policy (the
     * hardware gate applies), in this test's own directory and alias.
     */
    private fun manager(allowWithoutHardwareEvidence: Boolean = true) =
        SecureDatabaseKeyManager(
            storageDir = dir,
            legacyDatabaseFile = File(File(dir, "legacy"), SecureDatabaseKeyManager.LEGACY_DATABASE_FILE_NAME),
            keyAlias = alias,
            purpose = if (allowWithoutHardwareEvidence) StoragePurpose.TEST_NAMESPACE else StoragePurpose.PARTICIPANT,
            buildPolicy =
                if (allowWithoutHardwareEvidence) BuildPolicy(BuildKind.DEBUG, debuggable = true)
                else BuildPolicy(BuildKind.RELEASE, debuggable = false),
            strongBoxAvailable = false,
            emulator = emulator,
        )

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun aliasExists() = keyStore().containsAlias(alias)

    private val dbFile get() = File(dir, SecureDatabaseKeyManager.DATABASE_FILE_NAME)
    private val envelopeFile get() = File(dir, SecureDatabaseKeyManager.ENVELOPE_FILE_NAME)

    private fun sha256(f: File) = MessageDigest.getInstance("SHA-256").digest(f.readBytes())

    /** A stand-in for an existing encrypted database: random bytes, no SQLite header. */
    private fun createStandInDatabase() {
        dir.mkdirs()
        dbFile.writeBytes(ByteArray(4096).also { java.security.SecureRandom().nextBytes(it) })
    }

    private fun ready(r: KeyOpenResult): KeyOpenResult.Ready {
        assertTrue("expected Ready, got $r", r is KeyOpenResult.Ready)
        return r as KeyOpenResult.Ready
    }

    private fun failed(r: KeyOpenResult, expected: KeyFailure) {
        assertTrue("expected Failed($expected), got $r", r is KeyOpenResult.Failed)
        assertEquals(expected, (r as KeyOpenResult.Failed).failure)
    }

    private fun initializeWithDatabase(): ByteArray {
        val first = ready(manager().openOrInitialize())
        val passphrase = first.passphrase.copyOf()
        first.passphrase.fill(0)
        createStandInDatabase()
        manager().completeSetup() // what the lifecycle owner's commitOpen does
        return passphrase
    }

    private fun indexOf(haystack: ByteArray, needle: ByteArray): Int {
        if (needle.isEmpty() || needle.size > haystack.size) return -1
        outer@ for (i in 0..haystack.size - needle.size) {
            for (j in needle.indices) if (haystack[i + j] != needle[j]) continue@outer
            return i
        }
        return -1
    }

    private fun hex(b: ByteArray) = b.joinToString("") { "%02x".format(it) }

    // ---- First initialization and reopening --------------------------------------------------

    @Test
    fun firstInitializationCreatesKeyAndEnvelope() {
        assertFalse(aliasExists())
        val r = ready(manager().openOrInitialize())
        assertTrue(r.firstInitialization)
        assertEquals(KeyEnvelope.PASSPHRASE_BYTES, r.passphrase.size)
        assertTrue(aliasExists())
        assertTrue(envelopeFile.exists())
        assertEquals(KeyEnvelope.TOTAL_BYTES.toLong(), envelopeFile.length())
        assertFalse("first initialization must not create the database", dbFile.exists())
        r.passphrase.fill(0)
    }

    @Test
    fun subsequentInitializationUnwrapsTheSamePassphrase() {
        val original = initializeWithDatabase()
        val again = ready(manager().openOrInitialize()) // new instance: nothing cached
        assertFalse(again.firstInitialization)
        assertFalse(again.recoveredMissingDatabase)
        assertArrayEquals(original, again.passphrase)
        val third = ready(manager().openOrInitialize())
        assertArrayEquals(original, third.passphrase)
    }

    @Test
    fun envelopeDoesNotContainThePlaintextPassphrase() {
        val passphrase = initializeWithDatabase()
        val bytes = envelopeFile.readBytes()
        assertEquals(-1, indexOf(bytes, passphrase))
        assertEquals(-1, indexOf(bytes, hex(passphrase).toByteArray()))
        assertEquals(-1, indexOf(bytes, hex(passphrase).uppercase().toByteArray()))
        assertEquals(-1, indexOf(bytes, Base64.encode(passphrase, Base64.NO_WRAP)))
        assertEquals(-1, indexOf(bytes, Base64.encode(passphrase, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)))
        // Any 8-byte window of the passphrase is also absent.
        for (i in 0..passphrase.size - 8) assertEquals(-1, indexOf(bytes, passphrase.copyOfRange(i, i + 8)))
    }

    @Test
    fun ivIsFreshForEveryEncryption() {
        val passphrase = initializeWithDatabase()
        val m = manager()
        val ivs = mutableSetOf<String>()
        val ciphertexts = mutableSetOf<String>()
        repeat(25) {
            val env = KeyEnvelope.decode(m.wrapWithCurrentKey(passphrase))
            ivs += hex(env.iv)
            ciphertexts += hex(env.ciphertext)
            assertEquals(KeyEnvelope.IV_BYTES, env.iv.size)
        }
        assertEquals("IV reused", 25, ivs.size)
        assertEquals("ciphertext repeated", 25, ciphertexts.size)
        val stored = KeyEnvelope.decode(envelopeFile.readBytes())
        assertFalse(hex(stored.iv) in ivs)
    }

    // ---- Tampering, wrong keys and corruption ------------------------------------------------

    @Test
    fun envelopeTamperingIsDetectedAndNothingIsDeleted() {
        initializeWithDatabase()
        val good = envelopeFile.readBytes()
        val dbHash = sha256(dbFile)
        val ivAndCiphertext = KeyEnvelope.HEADER_BYTES until KeyEnvelope.TOTAL_BYTES
        for (offset in ivAndCiphertext step 5) {
            val bad = good.copyOf().also { it[offset] = (it[offset].toInt() xor 0x01).toByte() }
            envelopeFile.writeBytes(bad)
            failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_AUTHENTICATION_FAILED)
            assertTrue(envelopeFile.exists())
            assertArrayEquals(bad, envelopeFile.readBytes())
        }
        // Header bytes are rejected before decryption (and are also GCM AAD).
        for (offset in 0 until KeyEnvelope.HEADER_BYTES) {
            envelopeFile.writeBytes(good.copyOf().also { it[offset] = (it[offset].toInt() xor 0x01).toByte() })
            failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_MALFORMED)
        }
        assertArrayEquals(dbHash, sha256(dbFile))
        assertTrue(aliasExists())
        envelopeFile.writeBytes(good)
        ready(manager().openOrInitialize())
    }

    @Test
    fun aDifferentWrappingKeyUnderTheSameAliasFailsClosed() {
        initializeWithDatabase()
        val envelopeBefore = envelopeFile.readBytes()
        val dbHash = sha256(dbFile)
        keyStore().deleteEntry(alias)
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        gen.generateKey()
        failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_AUTHENTICATION_FAILED)
        assertArrayEquals(envelopeBefore, envelopeFile.readBytes())
        assertArrayEquals(dbHash, sha256(dbFile))
    }

    @Test
    fun corruptedEnvelopeFailsClosedWithoutDeletingTheDatabase() {
        initializeWithDatabase()
        val dbHash = sha256(dbFile)
        val corruptions =
            listOf(
                ByteArray(0),
                envelopeFile.readBytes().copyOf(KeyEnvelope.TOTAL_BYTES - 1),
                envelopeFile.readBytes() + byteArrayOf(0),
                ByteArray(KeyEnvelope.TOTAL_BYTES) { 0x41 },
                "not an envelope".toByteArray(),
            )
        for (c in corruptions) {
            envelopeFile.writeBytes(c)
            failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_MALFORMED)
            assertTrue(dbFile.exists())
            assertTrue(aliasExists())
        }
        assertArrayEquals(dbHash, sha256(dbFile))
    }

    // ---- The state table ---------------------------------------------------------------------

    @Test
    fun databasePresentEnvelopeAbsentAliasPresentFailsClosedAndNeverRegenerates() {
        initializeWithDatabase()
        envelopeFile.delete()
        repeat(2) {
            failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_MISSING_FOR_EXISTING_DATABASE)
            assertFalse("envelope must not be regenerated", envelopeFile.exists())
        }
    }

    @Test
    fun databasePresentEnvelopePresentAliasAbsentFailsClosed() {
        initializeWithDatabase()
        val env = envelopeFile.readBytes()
        keyStore().deleteEntry(alias)
        repeat(2) {
            failed(manager().openOrInitialize(), KeyFailure.KEY_MISSING_FOR_EXISTING_DATABASE)
            assertFalse("a key must never be regenerated for an existing database", aliasExists())
        }
        assertArrayEquals(env, envelopeFile.readBytes())
    }

    @Test
    fun databasePresentEnvelopeAbsentAliasAbsentFailsClosed() {
        initializeWithDatabase()
        envelopeFile.delete()
        keyStore().deleteEntry(alias)
        failed(manager().openOrInitialize(), KeyFailure.KEY_AND_ENVELOPE_MISSING_FOR_EXISTING_DATABASE)
        assertFalse(aliasExists())
        assertFalse(envelopeFile.exists())
        assertTrue(dbFile.exists())
    }

    @Test
    fun walOnlyStillCountsAsAnExistingDatabase() {
        initializeWithDatabase()
        dbFile.delete()
        File(dir, SecureDatabaseKeyManager.DATABASE_FILE_NAME + "-wal").writeBytes(ByteArray(64))
        keyStore().deleteEntry(alias)
        failed(manager().openOrInitialize(), KeyFailure.KEY_MISSING_FOR_EXISTING_DATABASE)
        assertFalse(aliasExists())
    }

    @Test
    fun databaseAbsentEnvelopeAndAliasPresentRecoversOnlyAfterValidation() {
        val original = initializeWithDatabase()
        dbFile.delete()
        val r = ready(manager().openOrInitialize())
        assertTrue(r.recoveredMissingDatabase)
        assertFalse(r.firstInitialization)
        assertArrayEquals(original, r.passphrase)
        // Same state but an envelope that does not authenticate: no recovery.
        val bad = envelopeFile.readBytes().also { it[40] = (it[40].toInt() xor 0x01).toByte() }
        envelopeFile.writeBytes(bad)
        failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_AUTHENTICATION_FAILED)
    }

    @Test
    fun databaseAbsentEnvelopePresentAliasAbsentFailsClosed() {
        initializeWithDatabase()
        dbFile.delete()
        keyStore().deleteEntry(alias)
        failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_WITHOUT_KEY)
        assertFalse(aliasExists())
        assertTrue(envelopeFile.exists())
    }

    @Test
    fun orphanedAliasIsNotOverwritten() {
        initializeWithDatabase()
        dbFile.delete()
        val retainedEnvelope = envelopeFile.readBytes()
        envelopeFile.delete()
        val createdBefore = keyStore().getCreationDate(alias)
        assertNotNull(createdBefore)
        repeat(2) {
            failed(manager().openOrInitialize(), KeyFailure.ORPHANED_KEY)
            assertFalse("no envelope may be written for an orphaned key", envelopeFile.exists())
        }
        // The alias was not replaced: same creation date, and it still
        // unwraps the envelope it originally wrote.
        assertEquals(createdBefore, keyStore().getCreationDate(alias))
        assertEquals(KeyEnvelope.PASSPHRASE_BYTES, manager().unwrapWithCurrentKey(retainedEnvelope).size)
    }

    @Test
    fun plaintextSqliteFileAtTheEncryptedPathIsRejectedUnchanged() {
        dir.mkdirs()
        val plaintext = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII) + ByteArray(4080) { 7 }
        dbFile.writeBytes(plaintext)
        failed(manager().openOrInitialize(), KeyFailure.PLAINTEXT_DATABASE_AT_ENCRYPTED_PATH)
        assertArrayEquals(plaintext, dbFile.readBytes())
        assertFalse(aliasExists())
        assertFalse(envelopeFile.exists())
    }

    // ---- Legacy database -----------------------------------------------------------------------

    @Test
    fun legacyDatabaseIsClassifiedAndNeverModified() {
        val legacy = File(File(dir, "legacy"), SecureDatabaseKeyManager.LEGACY_DATABASE_FILE_NAME)
        assertEquals(LegacyDatabaseState.ABSENT, manager().classifyLegacyDatabase())
        legacy.parentFile!!.mkdirs()
        legacy.writeBytes(ByteArray(0))
        assertEquals(LegacyDatabaseState.EMPTY, manager().classifyLegacyDatabase())
        legacy.writeBytes(ByteArray(2048) { 0x5A })
        assertEquals(LegacyDatabaseState.UNRECOGNIZED, manager().classifyLegacyDatabase())
        val plaintext = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII) + ByteArray(4080) { 3 }
        legacy.writeBytes(plaintext)
        val before = sha256(legacy)
        val modified = legacy.lastModified()
        val r = ready(manager().openOrInitialize())
        assertEquals(LegacyDatabaseState.PLAINTEXT_SQLITE, r.legacyDatabase)
        assertArrayEquals(before, sha256(legacy))
        assertEquals(modified, legacy.lastModified())
    }

    // ---- Destruction ---------------------------------------------------------------------------

    @Test
    fun destroyRemovesAliasEnvelopeAndDatabaseFilesAndRetainedCopiesCannotBeUnwrapped() {
        val passphrase = initializeWithDatabase()
        for (s in SecureDatabaseKeyManager.DATABASE_SIDECAR_SUFFIXES) {
            File(dir, SecureDatabaseKeyManager.DATABASE_FILE_NAME + s).writeBytes(ByteArray(32))
        }
        val retainedEnvelope = envelopeFile.readBytes()
        val m = manager()
        assertArrayEquals(passphrase, m.unwrapWithCurrentKey(retainedEnvelope))

        val report = m.destroy()
        assertTrue(report.envelopeDeleted)
        assertTrue(report.keyDeleted)
        assertTrue(report.databaseFilesRemaining.isEmpty())
        assertEquals(4, report.databaseFilesDeleted.size)
        assertFalse(aliasExists())
        assertFalse(envelopeFile.exists())
        assertFalse(dbFile.exists())

        // Cryptographic erasure: a retained copy of the envelope can no longer
        // be unwrapped, because the only key that could do it is gone.
        try {
            m.unwrapWithCurrentKey(retainedEnvelope)
            fail("a retained envelope must not be unwrappable after destroy")
        } catch (e: java.security.GeneralSecurityException) {
            // expected
        }
        // Restoring the old envelope without its key fails closed.
        envelopeFile.writeBytes(retainedEnvelope)
        failed(manager().openOrInitialize(), KeyFailure.ENVELOPE_WITHOUT_KEY)
        assertFalse(aliasExists())
    }

    // ---- Security level and the release policy ---------------------------------------------

    @Test
    fun securityLevelIsReportedAndReleasePolicyFailsClosedWithoutHardwareEvidence() {
        val r = ready(manager().openOrInitialize())
        val level = r.security.reportedLevel
        Log.i(
            "SenseKeyTest",
            "reportedSecurityLevel=$level emulator=${r.security.emulator} " +
                "hardwareBackedEvidence=${r.security.hardwareBackedEvidence} sdk=${Build.VERSION.SDK_INT} " +
                "model=${Build.MODEL}",
        )
        // Hardening M2: a test namespace is never production eligible, whatever the key.
        assertFalse("a test namespace is never production eligible", r.productionEligible)
        if (emulator) assertFalse("an emulator key is never hardware evidence", r.security.hardwareBackedEvidence)
        r.passphrase.fill(0)
        manager().destroy()

        // A non-debuggable (release) configuration on this device.
        val release = manager(allowWithoutHardwareEvidence = false).openOrInitialize()
        if (r.security.hardwareBackedEvidence) {
            assertTrue(ready(release).productionEligible)
        } else {
            failed(release, KeyFailure.INSECURE_KEY_STORAGE)
            assertFalse("rollback must delete the new key", aliasExists())
            assertFalse("rollback must delete the new envelope", envelopeFile.exists())
            assertFalse("rollback must delete the setup marker", File(dir, SecureDatabaseKeyManager.SETUP_MARKER_FILE_NAME).exists())
        }
    }

    @Test
    fun releasePolicyAlsoRefusesToUnwrapAnExistingSoftwareKey() {
        initializeWithDatabase()
        val m = manager(allowWithoutHardwareEvidence = false)
        val r = m.openOrInitialize()
        if (r is KeyOpenResult.Failed) {
            assertEquals(KeyFailure.INSECURE_KEY_STORAGE, r.failure)
            assertTrue("nothing is deleted", aliasExists() && envelopeFile.exists() && dbFile.exists())
        } else {
            assertTrue((r as KeyOpenResult.Ready).security.hardwareBackedEvidence)
        }
    }

    // ---- Logs ----------------------------------------------------------------------------------

    @Test
    fun noKeyMaterialAppearsInTheProcessLog() {
        val passphrase = initializeWithDatabase()
        // Exercise every path that could log.
        ready(manager().openOrInitialize())
        envelopeFile.writeBytes(envelopeFile.readBytes().also { it[30] = (it[30].toInt() xor 1).toByte() })
        manager().openOrInitialize()
        manager().destroy()
        val log = Runtime.getRuntime().exec(arrayOf("logcat", "-d", "-v", "raw")).inputStream.bufferedReader().readText()
        assertTrue("logcat returned nothing to check", log.isNotEmpty())
        val forms =
            listOf(
                hex(passphrase),
                hex(passphrase).uppercase(),
                Base64.encodeToString(passphrase, Base64.NO_WRAP),
                Base64.encodeToString(passphrase, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING),
                passphrase.joinToString(","),
            )
        for (f in forms) assertFalse("key material found in logcat", log.contains(f))
    }
}
