import java.time.Duration

// Runs the Kotlin tests on the JVM against a host build of the Swift package (macOS: also the main-actor
// tests, on the process's first thread, as Android's UI thread).
plugins {
    kotlin("jvm") version "2.4.21"
}

val packageDir = rootDir
val swiftBuildDir = packageDir.resolve(".build")
val modules = listOf("ShapesUtil", "ShapesModels", "ShapesClients", "ShapesDependencies", "ShapesViewModels")

// Builds the package with swift-java and the jextract plugin (SWIFT_JAVA_BUILD), which generates each
// module's Java and Swift bindings and links them into libShapesApp.
val swiftBuild = tasks.register<Exec>("swiftBuild") {
    workingDir = packageDir
    environment("SWIFT_JAVA_BUILD", "1")
    commandLine("swift", "build", "--disable-experimental-prebuilts", "--disable-sandbox")
    inputs.dir(packageDir.resolve("Sources"))
    inputs.file(packageDir.resolve("Package.swift"))
    inputs.dir(packageDir.resolve("swift-java/Sources"))
    outputs.dirs(modules.map { generatedJava(it) })
}

fun generatedJava(module: String) =
    swiftBuildDir.resolve("plugins/outputs/swift-java-app-shapes/$module/destination/JExtractSwiftPlugin/src/generated/java")

sourceSets {
    main {
        java.srcDirs(modules.map { generatedJava(it) })
    }
    test {
        kotlin.srcDirs(packageDir.resolve("Tests/shared"), packageDir.resolve("Tests/jvm"))
    }
}

tasks.named("compileJava") { dependsOn(swiftBuild) }
tasks.named("compileKotlin") { dependsOn(swiftBuild) }

dependencies {
    implementation("org.swift.swiftkit:swiftkit-core")
    testImplementation(kotlin("test"))
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
    // A deadlocked test fails instead of stalling the build.
    timeout.set(Duration.ofMinutes(2))
    jvmArgs("--enable-native-access=ALL-UNNAMED")
    systemProperty("java.library.path", swiftBuildDir.resolve("debug").path)
    if (System.getProperty("os.name").startsWith("Mac")) {
        jvmArgs("-XstartOnFirstThread")
    }
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
