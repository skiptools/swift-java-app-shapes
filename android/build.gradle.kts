// Runs the shared Kotlin tests (Tests/shared) as instrumented tests on an Android device or emulator,
// against the package cross-compiled with the Swift SDK for Android:
//
//   ./gradlew :android:connectedDebugAndroidTest
//
// Properties: `swiftToolchain` (a swift.org toolchain matching the SDK, default 6.4.2) and
// `swiftAndroidSdk` (the Swift SDK artifact bundle).
plugins {
    id("com.android.library") version "9.5.0"
}

val packageDir = rootDir
val swiftBuildDir = packageDir.resolve(".build-android")
val modules = listOf("ShapesUtil", "ShapesModels", "ShapesClients", "ShapesDependencies", "ShapesViewModels")
val home: String = System.getProperty("user.home")
val swiftToolchain = providers.gradleProperty("swiftToolchain")
    .getOrElse("$home/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain")
val swiftAndroidSdk = providers.gradleProperty("swiftAndroidSdk")
    .getOrElse("$home/.swiftpm/swift-sdks/swift-6.4.2-RELEASE_android.artifactbundle/swift-android")
val minSdkLevel = 28

fun generatedJava(module: String) =
    swiftBuildDir.resolve("plugins/outputs/swift-java-app-shapes/$module/destination/JExtractSwiftPlugin/src/generated/java")

// Cross-compiles the package for arm64 Android with swift-java and the jextract plugin. The toolchain's
// own `swift` must come first on PATH: plugins run `swift` too.
val swiftBuild = tasks.register<Exec>("swiftBuildAndroid") {
    workingDir = packageDir
    environment("SWIFT_JAVA_BUILD", "1")
    environment("PATH", "$swiftToolchain/usr/bin:${System.getenv("PATH")}")
    commandLine(
        "$swiftToolchain/usr/bin/swift", "build", "--swift-sdk", "aarch64-unknown-linux-android$minSdkLevel",
        "--scratch-path", swiftBuildDir.path, "--disable-experimental-prebuilts", "--disable-sandbox",
    )
    inputs.dir(packageDir.resolve("Sources"))
    inputs.file(packageDir.resolve("Package.swift"))
    outputs.dirs(modules.map { generatedJava(it) })
    outputs.file(swiftBuildDir.resolve("out/Products/Debug-android-aarch64/libShapesApp.so"))
}

// The app's library plus the Swift runtime and the C++ runtime it links against.
val jniLibs = layout.buildDirectory.dir("swift-jniLibs")
val copySwiftLibraries = tasks.register<Copy>("copySwiftLibraries") {
    dependsOn(swiftBuild)
    from(swiftBuildDir.resolve("out/Products/Debug-android-aarch64")) { include("*.so") }
    from("$swiftAndroidSdk/swift-resources/usr/lib/swift-aarch64/android") {
        include("*.so")
        exclude("libXCTest.so", "libTesting.so", "lib_Testing*.so")
    }
    from(fileTree("$swiftAndroidSdk/android-ndk-r30/toolchains/llvm/prebuilt").matching {
        include("*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so")
    }.files)
    into(jniLibs.map { it.dir("arm64-v8a") })
}

android {
    namespace = "com.example.shapes"
    compileSdk = 36

    defaultConfig {
        minSdk = minSdkLevel
        testInstrumentationRunner = "com.example.shapes.ShapesTestRunner"
        ndk { abiFilters += "arm64-v8a" }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        named("main") {
            java.directories += modules.map { generatedJava(it).path }
            jniLibs.directories += layout.buildDirectory.dir("swift-jniLibs").get().asFile.path
        }
        named("androidTest") {
            kotlin.directories += listOf(packageDir.resolve("Tests/shared").path, packageDir.resolve("Tests/android").path)
        }
    }

    packaging {
        jniLibs { useLegacyPackaging = true }
    }
}

tasks.named("preBuild") { dependsOn(copySwiftLibraries) }

dependencies {
    implementation("org.swift.swiftkit:swiftkit-core")
    androidTestImplementation(kotlin("test-junit"))
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
