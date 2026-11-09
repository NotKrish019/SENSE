allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// SQLCipher engine (Milestone J). The sqflite_sqlcipher 3.4.1 plugin declares
// net.zetetic:sqlcipher-android:4.10.0. Every configuration of every project,
// including the plugin's own compile classpath, is resolved to the official
// SQLCipher for Android 4.20.0 instead, with the androidx.sqlite version that
// 4.20.0's POM declares. The plugin already uses the same artifact and the
// same net.zetetic.database.sqlcipher API (no public API was removed between
// 4.10.0 and 4.20.0), so it is compiled against 4.20.0, not swapped at
// runtime. The legacy library (net.sqlcipher, artifact
// android-database-sqlcipher) is a different engine and fails the build, so
// exactly one SQLCipher implementation can be packaged.
// See docs/architecture/encrypted_local_storage.md.
val sqlcipherAndroidVersion = "4.20.0"
val androidxSqliteVersion = "2.7.0"
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "net.zetetic" && requested.name == "android-database-sqlcipher") {
                throw GradleException(
                    "Legacy SQLCipher (net.zetetic:android-database-sqlcipher) is not allowed; " +
                        "SENSE packages only net.zetetic:sqlcipher-android:$sqlcipherAndroidVersion.",
                )
            }
            if (requested.group == "net.zetetic" && requested.name == "sqlcipher-android") {
                useVersion(sqlcipherAndroidVersion)
                because("SENSE pins the official SQLCipher for Android stable release (Milestone J)")
            }
            if (requested.group == "androidx.sqlite" && requested.name == "sqlite") {
                useVersion(androidxSqliteVersion)
                because("androidx.sqlite version declared by sqlcipher-android $sqlcipherAndroidVersion")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
