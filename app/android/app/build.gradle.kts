plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mop.mop_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mop.mop_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 规约：Android 仅 arm64-v8a，不构建其他 ABI（ARCHITECTURE 第 6 节）；配合 flutter build apk --target-platform android-arm64
        ndk {
            abiFilters.clear()
            abiFilters.addAll(listOf("arm64-v8a"))
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 仅保留 arm64-v8a：插件（如 Jitsi）会带入 v7a/x86_64，打包时排除以减小体积
    packaging {
        jniLibs {
            excludes += setOf(
                "lib/armeabi-v7a/**",
                "lib/x86_64/**",
                "lib/x86/**",
                "lib/armeabi/**"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.guava:guava:31.0.1-android")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-core:1.3.1")
    implementation("androidx.camera:camera-video:1.3.1")
}
