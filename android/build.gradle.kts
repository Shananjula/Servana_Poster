plugins {
    // Make sure you have these alias if they are defined in settings.gradle.kts or libs.versions.toml
    // If not, use the full id "com.android.application" version "8.2.0" apply false (adjust version as needed)
    // Same for "org.jetbrains.kotlin.android"
    // alias(libs.plugins.androidApplication) apply false
    // alias(libs.plugins.jetbrainsKotlinAndroid) apply false
    // Add this line for the Google services plugin
    id("com.google.gms.google-services") version "4.3.15" apply false // Check for the latest version
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
