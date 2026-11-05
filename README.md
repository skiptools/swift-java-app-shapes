# swift-java app shapes

A small Swift package with the code shapes of a production app whose Swift code runs on iOS and Android,
and whose Android UI is Kotlin. [swift-java](https://github.com/swiftlang/swift-java)'s jextract (JNI mode)
generates the bindings, and Kotlin tests exercise them on the JVM and on an Android emulator.

The domain (a reading app) is made up; the shapes are the ones the app needs: how its modules depend on
each other, what it exports to Kotlin and what it keeps Swift-only, and how its view models talk to the UI.
It shows where swift-java can get to for a Kotlin app: the package uses upstream swift-java plus the series
of changes [listed below](#how-we-got-here-the-changes-to-swift-java), from the `skip/integration` branch of
[skiptools/swift-java](https://github.com/skiptools/swift-java) (the `swift-java` submodule).

With `"kotlinOutput": true` in each module's `swift-java.config`, Kotlin uses the Swift code like this
(adapted from `Tests/shared`):

```kotlin
val vm = ShelfViewModel.init(Dependencies.preview(), ShelfViewModel.Callbacks.init())
vm.load("cosmos")                        // a suspend call; cancelling the coroutine cancels the Swift task

when (val case = message.case) {         // exhaustive over the enum's cases
    is Message.Case.Closed -> case.reason  // String?, not Optional<String>
    is Message.Case.String -> case.arg0
}

progress.updates().collect { show(it) }  // a Flow over a Swift AsyncStream
book.shareText()                         // an extension function, from an extension in another module

LifecycleObserverFactory.init { id ->    // Kotlin implements a Swift protocol, returned to Swift
    object : LifecycleObserver { override fun dispose() = stop(id) }
}
```

|  | Builds | Tests |
|---|---|---|
| iOS | `xcodebuild`, without swift-java | — |
| macOS | `swift build`, with or without jextract | `swift test` (Swift), `./gradlew :jvm:test` (Kotlin on the JVM) |
| Android | cross-compiled with the Swift SDK for Android | `scripts/android-tests.sh` (Kotlin on an emulator) |

`Tests/ShapesTests` exercises all of the Swift API, exported or not; the Kotlin tests exercise all of what
the bindings export.

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
| `ShapesViewModels` | `annotated` | `@MainActor` `@Observable` view models, callbacks typed with another module's `@MainActor` typealias, callbacks taking entities, arrays of entities, `[URL]`, optional strings and numbers, `async` callbacks (suspend lambdas in Kotlin), a closure returning an optional array of entities |

Every module sets `failOnSkippedDeclarations`, so building with jextract fails when it can't handle
something. Shapes it doesn't handle yet are marked `@JavaExport(false)` with a `// Gap:` comment
([Gaps and limits](#gaps-and-limits)).

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

`"kotlinOutput": true` (opt-in; without it the generated Java is unchanged) keeps the generated Java as the
binding layer (same JNI glue, SwiftKit runtime and Gradle setup) and
1. emits Java that reads well from Kotlin: nullable types instead of `Optional`, and `async` and stream
   methods named `<name>Async` and `<name>Stream` so the Kotlin functions below aren't shadowed by them;
2. adds a `<Module>Kotlin.kt` per module, which needs kotlin-stdlib and kotlinx-coroutines (hence opt-in):
   `suspend` functions, `Flow`s, extension functions, and `suspending { }` for async callbacks.

The Gradle projects compile the generated `.kt` with the Java (`kotlin.srcDirs`) and depend on
kotlinx-coroutines-core. Before is what `Tests/shared` wrote without `kotlinOutput`; after is what it writes
now.

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

## How we got here: the changes to swift-java

`skip/integration` is upstream `main` plus the branches below, merged in this order. Each is one change, with
its tests, on [piercifani/swift-java](https://github.com/piercifani/swift-java), and its link shows its diff
against upstream. Five are open upstream PRs; the others aren't opened yet. Each was checked against this
package, and against the app it comes from (no new skipped declarations, javac or Swift errors).

| # | Change | Branch | Based on | Upstream PR |
|---|---|---|---|---|
| 1 | Escaping closures taking or returning jextracted types, `@Sendable`/`@MainActor` closures, across modules | [`jextract-closures-jextracted-types`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-closures-jextracted-types) | upstream `main` |  |
| 2 | Report every skipped declaration; `failOnSkippedDeclarations` | [`jextract-skipped-declarations`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-skipped-declarations) | upstream `main` |  |
| 3 | Enum payload types shadowed by the `Case` records' names | [`jextract-enum-case-name-collision`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-enum-case-name-collision) | upstream `main` |  |
| 4 | `Int` closures, `inout` thunks, unannotated variable types | [`jextract-codegen-fixes`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-codegen-fixes) | branch 2 |  |
| 5 | Java implementations of `async` and cross-module protocols | [`jextract-java-implemented-protocols`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-java-implemented-protocols) | upstream `main` |  |
| 6 | Swift class hierarchies as Java class hierarchies | [`jextract-class-inheritance`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-class-inheritance) | upstream `main` |  |
| 7 | Cancelling an `async` function's future cancels the Swift task | [`jextract-async-cancellation`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-async-cancellation) | branch 5 |  |
| 8 | Wrappers of the same Swift object are equal; `getCase()` without an arena | [`jextract-object-identity`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-object-identity) | upstream `main` |  |
| 9 | `AsyncStream` results as `SwiftAsyncStream` | [`jextract-async-stream`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-async-stream) | branch 2 |  |
| 10 | `AsyncThrowingStream` results, errors delivered to `onError` | [`jextract-async-throwing-stream`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-async-throwing-stream) | branch 9 |  |
| 11 | Arrays of optionals, dictionaries and sets | [`jextract-optional-nested-arrays`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-optional-nested-arrays) | branch 2 |  |
| 12 | `payloadlessEnumsAsJavaEnums`: Java enums for enums without payloads | [`jextract-java-enums`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-java-enums) | upstream `main` |  |
| 13 | Java overloads for trailing default arguments | [`jextract-default-arguments`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-default-arguments) | upstream `main` |  |
| 14 | `optionalsAsNullable`: optionals as nullable Java types | [`jextract-nullable-optionals`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-nullable-optionals) | upstream `main` |  |
| 15 | Non-escaping closures taking or returning jextracted types | [`jextract-closure-struct-arguments`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-closure-struct-arguments) | branch 1 |  |
| 16 | Java enum constants keep the Swift case names | [`jextract-enum-swift-case-names`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-enum-swift-case-names) | branch 12 |  |
| 17 | `nullableAnnotation` and `nonNullAnnotation`, for Kotlin's nullability | [`jextract-nullability-annotations`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-nullability-annotations) | branch 14 |  |
| 18 | `@JavaExport(false)` and `exportMode`; prefix and postfix operators skipped | [`jextract-export-control`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-export-control) | upstream `main` | [#950](https://github.com/swiftlang/swift-java/pull/950), [#951](https://github.com/swiftlang/swift-java/pull/951) |
| 19 | `foundationTypesAsJavaTypes`: Foundation values as standard Java types | [`jextract-foundation-java-types`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-foundation-java-types) | upstream `main` | [#952](https://github.com/swiftlang/swift-java/pull/952) |
| 20 | `closureMethodName`: the method name of closure interfaces | [`jextract-closure-method-name`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-closure-method-name) | upstream `main` | [#953](https://github.com/swiftlang/swift-java/pull/953) |
| 21 | Swift names that are Java keywords | [`jextract-java-identifiers`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-java-identifiers) | upstream `main` | [#954](https://github.com/swiftlang/swift-java/pull/954) |
| 22 | Overloads that lower to the same native signature | [`jextract-name-collisions`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-name-collisions) | upstream `main` |  |
| 23 | A bare protocol in a value position is an existential | [`jextract-implicit-existentials`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-implicit-existentials) | upstream `main` |  |
| 24 | Arrays of arrays of jextracted types | [`jextract-nested-object-arrays`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-nested-object-arrays) | upstream `main` |  |
| 25 | Interfaces of unlabeled closure parameters | [`jextract-unnamed-closure-parameters`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-unnamed-closure-parameters) | upstream `main` |  |
| 26 | Protocol extension members as default methods of the Java interface | [`jextract-protocol-extensions`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-protocol-extensions) | upstream `main` |  |
| 27 | Conformers take the protocol's functional interfaces for closure parameters | [`jextract-protocol-closure-parameters`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-protocol-closure-parameters) | branch 26 |  |
| 28 | Optional arrays of primitives as results | [`jextract-optional-result-types`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-optional-result-types) | upstream `main` |  |
| 29 | Type bridges usable by other modules' thunks | [`jextract-public-type-bridges`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-public-type-bridges) | upstream `main` |  |
| 30 | `async` thunks capture jextracted arguments | [`jextract-async-argument-captures`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-async-argument-captures) | upstream `main` |  |
| 31 | `@autoclosure` parameters take a Java lambda | [`jextract-autoclosure-parameters`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-autoclosure-parameters) | upstream `main` |  |
| 32 | Parameters named like the thunk's own locals | [`jextract-reserved-parameter-names`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-reserved-parameter-names) | upstream `main` |  |
| 33 | Thunks for another module's type go in the extending file | [`jextract-extension-thunk-files`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-extension-thunk-files) | upstream `main` |  |
| 34 | Enum cases with closure payloads | [`jextract-enum-unbridged-payloads`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-enum-unbridged-payloads) | upstream `main` |  |
| 35 | Closures returning arrays of jextracted types, optional or not | [`jextract-closure-array-results`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-closure-array-results) | branch 1 |  |
| 36 | `javaCallbacksBindings: jextract`; closures returning a protocol Kotlin implements | [`jextract-protocol-bindings`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-protocol-bindings) | branch 35 |  |
| 37 | `kotlinOutput`: Java shaped for Kotlin, and a Kotlin file per module | [`jextract-kotlin-output`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-kotlin-output) | `skip/integration` |  |
| 38 | A `Sendable` protocol's existential captured without `nonisolated(unsafe)` | [`jextract-sendable-existential-captures`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:jextract-sendable-existential-captures) | upstream `main` |  |
| 39 | swift-java's Gradle scripts without APIs Gradle deprecates | [`gradle-deprecations`](https://github.com/swiftlang/swift-java/compare/main...piercifani:swift-java:gradle-deprecations) | upstream `main` |  |

`skip/integration` also has, beyond these branches (see [Gaps and limits](#gaps-and-limits)):
- the change of [#938](https://github.com/swiftlang/swift-java/pull/938) (`@MainActor` isolation in synchronous thunks), closed upstream;
- a few commits that combine several branches (`Integration: …`), not yet split into branches of their own.

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

## Gaps and limits

**What jextract doesn't handle yet**, marked `@JavaExport(false)` with a `// Gap:` comment: fixing one means
removing its annotation, which the build and the Kotlin tests then check. The app's Kotlin uses none of them.
- `#if`: without a static build configuration jextract treats every platform as active, so a macOS build
  gets thunks for `#if os(Android)` API (`Platform.androidOnly()`, `ShelfViewModel.androidBackPressed()`),
  and it treats `canImport(_:)` as false.
- Optional arrays of primitives as parameters (`Shelf.withPageCounts(_:)`; they work as results).
- Sets as parameters (`Shelf.init(id:books:tags:)`): Kotlin can't create a `SwiftSet`, so it can pass only a
  set Swift returned (the test marks it with `// Gap:`).

**`kotlinOutput`, as prototyped:**
- Enums keep their class and a sealed `getCase()` (`when (val case = message.case)`), rather than becoming
  the sealed type themselves (`when (message)`), which would make each case a subclass holding the Swift
  value.
- `async` callbacks still return a future in Java, so Kotlin passes `suspending { … }` rather than a bare
  suspend lambda: a Java functional interface can't take one.
- Closure results are still Java optionals (`ShelfViewModel.setSeedProvider`), and a type's static `async`
  functions get no Kotlin wrapper (Kotlin can't add static members to a Java class).
- `@MainActor` work: a `suspend` call on Android's main dispatcher lets the main looper run it; the JVM
  tests' `runMain` is a main dispatcher that runs Swift's main loop.
- Out of scope: Observation to Compose state (Skip's), and arrays as `List`s.

**The path upstream:** a few changes aren't yet on a branch based on upstream `main`. `jextract-kotlin-output`
is based on `skip/integration`, the `Integration: …` commits combine several branches, and #938's change is
closed upstream. Splitting them into branches like the others makes `skip/integration` exactly upstream plus
the list above.
