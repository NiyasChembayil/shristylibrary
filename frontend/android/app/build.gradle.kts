plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.srishty.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // ⚠️ BEFORE RELEASE: Generate a keystore and configure signingConfigs.
    // Run: keytool -genkey -v -keystore srishty-release.jks -alias srishty -keyalg RSA -keysize 2048 -validity 10000
    // Then fill in the storeFile, storePassword, keyAlias, keyPassword below.
    // signingConfigs {
    //     create("release") {
    //         storeFile = file("srishty-release.jks")
    //         storePassword = System.getenv("STORE_PASSWORD")
    //         keyAlias = "srishty"
    //         keyPassword = System.getenv("KEY_PASSWORD")
    //     }
    // }

    defaultConfig {
        applicationId = "com.srishty.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // ⚠️ BEFORE RELEASE: Switch to your release signingConfig:
            // signingConfig = signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("debug") // Temporary: replace before Play Store upload
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
