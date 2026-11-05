rootProject.name = "swift-java-app-shapes"

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

// SwiftKitCore, the Java runtime for jextract's bindings, comes from the swift-java submodule
// (skiptools/swift-java, skip/integration): it isn't published to Maven Central.
includeBuild("swift-java") {
    dependencySubstitution {
        substitute(module("org.swift.swiftkit:swiftkit-core")).using(project(":SwiftKitCore"))
    }
}

// The Kotlin tests, run on the JVM against a host build of the Swift package.
include("jvm")

// The same tests, run on an Android device or emulator against the package cross-compiled for Android.
include("android")
