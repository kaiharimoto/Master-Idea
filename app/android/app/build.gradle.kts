import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.masteridea.master_idea"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.masteridea.master_idea"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Pinned rather than inherited, because two branches in
        // MainActivity depend on the floor: asking for install permission is
        // an Android 8 API, and writing into the shared Downloads collection
        // without any permission at all is an Android 10 one. An inherited
        // default that moved would take a branch's meaning with it silently.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The development signing key, committed to the repository on purpose.
    //
    // CI generates a fresh debug key on every run, which makes each build a
    // different application as far as Android is concerned: installing a new
    // one would mean uninstalling the old one first, taking every session
    // stored on the device with it. One fixed key is what lets a new build
    // install straight over the last, which is the whole point of an app that
    // updates itself.
    //
    // This key is PUBLIC. It must never sign a Play Store release.
    signingConfigs {
        create("dev") {
            val props = Properties()
            val file = rootProject.file("dev-key.properties")
            if (file.exists()) {
                props.load(FileInputStream(file))
                storeFile = rootProject.file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Fall back to the debug key only if the dev keystore is missing,
            // so a checkout without it still builds rather than failing
            // obscurely.
            signingConfig = if (rootProject.file("dev-key.properties").exists()) {
                signingConfigs.getByName("dev")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // FileProvider, used to hand the downloaded APK to the package installer.
    // Declared rather than relied on transitively through the Flutter
    // embedding, so an embedding change cannot silently break the updater.
    implementation("androidx.core:core-ktx:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
