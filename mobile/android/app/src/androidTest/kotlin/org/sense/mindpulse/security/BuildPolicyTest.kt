package org.sense.mindpulse.security

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * Hardening finding M2: explicit production eligibility. Debug and profile
 * builds can never open the participant database; release builds can only
 * with hardware-backed key metadata; test namespaces exist only in debug.
 *
 * Manager-level tests drive the real state machine and gate
 * (openOrInitialize) with an injected build policy and, where a hardware level
 * cannot exist on this device, an injected KeyInfo level. Channel-level tests
 * go through the real app path: SecureDatabaseChannel -> forApp -> gate.
 */
class BuildPolicyTest {
    private lateinit var env: KeyTestEnv
    private val release = BuildPolicy(BuildKind.RELEASE, debuggable = false)

    @Before
    fun setUp() {
        env = KeyTestEnv(InstrumentationRegistry.getInstrumentation().targetContext, "policy")
    }

    @After
    fun tearDown() = env.cleanup()

    private fun participant(policy: BuildPolicy, level: KeySecurityLevel? = null, emulator: Boolean = env.emulator) =
        env.manager(
            purpose = StoragePurpose.PARTICIPANT,
            policy = policy,
            emulator = emulator,
            levelProbe = level?.let { l -> { _ -> l } },
        )

    private fun assertNothingCreated() {
        assertFalse("no key may be created", env.aliasExists())
        assertFalse("no envelope may be created", env.envelopeFile.exists())
        assertFalse("no setup marker may be created", env.markerFile.exists())
        assertFalse("no database may be created", env.dbFile.exists())
    }

    // ---- The policy itself -------------------------------------------------------------------

    @Test
    fun thisInstrumentedBuildIsADebuggableDebugBuild() {
        val p = BuildPolicy.current(env.context)
        assertEquals(BuildKind.DEBUG, p.kind)
        assertTrue(p.debuggable)
        assertFalse(p.participantDatabaseAllowed)
        assertTrue(p.testNamespacesAllowed)
    }

    @Test
    fun policyMatrix() {
        data class Case(val kind: BuildKind, val debuggable: Boolean, val participant: Boolean, val testNs: Boolean)
        for (c in listOf(
            Case(BuildKind.DEBUG, true, participant = false, testNs = true),
            Case(BuildKind.DEBUG, false, participant = false, testNs = false),
            Case(BuildKind.PROFILE, true, participant = false, testNs = false),
            Case(BuildKind.PROFILE, false, participant = false, testNs = false),
            Case(BuildKind.RELEASE, false, participant = true, testNs = false),
            Case(BuildKind.RELEASE, true, participant = false, testNs = false),
            Case(BuildKind.UNKNOWN, false, participant = false, testNs = false),
        )) {
            val p = BuildPolicy(c.kind, c.debuggable)
            assertEquals("$p participant", c.participant, p.participantDatabaseAllowed)
            assertEquals("$p test namespaces", c.testNs, p.testNamespacesAllowed)
        }
        assertEquals(BuildKind.PROFILE, BuildKind.fromBuildType("profile"))
        assertEquals(BuildKind.UNKNOWN, BuildKind.fromBuildType("staging"))
    }

    // ---- Manager: build kind -----------------------------------------------------------------

    @Test
    fun debugBuildCannotOpenTheParticipantDatabaseEvenWithAHardwareKey() {
        val m = participant(BuildPolicy(BuildKind.DEBUG, true), KeySecurityLevel.TRUSTED_ENVIRONMENT, emulator = false)
        failedWith(m.openOrInitialize(), KeyFailure.BUILD_NOT_PRODUCTION_ELIGIBLE)
        assertNothingCreated()
    }

    @Test
    fun profileBuildCannotOpenTheParticipantDatabaseEvenWithAHardwareKey() {
        for (debuggable in listOf(true, false)) {
            val m = participant(BuildPolicy(BuildKind.PROFILE, debuggable), KeySecurityLevel.STRONGBOX, emulator = false)
            failedWith(m.openOrInitialize(), KeyFailure.BUILD_NOT_PRODUCTION_ELIGIBLE)
            assertNothingCreated()
        }
    }

    @Test
    fun debuggableReleaseAndUnknownBuildsCannotOpenTheParticipantDatabase() {
        for (p in listOf(BuildPolicy(BuildKind.RELEASE, true), BuildPolicy(BuildKind.UNKNOWN, false))) {
            failedWith(participant(p, KeySecurityLevel.TRUSTED_ENVIRONMENT, emulator = false).openOrInitialize(), KeyFailure.BUILD_NOT_PRODUCTION_ELIGIBLE)
            assertNothingCreated()
        }
    }

    @Test
    fun aBuildPolicyRefusalNeverTouchesAnExistingDatabase() {
        // An existing participant-style database, then a profile build asks for it.
        ready(env.manager().openOrInitialize()).passphrase.fill(0)
        env.standInDatabase()
        val envelope = env.envelopeFile.readBytes()
        failedWith(participant(BuildPolicy(BuildKind.PROFILE, true)).openOrInitialize(), KeyFailure.BUILD_NOT_PRODUCTION_ELIGIBLE)
        assertTrue(env.aliasExists())
        assertTrue(env.envelopeFile.readBytes().contentEquals(envelope))
        assertTrue(env.dbFile.exists())
    }

    // ---- Manager: release build and key metadata ---------------------------------------------

    @Test
    fun releaseWithTrustedEnvironmentMetadataIsAccepted() {
        val r = ready(participant(release, KeySecurityLevel.TRUSTED_ENVIRONMENT, emulator = false).openOrInitialize())
        assertTrue(r.productionEligible)
        assertEquals(KeySecurityLevel.TRUSTED_ENVIRONMENT, r.security.reportedLevel)
        r.passphrase.fill(0)
        env.standInDatabase()
        // The gate runs again on every open (unwrapExisting), not only at creation.
        assertTrue(ready(participant(release, KeySecurityLevel.TRUSTED_ENVIRONMENT, emulator = false).openOrInitialize()).productionEligible)
    }

    @Test
    fun releaseWithStrongBoxMetadataIsAccepted() {
        val r = ready(participant(release, KeySecurityLevel.STRONGBOX, emulator = false).openOrInitialize())
        assertTrue(r.productionEligible)
        assertEquals(KeySecurityLevel.STRONGBOX, r.security.reportedLevel)
    }

    @Test
    fun releaseWithSoftwareMetadataIsRejectedAndRolledBack() {
        failedWith(participant(release, KeySecurityLevel.SOFTWARE, emulator = false).openOrInitialize(), KeyFailure.INSECURE_KEY_STORAGE)
        assertNothingCreated()
    }

    @Test
    fun releaseWithUnknownMetadataIsRejectedAndRolledBack() {
        failedWith(participant(release, KeySecurityLevel.UNKNOWN, emulator = false).openOrInitialize(), KeyFailure.INSECURE_KEY_STORAGE)
        assertNothingCreated()
    }

    @Test
    fun anEmulatorIsNeverHardwareEvidenceEvenIfItReportsTrustedEnvironment() {
        failedWith(participant(release, KeySecurityLevel.TRUSTED_ENVIRONMENT, emulator = true).openOrInitialize(), KeyFailure.INSECURE_KEY_STORAGE)
        assertNothingCreated()
    }

    @Test
    fun releaseUsesTheRealKeyMetadataOfThisDevice() {
        val r = participant(release).openOrInitialize() // no probe: real KeyInfo
        if (r is KeyOpenResult.Ready) {
            assertTrue("accepted only with hardware evidence", r.security.hardwareBackedEvidence)
            assertTrue(r.productionEligible)
        } else {
            failedWith(r, KeyFailure.INSECURE_KEY_STORAGE)
            assertFalse((r as KeyOpenResult.Failed).security!!.hardwareBackedEvidence)
            assertNothingCreated()
        }
    }

    @Test
    fun anExistingKeyThatNoLongerReportsHardwareIsRefusedOnTheNextOpen() {
        ready(participant(release, KeySecurityLevel.TRUSTED_ENVIRONMENT, emulator = false).openOrInitialize()).passphrase.fill(0)
        env.standInDatabase()
        env.manager().completeSetup()
        for (level in listOf(KeySecurityLevel.SOFTWARE, KeySecurityLevel.UNKNOWN)) {
            failedWith(participant(release, level, emulator = false).openOrInitialize(), KeyFailure.INSECURE_KEY_STORAGE)
            assertTrue("nothing is deleted", env.aliasExists() && env.envelopeFile.exists() && env.dbFile.exists())
        }
    }

    @Test
    fun aTestNamespaceIsNeverProductionEligible() {
        val r = ready(env.manager(levelProbe = { KeySecurityLevel.STRONGBOX }, emulator = false).openOrInitialize())
        assertFalse(r.productionEligible)
    }

    // ---- Channel: the actual application path ------------------------------------------------

    private val ctx get() = env.context

    private fun participantFilesAbsent(): Boolean {
        val noBackup = ctx.noBackupFilesDir
        return !File(noBackup, SecureDatabaseKeyManager.DATABASE_FILE_NAME).exists() &&
            !File(noBackup, SecureDatabaseKeyManager.ENVELOPE_FILE_NAME).exists() &&
            !File(noBackup, SecureDatabaseKeyManager.SETUP_MARKER_FILE_NAME).exists() &&
            !env.keyStore().containsAlias(SecureDatabaseKeyManager.KEY_ALIAS)
    }

    @Test
    fun channelInThisDebugBuildRejectsTheParticipantDatabase() {
        assumeTrue("the debug test app must not hold participant key material", participantFilesAbsent())
        val ch = SecureDatabaseChannel(ctx) // real BuildConfig policy
        val out = ch.call("openKey").success!!
        assertEquals("failed", out["status"])
        assertEquals("buildNotProductionEligible", out["failure"])
        assertNull(out["passphrase"])
        assertEquals("debug", out["buildKind"])
        assertEquals("idle", ch.call("inspect").success!!["lifecycle"])
        assertTrue(participantFilesAbsent())
    }

    @Test
    fun channelInAProfileBuildRejectsTheParticipantDatabaseAndTestNamespaces() {
        assumeTrue(participantFilesAbsent())
        val ch = SecureDatabaseChannel(ctx, BuildPolicy(BuildKind.PROFILE, debuggable = true))
        val out = ch.call("openKey").success!!
        assertEquals("buildNotProductionEligible", out["failure"])
        assertNull(out["passphrase"])
        assertEquals("invalidArgument", ch.call("openKey", mapOf("testNamespace" to "policy_profile")).errorCode)
        assertTrue(participantFilesAbsent())
    }

    @Test
    fun channelInAReleaseBuildRejectsTestNamespaces() {
        val ch = SecureDatabaseChannel(ctx, release)
        for (m in listOf("inspect", "openKey", "destroy")) {
            assertEquals(m, "invalidArgument", ch.call(m, mapOf("testNamespace" to "policy_release")).errorCode)
        }
        assertFalse(File(File(ctx.noBackupFilesDir, "test_namespaces"), "policy_release").exists())
    }

    @Test
    fun channelInAReleaseBuildGatesTheParticipantDatabaseOnRealKeyMetadata() {
        assumeTrue("the debug test app must not hold participant key material", participantFilesAbsent())
        val ch = SecureDatabaseChannel(ctx, release)
        val out = ch.call("openKey").success!!
        if (out["status"] == "ready") {
            // Hardware-backed device: accepted, production eligible. Undo it.
            assertEquals(true, out["hardwareBackedEvidence"])
            assertEquals(true, out["productionEligible"])
            assertEquals(true, ch.call("release", mapOf("leaseId" to out["leaseId"])).success!!["released"])
            assertEquals("destroyed", ch.call("destroy").success!!["status"])
        } else {
            assertEquals("insecureKeyStorage", out["failure"])
            assertEquals(false, out["hardwareBackedEvidence"])
            assertNull(out["passphrase"])
            assertNull(out["leaseId"])
        }
        assertEquals("idle", ch.call("inspect").success!!["lifecycle"])
        assertTrue("rejected or destroyed: nothing may remain", participantFilesAbsent())
    }
}
