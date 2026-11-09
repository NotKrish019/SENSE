plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.sense.mindpulse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // PROVISIONAL development application ID. No release identifier has been
        // approved for SENSE. This value MUST be reviewed and replaced before any
        // release, store upload or distribution build.
        // (https://developer.android.com/studio/build/application-id.html)
        applicationId = "org.sense.mindpulse.dev"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // On-device tests of the Keystore key manager (src/androidTest).
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // BuildConfig.BUILD_TYPE feeds the explicit production-eligibility policy
    // (security/BuildPolicy.kt): only a non-debuggable "release" build may open
    // the participant database; "profile" (debuggable, initWith(debug)) may not.
    buildFeatures {
        buildConfig = true
    }

    // Release signing is intentionally NOT configured. Release builds are
    // unsigned until an approved application ID and signing process exist.
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Instrumented tests only (src/androidTest); never packaged in the app.
    // Aligned with the androidx.test 1.3.0 line that the integration_test dev
    // plugin already puts on the debug classpath (Gradle consistent resolution).
    // Only the runner (plain JUnit4 tests): androidx.test:core 1.3.0 predates
    // the Android 12 android:exported rule and cannot merge at targetSdk 36.
    androidTestImplementation("androidx.test:runner:1.3.0")
}
