import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jntnail.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jntnail.app"

        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["appName"] = "JNT"
        manifestPlaceholders["deepLinkScheme"] = "jntapp"
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"

            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"

            manifestPlaceholders["appName"] = "JNT DEV"
            manifestPlaceholders["deepLinkScheme"] = "jntappdev"
        }

        create("uat") {
            dimension = "environment"

            applicationIdSuffix = ".uat"
            versionNameSuffix = "-uat"

            manifestPlaceholders["appName"] = "JNT UAT"
            manifestPlaceholders["deepLinkScheme"] = "jntappuat"
        }

        create("production") {
            dimension = "environment"

            manifestPlaceholders["appName"] = "JNT"
            manifestPlaceholders["deepLinkScheme"] = "jntapp"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key only if key.properties is missing
            // (e.g. a fresh checkout before the keystore has been set up).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
