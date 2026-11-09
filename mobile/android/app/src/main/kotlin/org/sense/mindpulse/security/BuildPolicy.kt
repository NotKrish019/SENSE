package org.sense.mindpulse.security

import android.content.Context
import android.content.pm.ApplicationInfo
import org.sense.mindpulse.BuildConfig

/** The Android build type this APK was built as (Gradle `BuildConfig.BUILD_TYPE`). */
enum class BuildKind(val wireName: String) {
    DEBUG("debug"),

    /** Flutter's profile build type is created with `initWith(debug)`, so it is debuggable. */
    PROFILE("profile"),
    RELEASE("release"),
    UNKNOWN("unknown"),
    ;

    companion object {
        fun fromBuildType(buildType: String): BuildKind =
            when (buildType) {
                "debug" -> DEBUG
                "profile" -> PROFILE
                "release" -> RELEASE
                else -> UNKNOWN
            }
    }
}

/**
 * Explicit production-eligibility policy (Milestone J hardening, finding M2).
 *
 * `FLAG_DEBUGGABLE` alone is not the decision: Flutter profile builds inherit
 * the debug build type, and an unknown build type is never trusted.
 *
 * - The participant (production) database: only a `release` build that is
 *   also not debuggable, and then only with a hardware-backed key (checked
 *   separately from the key's own metadata).
 * - Test namespaces: only a `debug` build that is debuggable.
 * - Profile builds get neither.
 */
class BuildPolicy(val kind: BuildKind, val debuggable: Boolean) {
    val participantDatabaseAllowed: Boolean get() = kind == BuildKind.RELEASE && !debuggable

    val testNamespacesAllowed: Boolean get() = kind == BuildKind.DEBUG && debuggable

    override fun toString(): String = "BuildPolicy(${kind.wireName}, debuggable=$debuggable)"

    companion object {
        fun current(context: Context): BuildPolicy =
            BuildPolicy(
                kind = BuildKind.fromBuildType(BuildConfig.BUILD_TYPE),
                debuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0,
            )
    }
}
