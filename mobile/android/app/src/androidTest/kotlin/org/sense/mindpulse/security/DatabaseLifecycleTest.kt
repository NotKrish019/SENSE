package org.sense.mindpulse.security

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.security.KeyStore
import java.util.UUID
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Hardening finding M1: one process-wide lifecycle owner. Opening and
 * destruction are mutually exclusive across providers and Flutter engines.
 *
 * Registry tests use a fresh key per test. Channel tests go through
 * SecureDatabaseChannel (one instance per simulated engine) and a debug test
 * namespace, exactly as Dart calls it. Concurrency uses barriers, not sleeps.
 */
class DatabaseLifecycleTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val reg = DatabaseLifecycleRegistry
    private lateinit var key: String
    private lateinit var ns: String

    @Before
    fun setUp() {
        val id = UUID.randomUUID().toString().replace("-", "").take(10)
        key = "/test/lifecycle/$id"
        ns = "lifecycle_$id"
    }

    @After
    fun tearDown() {
        // Namespace leases may be orphaned on purpose; clean the files and key directly.
        try {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                .deleteEntry("${SecureDatabaseKeyManager.KEY_ALIAS}__$ns")
        } catch (_: Exception) {
        }
        File(File(context.noBackupFilesDir, "test_namespaces"), ns).deleteRecursively()
    }

    private fun granted(a: DatabaseLifecycleRegistry.Acquire): DatabaseLifecycleRegistry.Acquire.Granted {
        assertTrue("expected Granted, got $a", a is DatabaseLifecycleRegistry.Acquire.Granted)
        return a as DatabaseLifecycleRegistry.Acquire.Granted
    }

    private fun busy(a: DatabaseLifecycleRegistry.Acquire, reason: LifecycleBusyReason) {
        assertTrue("expected Busy($reason), got $a", a is DatabaseLifecycleRegistry.Acquire.Busy && a.reason == reason)
    }

    // ---- Registry ------------------------------------------------------------------------------

    @Test
    fun openingAndDestructionAreMutuallyExclusive() {
        val lease = granted(reg.beginOpen(key, owner = 1))
        assertEquals("opening", reg.stateOf(key))
        // Destroy during opening, and a second open (same or other engine), are refused.
        assertEquals(LifecycleBusyReason.OPEN_IN_PROGRESS, reg.beginDestroy(key))
        busy(reg.beginOpen(key, owner = 2), LifecycleBusyReason.OPEN_IN_PROGRESS)
        busy(reg.beginOpen(key, owner = 1), LifecycleBusyReason.OPEN_IN_PROGRESS)

        assertTrue(reg.commitOpen(key, lease.leaseId, owner = 1))
        assertEquals("open", reg.stateOf(key))
        // Destroy while open, also through another engine, is refused.
        assertEquals(LifecycleBusyReason.DATABASE_OPEN, reg.beginDestroy(key))
        busy(reg.beginOpen(key, owner = 2), LifecycleBusyReason.DATABASE_OPEN)

        assertTrue(reg.release(key, lease.leaseId, owner = 1))
        assertEquals("idle", reg.stateOf(key))
        assertNull(reg.beginDestroy(key))
        assertEquals("destroying", reg.stateOf(key))
        // No open may start during destruction.
        busy(reg.beginOpen(key, owner = 2), LifecycleBusyReason.DESTROY_IN_PROGRESS)
        assertEquals(LifecycleBusyReason.DESTROY_IN_PROGRESS, reg.beginDestroy(key))
        reg.endDestroy(key)
        // Open immediately after destroy completes.
        granted(reg.beginOpen(key, owner = 2)).also { reg.release(key, it.leaseId, 2) }
        assertEquals("idle", reg.stateOf(key))
    }

    @Test
    fun aFailedOpenReleasesTheLeaseAndRepeatedReleaseIsSafe() {
        val lease = granted(reg.beginOpen(key, 1))
        assertTrue(reg.release(key, lease.leaseId, 1)) // failed open
        assertFalse("second release is a no-op", reg.release(key, lease.leaseId, 1))
        assertFalse("a released lease cannot be committed", reg.commitOpen(key, lease.leaseId, 1))
        assertEquals("idle", reg.stateOf(key))
    }

    @Test
    fun onlyTheOwningEngineCanCommitOrReleaseALease() {
        val lease = granted(reg.beginOpen(key, 1))
        assertFalse(reg.commitOpen(key, lease.leaseId, owner = 2))
        assertFalse(reg.release(key, lease.leaseId, owner = 2))
        assertFalse(reg.commitOpen(key, "0".repeat(32), owner = 1))
        assertEquals("opening", reg.stateOf(key))
        reg.release(key, lease.leaseId, 1)
    }

    @Test
    fun aDetachedEnginesLeaseIsOrphanedNotReleasedAndCanOnlyBeAdopted() {
        val lease = granted(reg.beginOpen(key, 1))
        assertTrue(reg.commitOpen(key, lease.leaseId, 1))
        reg.detachOwner(1)
        assertEquals("orphaned", reg.stateOf(key))
        assertEquals(LifecycleBusyReason.ORPHANED_CONNECTION, reg.beginDestroy(key))
        assertFalse("an orphaned lease cannot be released", reg.release(key, lease.leaseId, 1))
        assertEquals("orphaned", reg.stateOf(key))

        // A failed adoption restores the orphaned lease (the connection may still be open).
        val adoption = granted(reg.beginOpen(key, 2))
        assertTrue(adoption.adopted)
        reg.release(key, adoption.leaseId, 2)
        assertEquals("orphaned", reg.stateOf(key))

        // A successful adoption takes over; closing it then frees the database.
        val adopted = granted(reg.beginOpen(key, 2))
        assertTrue(reg.commitOpen(key, adopted.leaseId, 2))
        assertEquals("open", reg.stateOf(key))
        assertTrue(reg.release(key, adopted.leaseId, 2))
        assertEquals("idle", reg.stateOf(key))
    }

    @Test
    fun simultaneousOpenAttemptsGrantExactlyOneLease() {
        val threads = 16
        val pool = Executors.newFixedThreadPool(threads)
        try {
            repeat(50) { round ->
                val k = "$key/$round"
                val barrier = CyclicBarrier(threads)
                val results =
                    (1..threads).map { owner ->
                        pool.submit<DatabaseLifecycleRegistry.Acquire> {
                            barrier.await(10, TimeUnit.SECONDS)
                            reg.beginOpen(k, owner)
                        }
                    }.map { it.get(10, TimeUnit.SECONDS) }
                val grants = results.filterIsInstance<DatabaseLifecycleRegistry.Acquire.Granted>()
                assertEquals("round $round", 1, grants.size)
                val winner = results.indexOf(grants.single()) + 1
                reg.release(k, grants.single().leaseId, winner)
            }
        } finally {
            pool.shutdownNow()
        }
    }

    @Test
    fun simultaneousOpenAndDestroyNeverBothProceed() {
        val pool = Executors.newFixedThreadPool(2)
        try {
            repeat(200) { round ->
                val k = "$key/race/$round"
                val barrier = CyclicBarrier(2)
                val open = pool.submit<DatabaseLifecycleRegistry.Acquire> { barrier.await(10, TimeUnit.SECONDS); reg.beginOpen(k, 1) }
                val destroy = pool.submit<LifecycleBusyReason?> { barrier.await(10, TimeUnit.SECONDS); reg.beginDestroy(k) }
                val opened = open.get(10, TimeUnit.SECONDS) is DatabaseLifecycleRegistry.Acquire.Granted
                val destroying = destroy.get(10, TimeUnit.SECONDS) == null
                assertTrue("round $round: exactly one may proceed (open=$opened destroy=$destroying)", opened xor destroying)
                if (destroying) reg.endDestroy(k)
                val o = open.get()
                if (o is DatabaseLifecycleRegistry.Acquire.Granted) reg.release(k, o.leaseId, 1)
            }
        } finally {
            pool.shutdownNow()
        }
    }

    // ---- Channel: two engines in one process -------------------------------------------------

    @Test
    fun aSecondEngineCannotDestroyOrOpenWhileTheFirstOpensOrHoldsTheDatabase() {
        val a = SecureDatabaseChannel(context)
        val b = SecureDatabaseChannel(context)
        val nsArg = mapOf("testNamespace" to ns)

        val opened = a.call("openKey", nsArg).success!!
        assertEquals("ready", opened["status"])
        val lease = opened["leaseId"] as String
        assertEquals(32, lease.length)

        // A is "opening" (between key unwrap and registration).
        assertEquals("openInProgress", b.call("destroy", nsArg).success!!["busyReason"])
        b.call("openKey", nsArg).success!!.let {
            assertEquals("lifecycleBusy", it["failure"])
            assertEquals("openInProgress", it["busyReason"])
            assertNull("a refused open never returns key material", it["passphrase"])
        }
        // A registers its connection.
        assertEquals(true, a.call("commitOpen", nsArg + ("leaseId" to lease)).success!!["committed"])
        assertEquals("databaseOpen", b.call("destroy", nsArg).success!!["busyReason"])
        assertEquals("databaseOpen", a.call("destroy", nsArg).success!!["busyReason"])
        val inspect = b.call("inspect", nsArg).success!!
        assertEquals("open", inspect["lifecycle"])
        assertEquals("the old key may not be deleted while a connection is registered", true, inspect["keyAliasPresent"])
        assertEquals(true, inspect["envelopePresent"])

        // Only A may release; then B can destroy, and a new open works right after.
        assertEquals(false, b.call("release", nsArg + ("leaseId" to lease)).success!!["released"])
        assertEquals(true, a.call("release", nsArg + ("leaseId" to lease)).success!!["released"])
        assertEquals("repeated release is a no-op", false, a.call("release", nsArg + ("leaseId" to lease)).success!!["released"])
        val destroyed = b.call("destroy", nsArg).success!!
        assertEquals("destroyed", destroyed["status"])
        assertEquals(true, destroyed["keyDeleted"])
        val again = b.call("openKey", nsArg).success!!
        assertEquals("ready", again["status"])
        assertEquals(true, again["firstInitialization"])
        b.call("release", nsArg + ("leaseId" to again["leaseId"]))
        assertEquals("destroyed", b.call("destroy", nsArg).success!!["status"])
    }

    @Test
    fun aDetachedEnginesConnectionBlocksDestructionAndIsAdoptedOnlyThroughTheGate() {
        val a = SecureDatabaseChannel(context)
        val b = SecureDatabaseChannel(context)
        val nsArg = mapOf("testNamespace" to ns)
        val opened = a.call("openKey", nsArg).success!!
        a.call("commitOpen", nsArg + ("leaseId" to opened["leaseId"]))
        a.detach()
        // detach() runs on the same process-wide worker, so it is ordered before this call.
        assertEquals("orphanedConnection", b.call("destroy", nsArg).success!!["busyReason"])
        assertEquals("orphaned", b.call("inspect", nsArg).success!!["lifecycle"])

        val adopted = b.call("openKey", nsArg).success!!
        assertEquals("ready", adopted["status"])
        assertEquals(true, adopted["adoptedOrphanedConnection"])
        assertEquals(opened["passphrase"], adopted["passphrase"])
        // Abandoning the adoption restores the orphaned lease: still not destroyable.
        b.call("release", nsArg + ("leaseId" to adopted["leaseId"]))
        assertEquals("orphanedConnection", b.call("destroy", nsArg).success!!["busyReason"])
    }

    @Test
    fun malformedLeaseIdsAreRejected() {
        val ch = SecureDatabaseChannel(context)
        val nsArg = mapOf("testNamespace" to ns)
        for (bad in listOf(null, "", "XYZ", "0".repeat(31), "G".repeat(32))) {
            assertEquals("$bad", "invalidArgument", ch.call("commitOpen", nsArg + ("leaseId" to bad)).errorCode)
            assertEquals("$bad", "invalidArgument", ch.call("release", nsArg + ("leaseId" to bad)).errorCode)
        }
        assertTrue(ch.call("unknownMethod").notImplemented)
    }
}
