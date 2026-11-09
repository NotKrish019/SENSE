package org.sense.mindpulse.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertTrue
import java.io.File
import java.nio.ByteBuffer
import java.security.KeyStore
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Shared helpers for the Milestone J hardening tests. Every environment has its
 * own directory under noBackupFilesDir/android_test and its own Keystore
 * alias, so the app's real participant key and files are never touched.
 */
internal class KeyTestEnv(val context: Context, tag: String) {
    private val id = UUID.randomUUID().toString().replace("-", "").take(12)
    val dir = File(File(context.noBackupFilesDir, "android_test"), "${tag}_$id")
    val alias = "sense_db_wrapping_key_v1__androidtest_${tag}_$id"
    val emulator = SecureDatabaseKeyManager.isProbablyEmulator()

    val dbFile get() = File(dir, SecureDatabaseKeyManager.DATABASE_FILE_NAME)
    val envelopeFile get() = File(dir, SecureDatabaseKeyManager.ENVELOPE_FILE_NAME)
    val markerFile get() = File(dir, SecureDatabaseKeyManager.SETUP_MARKER_FILE_NAME)

    fun manager(
        purpose: StoragePurpose = StoragePurpose.TEST_NAMESPACE,
        policy: BuildPolicy = BuildPolicy(BuildKind.DEBUG, debuggable = true),
        strongBoxAvailable: Boolean = false,
        emulator: Boolean = this.emulator,
        levelProbe: ((SecretKey) -> KeySecurityLevel)? = null,
        keyGeneration: ((Boolean) -> SecretKey)? = null,
        fault: ((InitStage) -> Unit)? = null,
    ) = SecureDatabaseKeyManager(
        storageDir = dir,
        legacyDatabaseFile = File(File(dir, "legacy"), SecureDatabaseKeyManager.LEGACY_DATABASE_FILE_NAME),
        keyAlias = alias,
        purpose = purpose,
        buildPolicy = policy,
        strongBoxAvailable = strongBoxAvailable,
        emulator = emulator,
        securityLevelProbe = levelProbe,
        keyGeneration = keyGeneration,
        faultInjector = fault,
    )

    fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun aliasExists() = keyStore().containsAlias(alias)

    /** The same key specification the manager uses, generated directly in the Keystore. */
    fun generateRealKey(strongBox: Boolean): SecretKey {
        val builder =
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) builder.setIsStrongBoxBacked(true)
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(builder.build())
        return gen.generateKey()
    }

    /** A setup marker in the documented format 1, with an explicit creation time. */
    fun writeMarker(createdAtMillis: Long, markerAlias: String = alias) {
        dir.mkdirs()
        val a = markerAlias.toByteArray(Charsets.UTF_8)
        markerFile.writeBytes(
            ByteBuffer.allocate(4 + 1 + 8 + 2 + a.size)
                .put(byteArrayOf(0x53, 0x4E, 0x53, 0x55))
                .put(1.toByte())
                .putLong(createdAtMillis)
                .putShort(a.size.toShort())
                .put(a)
                .array(),
        )
    }

    fun standInDatabase() {
        dir.mkdirs()
        dbFile.writeBytes(ByteArray(4096).also { java.security.SecureRandom().nextBytes(it) })
    }

    fun cleanup() {
        try {
            keyStore().deleteEntry(alias)
        } catch (_: Exception) {
        }
        dir.deleteRecursively()
    }
}

internal fun ready(r: KeyOpenResult): KeyOpenResult.Ready {
    assertTrue("expected Ready, got $r", r is KeyOpenResult.Ready)
    return r as KeyOpenResult.Ready
}

internal fun failedWith(r: KeyOpenResult, expected: KeyFailure) {
    assertTrue("expected Failed($expected), got $r", r is KeyOpenResult.Failed && r.failure == expected)
}

/** The outcome of one platform-channel call, as Dart would receive it. */
internal class ChannelOutcome(val success: Map<*, *>?, val errorCode: String?, val notImplemented: Boolean)

/** Calls [channel] exactly as the Flutter engine would and waits for the reply. */
internal fun SecureDatabaseChannel.call(method: String, args: Map<String, Any?> = emptyMap()): ChannelOutcome {
    val latch = CountDownLatch(1)
    var outcome: ChannelOutcome? = null
    onMethodCall(
        MethodCall(method, HashMap(args)),
        object : MethodChannel.Result {
            override fun success(result: Any?) {
                outcome = ChannelOutcome(result as Map<*, *>?, null, false)
                latch.countDown()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                outcome = ChannelOutcome(null, errorCode, false)
                latch.countDown()
            }

            override fun notImplemented() {
                outcome = ChannelOutcome(null, null, true)
                latch.countDown()
            }
        },
    )
    assertTrue("channel call $method timed out", latch.await(30, TimeUnit.SECONDS))
    return outcome!!
}
