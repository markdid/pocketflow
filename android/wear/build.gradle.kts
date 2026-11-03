plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "dev.markdid.pocketflow.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Same id and signing key as the phone app: the Wearable Data Layer only connects matching apps.
        applicationId = "dev.markdid.pocketflow"
        // Wear OS 3 (Galaxy Watch 4 and later).
        minSdk = 30
        targetSdk = 36
        // Same version as the phone app, so a release's two APKs match.
        val pubspecVersion =
            rootProject.file("../pubspec.yaml").readLines().first { it.startsWith("version:") }.substringAfter(":").trim()
        versionCode = pubspecVersion.substringAfter("+").toInt()
        versionName = pubspecVersion.substringBefore("+")
    }

    signingConfigs {
        // CI release builds sign with the PocketFlow release key; local builds fall back to the debug key.
        System.getenv("POCKETFLOW_KEYSTORE")?.let { keystore ->
            create("release") {
                storeFile = file(keystore)
                storePassword = System.getenv("POCKETFLOW_KEYSTORE_PASSWORD")
                keyAlias = "pocketflow"
                keyPassword = System.getenv("POCKETFLOW_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Same key as the phone app: the Data Layer only pairs apps with the same signature.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // A small APK installs before the watch's Wi-Fi debugging connection drops.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    // play-services pulls in an old Fragment that breaks registerForActivityResult (the permission prompt).
    implementation("androidx.fragment:fragment:1.8.6")
    implementation("androidx.wear.compose:compose-material:1.4.1")
    implementation("androidx.wear.compose:compose-foundation:1.4.1")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
}
