plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jewelnottool"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.jewelnottool"

        minSdk = flutter.minSdkVersion
        targetSdk = 35
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

    buildTypes {
        release {
            // Keep your existing signing behavior unchanged for now.
            signingConfig = signingConfigs.getByName("debug")
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
