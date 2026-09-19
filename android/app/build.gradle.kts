import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key never enters the repository: `android/key.properties` and the
// keystore it points at are both gitignored, so a fresh checkout has neither.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

if (!hasUploadKey) {
    // Loud on purpose. A release build signed with the debug key looks fine
    // locally and is only refused at the far end, by Play, after the upload.
    logger.warn(
        "WARNING: android/key.properties is missing — the release build will " +
            "be signed with the debug key and Play will reject it."
    )
}

android {
    namespace = "yolyoldasi.az"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time, which needs desugaring
        // to run on the API 24 devices this app still supports.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Fixed by the Play Console entry: the store listing was created under
        // this id, and an id cannot be changed once an app is published.
        applicationId = "yolyoldasi.az"
        // Firebase Auth and flutter_local_notifications both require API 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Resolved against this module, so `storeFile` in
                // key.properties is relative to android/app/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Debug signing stays as the fallback so `flutter run --release`
            // still works without the keystore; the warning above is what stops
            // that quietly becoming an upload.
            signingConfig = signingConfigs.getByName(
                if (hasUploadKey) "release" else "debug"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
