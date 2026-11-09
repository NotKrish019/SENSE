package org.sense.mindpulse.security

import java.security.SecureRandom

/** Why the lifecycle registry refused an open or a destroy. */
enum class LifecycleBusyReason(val wireName: String) {
    /** Another open of the same database is between key unwrap and registration. */
    OPEN_IN_PROGRESS("openInProgress"),

    /** A registered connection to the database is open. */
    DATABASE_OPEN("databaseOpen"),

    /**
     * A connection was registered by a Flutter engine that has since been
     * detached. The SQLCipher driver keeps native connections in a static map
     * that outlives the engine, so the connection may still be open.
     */
    ORPHANED_CONNECTION("orphanedConnection"),
    DESTROY_IN_PROGRESS("destroyInProgress"),
}

/**
 * Process-wide owner of the encrypted database lifecycle (Milestone J
 * hardening, finding M1). One per Android process, shared by every Flutter
 * engine and every Dart provider in that process.
 *
 * Each storage directory (the participant directory, or one test namespace)
 * has at most one lease. A lease is taken BEFORE the key is resolved or
 * generated and is held until the Dart side reports the connection closed:
 *
 *     (none) --beginOpen--> OPENING --commitOpen--> OPEN --release--> (none)
 *                              \--release (failed open)--> (none)
 *
 * Destroy is refused while any lease exists, and an open is refused while a
 * destroy runs, so opening and destruction are mutually exclusive. When an
 * engine is detached, its leases become orphaned rather than released (the
 * driver may still hold the connection): destroy stays refused, and a later
 * engine may adopt the lease after passing the full key and policy gate again.
 *
 * Every method is synchronized; the channel additionally runs all native
 * key operations on one process-wide thread.
 */
internal object DatabaseLifecycleRegistry {
    enum class Phase(val wireName: String) { OPENING("opening"), OPEN("open") }

    private class Lease(
        val id: String,
        var phase: Phase,
        var owner: Int,
        var orphaned: Boolean,
        /** The orphaned lease this one adopted; restored if the adoption fails before opening. */
        val adoptedFrom: Lease?,
    )

    sealed class Acquire {
        class Granted(val leaseId: String, val adopted: Boolean) : Acquire()

        class Busy(val reason: LifecycleBusyReason) : Acquire()
    }

    private val leases = HashMap<String, Lease>()
    private val destroying = HashSet<String>()
    private val random = SecureRandom()

    private fun newId(): String {
        val b = ByteArray(16).also(random::nextBytes)
        return b.joinToString("") { "%02x".format(it) }
    }

    @Synchronized
    fun beginOpen(key: String, owner: Int): Acquire {
        if (key in destroying) return Acquire.Busy(LifecycleBusyReason.DESTROY_IN_PROGRESS)
        val existing = leases[key]
        if (existing == null) {
            val lease = Lease(newId(), Phase.OPENING, owner, orphaned = false, adoptedFrom = null)
            leases[key] = lease
            return Acquire.Granted(lease.id, adopted = false)
        }
        if (existing.orphaned) {
            val lease = Lease(newId(), Phase.OPENING, owner, orphaned = false, adoptedFrom = existing)
            leases[key] = lease
            return Acquire.Granted(lease.id, adopted = true)
        }
        return Acquire.Busy(
            if (existing.phase == Phase.OPENING) LifecycleBusyReason.OPEN_IN_PROGRESS else LifecycleBusyReason.DATABASE_OPEN,
        )
    }

    /** OPENING -> OPEN. False if [leaseId] is not the current lease of [owner]. */
    @Synchronized
    fun commitOpen(key: String, leaseId: String, owner: Int): Boolean {
        val lease = leases[key] ?: return false
        if (lease.id != leaseId || lease.owner != owner || lease.orphaned || lease.phase != Phase.OPENING) return false
        lease.phase = Phase.OPEN
        return true
    }

    /**
     * Ends a lease: a failed open (OPENING) or a closed connection (OPEN).
     * A failed adoption restores the orphaned lease it replaced, because the
     * orphaned connection may still be open. Releasing twice is harmless.
     */
    @Synchronized
    fun release(key: String, leaseId: String, owner: Int): Boolean {
        val lease = leases[key] ?: return false
        // An orphaned lease is never released: only adoption through the gate ends it.
        if (lease.id != leaseId || lease.owner != owner || lease.orphaned) return false
        val previous = lease.adoptedFrom
        if (lease.phase == Phase.OPENING && previous != null) {
            leases[key] = previous
        } else {
            leases.remove(key)
        }
        return true
    }

    /** Null when destruction may start (and marks it started); otherwise why not. */
    @Synchronized
    fun beginDestroy(key: String): LifecycleBusyReason? {
        if (key in destroying) return LifecycleBusyReason.DESTROY_IN_PROGRESS
        val lease = leases[key]
        if (lease != null) {
            return when {
                lease.orphaned -> LifecycleBusyReason.ORPHANED_CONNECTION
                lease.phase == Phase.OPENING -> LifecycleBusyReason.OPEN_IN_PROGRESS
                else -> LifecycleBusyReason.DATABASE_OPEN
            }
        }
        destroying += key
        return null
    }

    @Synchronized
    fun endDestroy(key: String) {
        destroying -= key
    }

    /** Called when a Flutter engine is detached: its leases become orphaned, never released. */
    @Synchronized
    fun detachOwner(owner: Int) {
        for (lease in leases.values) if (lease.owner == owner) lease.orphaned = true
    }

    /** "idle", "opening", "open", "orphaned" or "destroying". */
    @Synchronized
    fun stateOf(key: String): String {
        if (key in destroying) return "destroying"
        val lease = leases[key] ?: return "idle"
        return if (lease.orphaned) "orphaned" else lease.phase.wireName
    }
}
