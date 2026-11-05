import Foundation
import Observation
import Testing

import ShapesDependencies
import ShapesModels
import ShapesViewModels

@MainActor
struct ViewModelsTests {
  @Test func login() {
    var events: [String] = []
    let model = LoginViewModel(
      callbacks: .init(didLogin: { events.append("login") }, didCancel: { events.append("cancel") }))
    #expect(model.email == "")

    let changes = Counter()
    withObservationTracking { _ = model.email } onChange: { changes.increment() }
    model.submit(email: "a@example.com")
    #expect(changes.value == 1)
    #expect(model.email == "a@example.com")
    model.submit(email: "")
    #expect(events == ["login", "cancel"])

    LoginViewModel(callbacks: .init()).submit(email: "defaults")
  }

  @Test func shelf() async throws {
    var events: [String] = []
    let model = ShelfViewModel(
      dependencies: .preview(),
      callbacks: .init(
        onOpen: { events.append("open \($0.title)") },
        onSelect: { events.append("select \($0.count)") },
        onShareLinks: { events.append("links \($0.count)") },
        onVerify: { events.append("verify \($0 ?? "nil") \($1.map(String.init) ?? "nil")") },
        onShare: { model, genre in events.append("share \(genre.rawValue) \(model.books.count)") },
        onSetIcon: { events.append("icon \($0 ?? "nil")") }
      ))
    #expect(model.appName == "Library")
    #expect(model.books.isEmpty)
    #expect(!model.isLoading)

    try await model.load(query: "cosmos")
    #expect(model.books.map(\.title) == ["Cosmos"])
    #expect(!model.isLoading)
    await #expect(throws: LibraryError.self) { try await model.load(query: "") }
    #expect(!model.isLoading)

    try await model.load(query: "a")
    model.open(index: 1)
    model.selectAll()
    model.verify(code: "123", attempt: 2)
    model.verify(code: nil, attempt: nil)
    await model.share(genre: .science)
    await model.setIcon("dark")
    await model.setIcon(nil)
    model.setSeedProvider { query in query == "seeded" ? [Book(id: "9", title: "Seeded")] : nil }
    model.seed(query: "seeded")
    #expect(model.books.map(\.title) == ["Seeded"])
    model.seed(query: "other")
    #expect(model.books.isEmpty)
    #if os(Android)
      model.androidBackPressed()
    #endif
    #expect(
      events == [
        "open A Long Story", "select 2", "links 0", "verify 123 2", "verify nil nil", "share science 2",
        "icon dark", "icon nil",
      ])
  }

  @Test func shelfDefaultCallbacks() async throws {
    let model = ShelfViewModel(dependencies: .preview(), callbacks: .init())
    try await model.load(query: "a")
    model.open(index: 0)
    model.selectAll()
    model.verify(code: nil, attempt: nil)
    await model.share(genre: .fiction)
    await model.setIcon(nil)
  }

  @Test func mainLoop() {
    MainLoop.run(seconds: 0.01)
  }
}
