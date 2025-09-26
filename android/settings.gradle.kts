pluginManagement {
    val flutterSdkPath: String by settings
    settings.extra["flutterSdkPath"] = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk") ?: throw GradleException("flutter.sdk not set in local.properties")
    }

    includeBuild("${extra["flutterSdkPath"]}/packages/flutter_tools/gradle")

    repositories {
          google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://jitpack.io") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.25" apply false
}

include(":app")
