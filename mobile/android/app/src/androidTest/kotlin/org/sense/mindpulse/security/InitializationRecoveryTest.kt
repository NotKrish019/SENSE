package org.sense.mindpulse.security

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/**
 * Hardening finding L3: first-time initialization interrupted by process death
 * at each stage. Death is modelled by [SimulatedProcessDeath], an Error that
 * bypasses the normal rollback (which catches Exception), exactly like a kill:
 * nothing after the injection point runs. A fresh manager then starts again.
 */
class InitializationRecoveryTest {
    private lateinit var env: KeyTestEnv

    @Before
    fun setUp() {
        env = KeyTestEnv(InstrumentationRegistry.getInstrumentation().targetContext, "recovery")
    }

    @After
    fun tearDown() = env.cleanup()

    private fun dieAt(stage: InitStage) {
        val m = env.manager(fault = { if (it == stage) throw SimulatedProcessDeath(it) })
        try {
            m.openOrInitialize()
            fail("expected simulated process death at $stage")
        } catch (e: SimulatedProcessDeath) {
            // the "process" ended here
        }
    }

    @Test
    fun killedAfterTheSetupMarkerBeforeAnyKey() {
        dieAt(InitStage.AFTER_SETUP_MARKER)
        assertTrue(env.markerFile.exists())
        assertFalse(env.aliasExists())
        assertFalse(env.envelopeFile.exists())

        val r = ready(env.manager().openOrInitialize())
        assertTrue(r.firstInitialization)
        assertTrue(env.aliasExists() && env.envelopeFile.exists())
        assertTrue("the marker stays until the database is confirmed", env.markerFile.exists())
    }

    @Test
    fun killedBetweenKeyCreationAndEnvelopeCreation() {
        dieAt(InitStage.AFTER_KEY_GENERATION)
        assertTrue(env.markerFile.exists())
        assertTrue(env.aliasExists())
        assertFalse(env.envelopeFile.exists())
        // Without the marker this state is ORPHANED_KEY (stuck). With it, the
        // key provably belongs to the interrupted setup and nothing depends on it.
        val r = ready(env.manager().openOrInitialize())
        assertTrue(r.firstInitialization)
        assertFalse(r.recoveredMissingDatabase)
        assertTrue(env.envelopeFile.exists())
        assertArrayEquals(r.passphrase, env.manager().unwrapWithCurrentKey(env.envelopeFile.readBytes()))
    }

    @Test
    fun killedAfterTheEnvelopeWasPersisted() {
        dieAt(InitStage.AFTER_ENVELOPE_WRITE)
        val envelope = env.envelopeFile.readBytes()
        val created = env.keyStore().getCreationDate(env.alias)
        assertTrue(env.markerFile.exists())

        val r = ready(env.manager().openOrInitialize())
        assertTrue("still the same first initialization", r.firstInitialization)
        assertFalse("not misreported as a lost database", r.recoveredMissingDatabase)
        assertArrayEquals("the envelope is reused, never rewritten", envelope, env.envelopeFile.readBytes())
        assertEquals("the key is reused, never regenerated", created, env.keyStore().getCreationDate(env.alias))
    }

    @Test
    fun killedDuringInitialDatabaseCreation() {
        val first = ready(env.manager().openOrInitialize())
        val passphrase = first.passphrase.copyOf()
        // The database file exists (partially written) but was never confirmed.
        env.standInDatabase()
        assertTrue(env.markerFile.exists())

        val again = ready(env.manager().openOrInitialize())
        assertTrue(again.firstInitialization)
        assertArrayEquals("same key for the same (partial) database", passphrase, again.passphrase)
        assertTrue(env.dbFile.exists())

        // The lifecycle owner's commit ends the setup; later opens are ordinary.
        env.manager().completeSetup()
        assertFalse(env.markerFile.exists())
        assertFalse(ready(env.manager().openOrInitialize()).firstInitialization)
    }

    @Test
    fun anAliasOlderThanTheMarkerIsNeverDeleted() {
        env.generateRealKey(strongBox = false)
        val created = env.keyStore().getCreationDate(env.alias)
        env.writeMarker(createdAtMillis = System.currentTimeMillis() + 60_000) // key predates the setup
        repeat(2) { failedWith(env.manager().openOrInitialize(), KeyFailure.ORPHANED_KEY) }
        assertEquals(created, env.keyStore().getCreationDate(env.alias))
    }

    @Test
    fun aMarkerForAnotherAliasProvesNothing() {
        env.generateRealKey(strongBox = false)
        env.writeMarker(System.currentTimeMillis() - 1_000, markerAlias = "${env.alias}_other")
        failedWith(env.manager().openOrInitialize(), KeyFailure.ORPHANED_KEY)
        assertTrue(env.aliasExists())
    }

    @Test
    fun aCorruptMarkerIsTreatedAsAbsent() {
        env.generateRealKey(strongBox = false)
        env.dir.mkdirs()
        env.markerFile.writeBytes(byteArrayOf(1, 2, 3, 4, 5))
        failedWith(env.manager().openOrInitialize(), KeyFailure.ORPHANED_KEY)
        assertTrue(env.aliasExists())
    }

    @Test
    fun aMarkerNeverAllowsAKeyForAnExistingDatabaseToBeReplaced() {
        dieAt(InitStage.AFTER_KEY_GENERATION)
        env.standInDatabase() // a database now exists
        repeat(2) {
            failedWith(env.manager().openOrInitialize(), KeyFailure.ENVELOPE_MISSING_FOR_EXISTING_DATABASE)
            assertTrue(env.aliasExists())
            assertFalse(env.envelopeFile.exists())
            assertTrue(env.dbFile.exists())
        }
    }

    @Test
    fun anOrdinaryFailureDuringSetupRollsEverythingBack() {
        val m = env.manager(fault = { if (it == InitStage.AFTER_KEY_GENERATION) throw java.io.IOException("disk full") })
        failedWith(m.openOrInitialize(), KeyFailure.INITIALIZATION_FAILED)
        assertFalse(env.aliasExists())
        assertFalse(env.envelopeFile.exists())
        assertFalse(env.markerFile.exists())
        ready(env.manager().openOrInitialize())
    }

    @Test
    fun destroyRemovesAPendingSetupMarker() {
        dieAt(InitStage.AFTER_ENVELOPE_WRITE)
        val d = env.manager().destroy()
        assertTrue(d.keyDeleted && d.envelopeDeleted)
        assertFalse(env.markerFile.exists())
    }
}
