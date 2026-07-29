pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9.0.1 quá mới (Flutter Gradle plugin hiện tại chưa hỗ trợ đầy đủ
    // DSL mới của AGP 9+, gây lỗi "Cannot add task 'generateLockfiles'").
    // Hạ về bản ổn định, được Flutter hỗ trợ tốt.
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Cần cho Firebase — đọc android/app/google-services.json.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
