package org.sense.mindpulse.security

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Platform channel for the encrypted-database key and lifecycle (Milestone J).
 *
 * Nothing calls this channel in the shipped app: no production code opens the
 * encrypted database yet.
 *
 * One instance per Flutter engine; every instance shares ONE process-wide
 * worker thread and the process-wide [DatabaseLifecycleRegistry], so two
 * engines (or two Dart providers) can never race a first-time
 * initialization, an open and a destroy against each other.
 *
 * Methods:
 * - `inspect`: component presence and lifecycle state; creates nothing.
 * - `openKey`: takes the lifecycle lease FIRST, then runs the policy gate and
 *   the fail-closed key state machine. On success the reply holds the
 *   passphrase and the lease id; on failure the lease is released.
 * - `commitOpen(leaseId)`: the Dart side opened and verified the database.
 * - `release(leaseId)`: the open failed, or the connection was closed.
 * - `destroy`: refused while any lease exists (open, opening or orphaned).
 *
 * The passphrase leaves native code only in the `openKey` success reply, as a
 * 64-character lowercase hex String (the format the SQLCipher driver
 * receives). Native byte and char buffers are zeroed after use; the String
 * itself is immutable and cannot be reliably cleared (documented limitation).
 * Errors carry type names and codes only, never messages that could include
 * key material. Nothing here logs.
 */
class SecureDatabaseChannel internal constructor(
    private val context: Context,
    private val policy: BuildPolicy,
) : MethodChannel.MethodCallHandler {
    constructor(context: Context) : this(context, BuildPolicy.current(context))

    companion object {
        const val NAME = "org.sense.mindpulse/secure_database"
        private val HEX = "0123456789abcdef".toCharArray()
        private val METHODS = setOf("inspect", "openKey", "commitOpen", "release", "destroy")

        /** Process-wide: every engine's calls run one at a time, in order. */
        private val worker: ExecutorService = Executors.newSingleThreadExecutor()
        private val nextOwnerId = AtomicInteger(1)
    }

    /** Identifies this engine's leases in [DatabaseLifecycleRegistry]. */
    internal val ownerId: Int = nextOwnerId.getAndIncrement()
    private val main = Handler(Looper.getMainLooper())

    /**
     * The engine this channel belongs to is going away. Its leases become
     * orphaned (never released): the driver may still hold the connection.
     */
    fun detach() {
        worker.execute { DatabaseLifecycleRegistry.detachOwner(ownerId) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val method = call.method
        if (method !in METHODS) {
            result.notImplemented()
            return
        }
        val namespace: String?
        val leaseId: String?
        try {
            namespace = call.argument<String>("testNamespace")
            leaseId = call.argument<String>("leaseId")
        } catch (e: Exception) {
            result.error("invalidArgument", "Invalid secure-database request.", null)
            return
        }
        worker.execute {
            val reply: Map<String, Any?> =
                try {
                    val manager = SecureDatabaseKeyManager.forApp(context, namespace, policy)
                    when (method) {
                        "inspect" -> inspect(manager)
                        "openKey" -> openKey(manager)
                        "commitOpen" -> commitOpen(manager, requireLease(leaseId))
                        "release" -> release(manager, requireLease(leaseId))
                        else -> destroy(manager)
                    }
                } catch (e: IllegalArgumentException) {
                    main.post { result.error("invalidArgument", "Invalid secure-database request.", null) }
                    return@execute
                } catch (e: Exception) {
                    main.post { result.error("secureDatabaseError", e.javaClass.simpleName, null) }
                    return@execute
                }
            main.post { result.success(reply) }
        }
    }

    private fun requireLease(leaseId: String?): String {
        require(leaseId != null && leaseId.length == 32 && leaseId.all { it in '0'..'9' || it in 'a'..'f' }) { "invalid lease" }
        return leaseId
    }

    private fun paths(m: SecureDatabaseKeyManager): Map<String, Any?> =
        mapOf(
            "databasePath" to m.databaseFile.absolutePath,
            "envelopePath" to m.envelopePath.absolutePath,
            "legacyDatabasePath" to m.legacyDatabasePath.absolutePath,
            "storageDirectory" to m.storageDirectory.absolutePath,
            "buildKind" to policy.kind.wireName,
        )

    private fun inspect(m: SecureDatabaseKeyManager): Map<String, Any?> {
        val s = m.inspect()
        return paths(m) +
            mapOf(
                "databasePresent" to s.databasePresent,
                "envelopePresent" to s.envelopePresent,
                "keyAliasPresent" to s.keyAliasPresent,
                "setupPending" to s.setupPending,
                "legacyDatabase" to s.legacyDatabase.wireName,
                "lifecycle" to DatabaseLifecycleRegistry.stateOf(m.lifecycleKey),
            )
    }

    private fun security(a: KeySecurityAssessment?): Map<String, Any?> =
        if (a == null) {
            emptyMap()
        } else {
            mapOf(
                "securityLevel" to a.reportedLevel.wireName,
                "emulator" to a.emulator,
                "hardwareBackedEvidence" to a.hardwareBackedEvidence,
            )
        }

    private fun openKey(m: SecureDatabaseKeyManager): Map<String, Any?> {
        // The lease is acquired BEFORE the key is resolved or generated.
        val lease =
            when (val a = DatabaseLifecycleRegistry.beginOpen(m.lifecycleKey, ownerId)) {
                is DatabaseLifecycleRegistry.Acquire.Busy ->
                    return paths(m) +
                        mapOf(
                            "status" to "failed",
                            "failure" to "lifecycleBusy",
                            "busyReason" to a.reason.wireName,
                            "legacyDatabase" to m.classifyLegacyDatabase().wireName,
                        )
                is DatabaseLifecycleRegistry.Acquire.Granted -> a
            }
        val r =
            try {
                m.openOrInitialize()
            } catch (e: Throwable) {
                DatabaseLifecycleRegistry.release(m.lifecycleKey, lease.leaseId, ownerId)
                throw e
            }
        return when (r) {
            is KeyOpenResult.Failed -> {
                DatabaseLifecycleRegistry.release(m.lifecycleKey, lease.leaseId, ownerId)
                paths(m) + security(r.security) +
                    mapOf(
                        "status" to "failed",
                        "failure" to r.failure.wireName,
                        "legacyDatabase" to r.legacyDatabase.wireName,
                    )
            }
            is KeyOpenResult.Ready -> {
                val chars = CharArray(r.passphrase.size * 2)
                try {
                    for (i in r.passphrase.indices) {
                        val v = r.passphrase[i].toInt() and 0xFF
                        chars[i * 2] = HEX[v ushr 4]
                        chars[i * 2 + 1] = HEX[v and 0x0F]
                    }
                    paths(m) + security(r.security) +
                        mapOf(
                            "status" to "ready",
                            "passphrase" to String(chars),
                            "leaseId" to lease.leaseId,
                            "adoptedOrphanedConnection" to lease.adopted,
                            "productionEligible" to r.productionEligible,
                            "firstInitialization" to r.firstInitialization,
                            "recoveredMissingDatabase" to r.recoveredMissingDatabase,
                            "legacyDatabase" to r.legacyDatabase.wireName,
                            "strongBoxFallback" to r.strongBoxFallback?.wireName,
                        )
                } finally {
                    chars.fill('\u0000')
                    r.passphrase.fill(0)
                }
            }
        }
    }

    private fun commitOpen(m: SecureDatabaseKeyManager, leaseId: String): Map<String, Any?> {
        val committed = DatabaseLifecycleRegistry.commitOpen(m.lifecycleKey, leaseId, ownerId)
        if (committed) m.completeSetup()
        return mapOf("committed" to committed)
    }

    private fun release(m: SecureDatabaseKeyManager, leaseId: String): Map<String, Any?> =
        mapOf("released" to DatabaseLifecycleRegistry.release(m.lifecycleKey, leaseId, ownerId))

    private fun destroy(m: SecureDatabaseKeyManager): Map<String, Any?> {
        val busy = DatabaseLifecycleRegistry.beginDestroy(m.lifecycleKey)
        if (busy != null) return mapOf("status" to "busy", "busyReason" to busy.wireName)
        try {
            val d = m.destroy()
            return mapOf(
                "status" to "destroyed",
                "envelopeDeleted" to d.envelopeDeleted,
                "keyDeleted" to d.keyDeleted,
                "databaseFilesDeleted" to d.databaseFilesDeleted,
                "databaseFilesRemaining" to d.databaseFilesRemaining,
            )
        } finally {
            DatabaseLifecycleRegistry.endDestroy(m.lifecycleKey)
        }
    }
}
