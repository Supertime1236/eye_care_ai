import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Đọc cấu hình ký release từ android/key.properties (không commit file này lên
// git — trên CI, workflow sẽ tự tạo file này từ GitHub Secrets trước khi
// build). Nếu file không tồn tại (build local chưa cấu hình), app vẫn build
// được bằng debug key như trước, chỉ là các bản build từ nguồn khác nhau sẽ
// KHÔNG cài đè lên nhau được (phải gỡ cài lại) vì chữ ký khác nhau.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.eyecare.eye_care_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eyecare.eye_care_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // health plugin (HealthKit/Health Connect) requires minSdk 26+;
        // flutter.minSdkVersion mặc định thấp hơn nên phải ghi đè ở đây.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
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
            // Dùng key release CỐ ĐỊNH nếu đã cấu hình (xem key.properties),
            // để mọi bản build đều cùng chữ ký -> cài đè lên bản cũ được thay
            // vì bắt buộc gỡ cài lại. Nếu chưa cấu hình, tạm dùng debug key
            // như cũ (chỉ nên dùng khi build thử ở máy local).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
