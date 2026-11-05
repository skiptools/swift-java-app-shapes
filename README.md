# swift-java app shapes

A small Swift package with the code shapes of a production app whose Swift code runs on iOS and Android,
with its Android UI in Kotlin. jextract ([swift-java](https://github.com/swiftlang/swift-java), JNI mode)
generates the Java bindings; Kotlin tests exercise them on the JVM and on an Android emulator.

The domain (a reading app) is made up; the shapes are the ones the app needed: how its modules depend
on each other, what it exports to Kotlin and what it keeps Swift-only, and how its view models talk to
the UI. It uses swift-java from [skiptools/swift-java](https://github.com/skiptools/swift-java)'s
`skip/integration` branch (the `swift-java` submodule): upstream swift-java plus the changes proposed to
it, which this package needs.

|  | Builds | Tests |
|---|---|---|
| iOS | `xcodebuild`, without swift-java | — |
| macOS | `swift build`, with or without jextract | `swift test` (Swift), `./gradlew :jvm:test` (Kotlin on the JVM) |
| Android | cross-compiled with the Swift SDK for Android | `scripts/android-tests.sh` (Kotlin on an emulator) |

`Tests/ShapesTests` exercises all of the Swift API, exported or not; the Kotlin tests exercise all of
what the bindings export.

## Layout

```
Package.swift            five Swift 6 modules, linked into one library (ShapesApp)
Sources/<Module>/        about 20 source files, and each module's swift-java.config
Tests/ShapesTests/       the Swift tests
Tests/shared/            the Kotlin tests, the same on the JVM and on Android
Tests/jvm, Tests/android how each platform runs code on the main thread
jvm/, android/           the Gradle projects that build the package and run the tests
swift-java/              skiptools/swift-java at skip/integration (submodule)
```

| Module | `exportMode` | Shapes |
|---|---|---|
| `ShapesUtil` | `all` | static helpers, constants inferred from literals, `@autoclosure` arguments, Java keywords as names, a method named like `Object.wait()`, platform-specific API |
| `ShapesModels` | `annotated` | Codable entities with Foundation values, raw-value enums, enums with payloads (one carrying an `Error`, one whose case shadows a payload type), nested arrays, sets, optional labeled tuples, overloads that differ only in pointer types, clashing accessor names, a default-argument overload that would be ambiguous, a parameter named `result`, a `@MainActor` callback typealias |
| `ShapesClients` | `annotated` | client protocols used as bare existentials, protocol extensions implementing requirements and adding methods, mocks that rely on them, a requirement taking a closure, an extension of another module's type, dictionaries and sets of another module's types, Combine state |
| `ShapesDependencies` | `all` | a container of clients typed as another module's protocols, `@autoclosure @escaping` configuration returning another module's enum, app state, async functions taking entities |
| `ShapesViewModels` | `annotated` | `@MainActor` `@Observable` view models, callbacks typed with another module's `@MainActor` typealias, callbacks taking entities, arrays of entities, `[URL]`, optional strings and numbers, async callbacks returning futures |

Every module sets `failOnSkippedDeclarations`, so building with jextract fails when it can't handle
something. Shapes it doesn't handle yet are marked `@JavaExport(false)` with a `// Gap:` comment (below).

## Running it

```bash
git clone --recurse-submodules https://github.com/skiptools/swift-java-app-shapes.git
swift test                          # Swift tests (SWIFT_JAVA_BUILD=1 swift test: with jextract)
./gradlew :jvm:test                 # macOS: Kotlin tests on the JVM (builds the package with jextract)
xcodebuild -scheme swift-java-app-shapes -destination 'generic/platform=iOS Simulator' build
scripts/android-tests.sh            # Kotlin tests on an Android emulator
```

**Apple platforms** build without swift-java: as in
[swiftlang/swift-java#694](https://github.com/swiftlang/swift-java/issues/694), the package adds swift-java
and the jextract plugin only when `SWIFT_JAVA_BUILD` is set (the Gradle builds set it), and otherwise
depends only on the JNI-free `SwiftJavaAnnotations` for the `@JavaExport` markers.

**Android** needs the Android SDK with an arm64 emulator image, the Swift SDK for Android and the
swift.org toolchain of the same version (6.4.2 by default; `-PswiftToolchain=<path>` and
`-PswiftAndroidSdk=<path>` change them). Both are on [swift.org/install](https://www.swift.org/install/);
the SDK installs with `swift sdk install <artifact bundle URL>`.

The Android project cross-compiles the package, packages `libShapesApp.so` with the Swift runtime, and
runs `Tests/shared` as instrumented tests. Its test runner loads the Swift libraries on the main thread
before the tests run, as an app does at startup: libdispatch binds its main queue, which Swift's main
actor runs on, to the thread that loads it.

## What it takes to use swift-java from outside its repository

These are what this repository had to set up itself, and what an app would too:

- `SwiftKitCore`, the Java runtime of the bindings, isn't published: the Gradle build includes the
  `swift-java` submodule's build (`includeBuild`) to get it.
- The Gradle helpers swift-java's own samples use (running jextract, finding the generated Java, library
  paths) are internal to its repository: `jvm/build.gradle.kts` and `android/build.gradle.kts` do the
  same in a few lines each.
- One library for all modules (`nativeLibraryName` in each `swift-java.config`): with a library per
  module, each links its own copy of the modules it depends on, and Swift casts fail between the copies.
- The Swift SDK for Android needs the swift.org toolchain of its version, first on `PATH`: swift-java's
  build plugins run `swift` themselves.

## Gaps

Marked `@JavaExport(false)` with a `// Gap:` comment. Fixing one means removing its annotation, which the
build and the Kotlin tests then check.

- `#if`: without a static build configuration jextract treats every platform as active, so a macOS
  build gets thunks for `#if os(Android)` API (`Platform.androidOnly()`,
  `ShelfViewModel.androidBackPressed()`), and it treats `canImport(_:)` as false.
- Generic classes used with type arguments (`StateValue<Int64>`).
- Closures returning a protocol type (`CatalogClient.makeSearch()`).
- Closures taking or returning optional arrays (`ShelfViewModel.setSeedProvider(_:)`).
- Optional arrays of primitives as parameters (`Shelf.withPageCounts(_:)`; they work as results).
- Enum cases with closure payloads over jextracted types (`SortPolicy`); a single case can't be left out
  either.
- An extension of another module's type (`extension Book` in `ShapesClients`) becomes a separate Java
  class, `com.example.shapes.clients.Book`, rather than members Kotlin can call on a
  `com.example.shapes.models.Book`: Kotlin reaches it only by wrapping the entity's address.
- Sets as parameters (`Shelf.init(id:books:tags:)`): Kotlin can't create a `SwiftSet`, so it can pass only
  a set Swift returned.

The tests mark where they work around a gap with a `// Gap:` comment.
