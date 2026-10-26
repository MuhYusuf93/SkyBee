import java.util.Base64
import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Native integration fixtures must never share the operational app's sandbox.
// Flutter uses a generated entrypoint for integration tests, so target paths
// cannot identify them reliably. The test command must pass the explicit flag;
// its APK package is verified BEFORE any install on a physical device.
val isIntegrationFixture = project.findProperty("dart-defines")?.toString()
    ?.split(',')?.any {
        String(Base64.getDecoder().decode(it)) == "KASIR_INTEGRATION_TEST=true"
    } == true
val isSkybeeDemo = project.findProperty("dart-defines")?.toString()
    ?.split(',')?.any {
        String(Base64.getDecoder().decode(it)) == "KASIR_SKYBEE_DEMO=true"
    } == true
if (isIntegrationFixture && isSkybeeDemo) {
    throw GradleException("Skybee demo and integration fixture are separate sandboxes.")
}
val fixtureBackgroundPaused = project.findProperty("dart-defines")?.toString()
    ?.split(',')?.any {
        String(Base64.getDecoder().decode(it)) == "KASIR_FIXTURE_BACKGROUND_PAUSED=true"
    } == true
if (fixtureBackgroundPaused && !isIntegrationFixture) {
    throw GradleException("Background isolation override is restricted to integration fixtures.")
}

// Flutter's packaging defaults retain all three supported ABIs even for a
// --target-platform build. Compile our CMake library for exactly the requested
// Flutter targets: otherwise a lone KDF library can advertise an ABI with no
// matching Flutter engine/app. Universal production builds still include all
// original ABIs; this is not a fixed ABI restriction or a minSdk change.
val kdfTargetAbiMap = mapOf(
    "android-arm" to "armeabi-v7a",
    "android-arm64" to "arm64-v8a",
    "android-x64" to "x86_64",
)
val kdfTargetAbis = (project.findProperty("target-platform")?.toString()
    ?: "android-arm,android-arm64,android-x64").split(',').map {
    kdfTargetAbiMap[it] ?: throw GradleException("Unsupported Flutter native target: $it")
}

// Fail before install when a direct/generated test entrypoint lacks isolation.
// This also protects accidental bare `flutter test integration_test/...` calls.
val entrypointPath = project.findProperty("target")?.toString() ?: "lib/main.dart"
val entrypointCandidate = File(entrypointPath)
val entrypointFile = if (entrypointCandidate.isAbsolute) entrypointCandidate else
    project.rootProject.projectDir.parentFile.resolve(entrypointPath)
val skybeeEntrypoint = project.rootProject.projectDir.parentFile.resolve("lib/main_skybee_demo.dart").canonicalFile
if (isSkybeeDemo != (entrypointFile.canonicalFile == skybeeEntrypoint)) {
    throw GradleException("Skybee demo requires its dedicated entrypoint and KASIR_SKYBEE_DEMO=true together.")
}
if (isSkybeeDemo && gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) || it.contains("Profile", ignoreCase = true)
}) {
    throw GradleException("Skybee populated demo is debug-only.")
}
val fixtureDirectory = project.rootProject.projectDir.parentFile.resolve("integration_test").canonicalFile.toPath()
if (!isIntegrationFixture && entrypointFile.canonicalFile.toPath().startsWith(fixtureDirectory)) {
    throw GradleException("Fixture entrypoints require KASIR_INTEGRATION_TEST=true. Use tools/test_android.ps1.")
}
if (!isIntegrationFixture && entrypointFile.isFile) {
    val entrypointSource = entrypointFile.readText()
    if (entrypointSource.contains("package:integration_test/") ||
        entrypointSource.contains("package:flutter_test/")) {
        throw GradleException("Native tests require KASIR_INTEGRATION_TEST=true and --no-uninstall. Use tools/test_android.ps1.")
    }
}

android {
    if (isIntegrationFixture) {
        sourceSets.getByName("main").java.srcDir("src/integrationFixture/kotlin")
    }
    if (isSkybeeDemo) {
        sourceSets.getByName("main").java.srcDir("src/skybeeDemo/kotlin")
    }
    namespace = "com.example.kasir_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Applies to packaged AAR libraries too: SQLCipher must not advertise a
        // wider ABI set than Flutter's engine on a narrow test/profile build.
        // The default universal build still retains all three original ABIs.
        ndk { abiFilters.addAll(kdfTargetAbis) }
        externalNativeBuild {
            cmake { abiFilters.addAll(kdfTargetAbis) }
        }
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = when {
            isIntegrationFixture -> "com.example.kasir_app.integration"
            isSkybeeDemo -> "com.example.kasir_app.skybee"
            else -> "com.example.kasir_app"
        }
        manifestPlaceholders["appLabel"] = when {
            isIntegrationFixture -> "kasir_app tests"
            isSkybeeDemo -> "skybee kasir"
            else -> "kasir_app"
        }
        manifestPlaceholders["launcherActivity"] = when {
            isIntegrationFixture -> "com.example.kasir_app.IntegrationActivity"
            isSkybeeDemo -> "com.example.kasir_app.SkybeeDemoActivity"
            else -> "com.example.kasir_app.MainActivity"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// The sqflite adapter's API remains stable; use the maintained modern SQLCipher
// Android AAR, including its 16 KiB native page-size support, on all existing ABIs.
configurations.configureEach {
    resolutionStrategy.force("net.zetetic:sqlcipher-android:4.19.1")
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
