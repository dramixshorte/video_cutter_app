plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.video_cutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

 compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.video_cutter_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName


    }

    buildTypes {
        release {
            // استخدم المفتاح الحقيقي لاحقاً
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            // تمكين رموز التكديس المفهومة لو احتجت تتبع أعطال
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                File(projectDir, "proguard-rules.pro")
            )
        }
        debug {
            // يمكن تفعيل التصغير للتجربة (اختياري)
            // isMinifyEnabled = false
        }
    }

    // (اختياري) لتفعيل تقسيم ABI في الإصدار فقط لاحقاً:
    // بعد الاستقرار، أزل التعليقات التالية:
    // splits {
    //   abi {
    //     enable true
    //     reset()
    //     include("armeabi-v7a","arm64-v8a")
    //     universalApk false
    //   }
    // }

    // تقسيم الـ APK حسب ABI لتقليل الحجم (نفعّلها فقط في الإصدار release لتجنب تعارض debug مع x86_64 للمحاكي)
}
dependencies {
     coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.12.0")
    // Play Core for deferred components (SplitCompat, SplitInstall)
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.play:core-ktx:1.8.1")
}
flutter {
    source = "../.."
}
