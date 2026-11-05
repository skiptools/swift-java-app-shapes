// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The code shapes of a production multi-module app, extracted for Kotlin (Tests/): Swift 6,
// modules depending on each other's types, public API that isn't exported, Combine and Observation,
// main-actor view models with callbacks. See README.md for the shapes each module holds.
//
// Every module uses `failOnSkippedDeclarations`: building this package checks that jextract handles
// all of it, and that the Java and Swift it generates compile. Shapes jextract doesn't handle yet are
// marked `@JavaExport(false)` with a `// Gap:` comment.

// Apple builds use only the JNI-free `@JavaExport` markers. Android (and the Gradle build that runs the
// Kotlin tests) sets `SWIFT_JAVA_BUILD`, which adds swift-java and the jextract plugin, as
// swiftlang/swift-java#694 describes.
let isSwiftJavaBuild = Context.environment["SWIFT_JAVA_BUILD"] != nil

func module(_ name: String, dependencies: [Target.Dependency] = []) -> Target {
  .target(
    name: name,
    dependencies: [.product(name: "SwiftJavaAnnotations", package: "swift-java")]
      + (isSwiftJavaBuild ? [.product(name: "SwiftJava", package: "swift-java")] : [])
      + dependencies,
    exclude: ["swift-java.config"],
    swiftSettings: [.swiftLanguageMode(.v6)],
    plugins: isSwiftJavaBuild ? [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")] : []
  )
}

let package = Package(
  name: "swift-java-app-shapes",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    // One library with every module, as an app ships them: a library per module would link copies of
    // the modules it depends on, and Swift casts fail between the copies. Each module's
    // swift-java.config names it in `nativeLibraryName`.
    .library(
      name: "ShapesApp",
      type: .dynamic,
      targets: [
        "ShapesUtil", "ShapesModels", "ShapesClients", "ShapesDependencies", "ShapesViewModels",
      ]
    )
  ],
  dependencies: [
    // The skip/integration branch of skiptools/swift-java, a submodule so SwiftPM and Gradle use one commit.
    .package(name: "swift-java", path: "swift-java"),
    // Combine's API where Combine isn't available (Android, Linux).
    .package(url: "https://github.com/OpenSwiftUIProject/OpenCombine.git", from: "0.17.0"),
  ],
  targets: [
    module("ShapesUtil"),
    module("ShapesModels", dependencies: ["ShapesUtil"]),
    module(
      "ShapesClients",
      dependencies: [
        "ShapesModels", "ShapesUtil",
        .product(
          name: "OpenCombine", package: "OpenCombine",
          condition: .when(platforms: [.android, .linux])),
      ]
    ),
    module("ShapesDependencies", dependencies: ["ShapesClients", "ShapesModels", "ShapesUtil"]),
    module(
      "ShapesViewModels",
      dependencies: ["ShapesDependencies", "ShapesClients", "ShapesModels", "ShapesUtil"]),
    // The Swift API, all of it: what Kotlin sees through the bindings (Tests/shared) and what it doesn't.
    .testTarget(
      name: "ShapesTests",
      dependencies: [
        "ShapesUtil", "ShapesModels", "ShapesClients", "ShapesDependencies", "ShapesViewModels",
        .product(
          name: "OpenCombine", package: "OpenCombine",
          condition: .when(platforms: [.android, .linux])),
      ]
    ),
  ]
)
