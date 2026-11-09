package org.sense.mindpulse.security

import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import java.security.InvalidAlgorithmParameterException
import java.security.KeyStore
import java.security.ProviderException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Hardening finding L4: StrongBox is preferred; the key falls back to the
 * TEE/default Keystore ONLY when StrongBox is unavailable or the Keystore
 * provider rejected the StrongBox generation. Any other error fails
 * initialization. The resulting level is the key's real reported level.
 *
 * This emulator has no StrongBox: the real StrongBox path is exercised as
 * "unavailable". A successful StrongBox key needs compatible physical hardware.
 */
class StrongBoxFallbackTest {
    private lateinit var env: KeyTestEnv
    private val calls = mutableListOf<Boolean>()

    @Before
    fun setUp() {
        env = KeyTestEnv(InstrumentationRegistry.getInstrumentation().targetContext, "strongbox")
    }

    @After
    fun tearDown() = env.cleanup()

    private fun recording(onStrongBox: () -> SecretKey, onDefault: () -> SecretKey = { env.generateRealKey(false) }) =
        { strongBox: Boolean ->
            calls += strongBox
            if (strongBox) onStrongBox() else onDefault()
        }

    private fun assertRolledBack() {
        assertFalse(env.aliasExists())
        assertFalse(env.envelopeFile.exists())
        assertFalse(env.markerFile.exists())
    }

    /** A genuine android.security.KeyStoreException, produced by the Keystore itself. */
    private fun realKeystoreException(): Throwable {
        val alias = "${env.alias}_encrypt_only"
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        val key = gen.generateKey()
        try {
            Cipher.getInstance("AES/GCM/NoPadding").init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, ByteArray(12)))
            throw AssertionError("decrypting with an encrypt-only key must fail")
        } catch (e: Exception) {
            var t: Throwable? = e
            while (t != null) {
                if (t.javaClass.name == SecureDatabaseKeyManager.KEYSTORE_EXCEPTION_CLASS) return t
                t = t.cause
            }
            throw AssertionError("no android.security.KeyStoreException in ${e.javaClass.name}", e)
        } finally {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(alias)
        }
    }

    @Test
    fun theRealStrongBoxRequestOnThisDevice() {
        val hasStrongBox =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                env.context.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        val r = ready(env.manager(strongBoxAvailable = true).openOrInitialize()) // real Keystore, no seam
        Log.i("SenseKeyTest", "strongBoxFeature=$hasStrongBox fallback=${r.strongBoxFallback} level=${r.security.reportedLevel}")
        if (r.strongBoxFallback == null) {
            assertEquals("a StrongBox key reports STRONGBOX", KeySecurityLevel.STRONGBOX, r.security.reportedLevel)
        } else {
            assertEquals(StrongBoxFallback.UNAVAILABLE, r.strongBoxFallback)
            assertTrue("the TEE/default key's real level is reported", r.security.reportedLevel != KeySecurityLevel.STRONGBOX)
        }
        if (!hasStrongBox) assertNotNull("no StrongBox here: the real request must fall back", r.strongBoxFallback)
    }

    @Test
    fun strongBoxAvailableIsUsedWithoutFallback() {
        val r = ready(env.manager(strongBoxAvailable = true, keyGeneration = recording({ env.generateRealKey(false) })).openOrInitialize())
        assertEquals(listOf(true), calls)
        assertNull(r.strongBoxFallback)
    }

    @Test
    fun strongBoxUnavailableFallsBackToTheDefaultKeystore() {
        val r =
            ready(
                env.manager(
                    strongBoxAvailable = true,
                    keyGeneration = recording({ throw StrongBoxUnavailableException("no StrongBox") }),
                ).openOrInitialize(),
            )
        assertEquals(listOf(true, false), calls)
        assertEquals(StrongBoxFallback.UNAVAILABLE, r.strongBoxFallback)
        assertEquals("the fallback key's actual level", env.manager().assess(env.keyStore().getKey(env.alias, null) as SecretKey).reportedLevel, r.security.reportedLevel)
    }

    @Test
    fun aWrappedStrongBoxUnavailableExceptionAlsoFallsBack() {
        val r =
            ready(
                env.manager(
                    strongBoxAvailable = true,
                    keyGeneration = recording({ throw ProviderException("wrapped", StrongBoxUnavailableException()) }),
                ).openOrInitialize(),
            )
        assertEquals(StrongBoxFallback.UNAVAILABLE, r.strongBoxFallback)
    }

    @Test
    fun theProviderRejectingStrongBoxFallsBackToTheDefaultKeystore() {
        val kse = realKeystoreException()
        val r =
            ready(
                env.manager(
                    strongBoxAvailable = true,
                    keyGeneration = recording({ throw ProviderException("Failed to generate key", kse) }),
                ).openOrInitialize(),
            )
        assertEquals(listOf(true, false), calls)
        assertEquals(StrongBoxFallback.PROVIDER_REJECTED, r.strongBoxFallback)
    }

    @Test
    fun theFallbackStillAppliesTheReleaseHardwareGate() {
        // StrongBox unavailable, the default key reports SOFTWARE: a release
        // participant database is refused, not silently downgraded.
        val m =
            env.manager(
                purpose = StoragePurpose.PARTICIPANT,
                policy = BuildPolicy(BuildKind.RELEASE, debuggable = false),
                strongBoxAvailable = true,
                emulator = false,
                levelProbe = { KeySecurityLevel.SOFTWARE },
                keyGeneration = recording({ throw StrongBoxUnavailableException() }),
            )
        failedWith(m.openOrInitialize(), KeyFailure.INSECURE_KEY_STORAGE)
        assertRolledBack()
    }

    @Test
    fun otherStrongBoxErrorsAreRealFailuresWithoutFallback() {
        val errors =
            listOf<() -> Throwable>(
                { InvalidAlgorithmParameterException("bad spec") },
                { ProviderException("not from the Keystore", java.io.IOException("io")) },
                { ProviderException("no cause") },
                { IllegalStateException("unexpected") },
            )
        for (error in errors) {
            calls.clear()
            val m = env.manager(strongBoxAvailable = true, keyGeneration = recording({ throw error() }))
            failedWith(m.openOrInitialize(), KeyFailure.INITIALIZATION_FAILED)
            assertEquals("no fallback attempt", listOf(true), calls)
            assertRolledBack()
        }
    }

    @Test
    fun anActualKeyGenerationFailureAfterTheFallbackFailsInitialization() {
        val m =
            env.manager(
                strongBoxAvailable = true,
                keyGeneration = recording({ throw StrongBoxUnavailableException() }, { throw ProviderException("TEE failure") }),
            )
        failedWith(m.openOrInitialize(), KeyFailure.INITIALIZATION_FAILED)
        assertEquals(listOf(true, false), calls)
        assertRolledBack()
    }

    @Test
    fun noStrongBoxAttemptWhenTheDeviceDoesNotAdvertiseIt() {
        val r = ready(env.manager(strongBoxAvailable = false, keyGeneration = recording({ throw AssertionError("not called") })).openOrInitialize())
        assertEquals(listOf(false), calls)
        assertNull(r.strongBoxFallback)
    }

    @Test
    fun classifierIsNarrow() {
        assumeTrue(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        val kse = realKeystoreException()
        assertEquals(StrongBoxFallback.UNAVAILABLE, SecureDatabaseKeyManager.strongBoxFallbackFor(StrongBoxUnavailableException()))
        assertEquals(StrongBoxFallback.PROVIDER_REJECTED, SecureDatabaseKeyManager.strongBoxFallbackFor(ProviderException("x", kse)))
        assertNull("a bare KeyStoreException is not a provider rejection", SecureDatabaseKeyManager.strongBoxFallbackFor(kse))
        assertNull(SecureDatabaseKeyManager.strongBoxFallbackFor(RuntimeException("x", kse)))
        assertNull(SecureDatabaseKeyManager.strongBoxFallbackFor(InvalidAlgorithmParameterException()))
    }
}
