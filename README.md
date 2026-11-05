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
| `ShapesModels` | `annotated` | Codable entities with Foundation values, raw-value enums, enums with payloads (one carrying an `Error`, one whose case shadows a payload type, one a closure), nested arrays, sets, optional labeled tuples, overloads that differ only in pointer types, clashing accessor names, a default-argument overload that would be ambiguous, a parameter named `result`, a `@MainActor` callback typealias |
| `ShapesClients` | `annotated` | client protocols used as bare existentials, a protocol Kotlin implements, returned by a Kotlin closure, protocol extensions implementing requirements and adding methods, mocks that rely on them, a requirement taking a closure, an extension of another module's type, dictionaries and sets of another module's types, Combine state, an `AsyncStream`, a long-running `async` function that stops when cancelled |
| `ShapesDependencies` | `all` | a container of clients typed as another module's protocols, `@autoclosure @escaping` configuration returning another module's enum, app state, async functions taking entities |
| `ShapesViewModels` | `annotated` | `@MainActor` `@Observable` view models, callbacks typed with another module's `@MainActor` typealias, callbacks taking entities, arrays of entities, `[URL]`, optional strings and numbers, async callbacks returning futures, a closure returning an optional array of entities |

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

## Kotlin ergonomics

The bindings are Java, so Kotlin calls them through Java's types: `Optional`, `CompletableFuture`,
functional interfaces. `"kotlinOutput": true` in `swift-java.config` (opt-in; the default Java is unchanged)
keeps the generated Java as the binding layer (same JNI glue, SwiftKit runtime and Gradle setup) and
1. emits Java that reads well from Kotlin: nullable types instead of `Optional`, and `async` and stream
   methods named `<name>Async` and `<name>Stream` so the Kotlin functions below aren't shadowed by them;
2. adds a `<Module>Kotlin.kt` per module, which needs kotlin-stdlib and kotlinx-coroutines (hence opt-in):
   `suspend` functions, `Flow`s, extension functions, and `suspending { }` for async callbacks.

Every module here sets it. The Gradle projects compile the generated `.kt` with the Java
(`kotlin.srcDirs`), and depend on kotlinx-coroutines-core. Before is what `Tests/shared` wrote without it;
after is what it writes now.

**Optionals** in closure parameters and enum payloads (method parameters and results were already
nullable, with `optionalsAsNullable`, which `kotlinOutput` implies):

```kotlin
// Before
{ code: Optional<String>, attempt: OptionalLong ->
    verified += code.orElse(null) to (if (attempt.isPresent) attempt.asLong else null)
}
assertEquals("bye", closed.reason.get())

// After
{ code: String?, attempt: Long? -> verified += code to attempt }
assertEquals("bye", closed.reason)
```

**Enums with payloads**: their `Case` is a Java sealed interface of records, which Kotlin's `when` checks
exhaustively (a missing case doesn't compile: `ModelsTest.enumPayloads`):

```kotlin
// Before
val closed = Message.closed(1000, "bye").getAsClosed()!!.get()
assertEquals(1000, closed.code)

// After
when (val case = message.case) {
    is Message.Case.Closed -> assertEquals(1000, case.code)
    is Message.Case.String -> fail()
}
```

**`async` functions**, as `suspend` functions that throw the Swift error; cancelling the coroutine cancels
the Swift task (`ClientsTest.cancellingTheCoroutineCancelsTheSwiftTask`):

```kotlin
// Before
val offline = assertFailsWith<ExecutionException> { state.borrow(book).get() }
assertIs<LibraryError>(offline.cause)
vm.load("a").awaitOnMain()  // a helper running the main loop while it waits

// After (import com.example.shapes.dependencies.borrow)
assertFailsWith<LibraryError> { state.borrow(book) }
vm.load("a")  // in a coroutine on the main thread
```

**`async` callbacks**, as suspend lambdas run by `suspending { }`:

```kotlin
// Before
{ vm: ShelfViewModel, genre: Genre -> shared += vm.appName; CompletableFuture.completedFuture(null) }

// After
{ vm: ShelfViewModel, genre: Genre -> suspending { shared += vm.appName } }
```

**`AsyncStream`s**, as `Flow`s; cancelling the collection cancels the Swift task iterating the stream:

```kotlin
// Before: no shape
// After
val values = progress.updates().toList()  // DownloadProgress.updates() -> AsyncStream<Double>
```

**An extension of another module's type**, as extension functions:

```kotlin
// Before
val sharing = com.example.shapes.clients.Book.wrapMemoryAddressUnsafe(book.`$memoryAddress`(), SwiftArena.ofConfined())
sharing.shareText()

// After (import com.example.shapes.clients.shareText)
book.shareText()
```

Decisions, and what's left:
- Enums keep their class and a sealed `getCase()` (`when (val case = message.case)`), rather than becoming
  the sealed type themselves (`when (message)`), which would make each case a subclass holding the Swift
  value.
- `async` callbacks still return a future in Java, so Kotlin passes `suspending { … }` rather than a bare
  suspend lambda: a Java functional interface can't take one.
- `@MainActor` work: a `suspend` call on Android's main dispatcher lets the main looper run it. The JVM
  tests' `runMain` is a main dispatcher that runs Swift's main loop, replacing `awaitOnMain()`.
- Closure results are still Java optionals (`ShelfViewModel.setSeedProvider`), and a Kotlin wrapper for a
  type's static `async` function isn't generated (Kotlin can't add static members to a Java class).
- Out of scope: Observation to Compose state (Skip's), and arrays as `List`s.

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
- Kotlin implementations of Swift protocols (`ShapesClients`) need `enableJavaCallbacks`. By default that
  runs Gradle, javac and wrap-java inside the SwiftPM build, with its sandbox disabled;
  `"javaCallbacksBindings": "jextract"` has jextract print the Swift bindings it needs instead.

## Gaps

Marked `@JavaExport(false)` with a `// Gap:` comment. Fixing one means removing its annotation, which the
build and the Kotlin tests then check.

- `#if`: without a static build configuration jextract treats every platform as active, so a macOS
  build gets thunks for `#if os(Android)` API (`Platform.androidOnly()`,
  `ShelfViewModel.androidBackPressed()`), and it treats `canImport(_:)` as false.
- Optional arrays of primitives as parameters (`Shelf.withPageCounts(_:)`; they work as results).
- An extension of another module's type (`extension Book` in `ShapesClients`) becomes a separate Java
  class, `com.example.shapes.clients.Book`, rather than members Kotlin can call on a
  `com.example.shapes.models.Book`: Kotlin reaches it only by wrapping the entity's address.
- Sets as parameters (`Shelf.init(id:books:tags:)`): Kotlin can't create a `SwiftSet`, so it can pass only
  a set Swift returned.

The tests mark where they work around a gap with a `// Gap:` comment.
