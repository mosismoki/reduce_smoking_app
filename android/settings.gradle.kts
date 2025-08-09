pluginManagement {
    val flutterSdkPath = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        props.getProperty("flutter.sdk") ?: error("flutter.sdk not set in local.properties")
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
    id("com.android.application") version "8.9.0" apply false   // ارتقا
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false  // ارتقا به Kotlin 2.1
    id("com.google.gms.google-services") version "4.4.2" apply false
}


include(":app")


include(":app")
