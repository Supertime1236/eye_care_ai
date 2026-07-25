allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

defaultConfig {
    applicationId = "com.eyecare.eye_care_ai"
    minSdk = 26
    targetSdk = flutter.targetSdkVersion
    versionCode = 3  // Tăng lên 3 (khớp với +3 ở pubspec)
    versionName = "1.0.1"  // Thay đổi từ flutter.versionName
}

// THÊM signingConfigs CHO RELEASE
signingConfigs {
    create("release") {
        storeFile = file("keystore/eye_care_ai.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_password"
        keyAlias = "eye_care_ai"
        keyPassword = System.getenv("KEY_PASSWORD") ?: "your_password"
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")  // Sửa từ "debug" thành "release"
        isMinifyEnabled = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}