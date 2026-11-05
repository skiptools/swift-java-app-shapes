import Foundation
import Testing

import ShapesClients
import ShapesDependencies
import ShapesModels

struct DependenciesTests {
  @Test func stateValue() {
    let value = StateValue<Int64>(1)
    value.value += 1
    #expect(value.value == 2)
  }

  @Test func appState() async throws {
    let state = AppState()
    #expect(state.launchCount.value == 0)
    #expect(state.shelves.isEmpty)
    #expect(state.reader == nil)

    let book = Book(id: "1", title: "Cosmos")
    state.load(from: CatalogClient(shelves: [Shelf(id: ShelfID("main"), books: [book])]))
    #expect(state.shelves[ShelfID("main")]?.books == [book])

    await #expect(throws: LibraryError.self) { try await state.borrow(book) }
    await state.connect(reader: Reader(name: "Ada"))
    #expect(state.reader?.name == "Ada")
    let loan = try await state.borrow(book)
    #expect(loan.book == book)
    #expect(loan.days == 14)
    #expect(Loan(book: book, days: 7).days == 7)
    await state.connect(reader: nil)
    #expect(state.reader == nil)
  }

  @Test func systemEvaluatesLazily() {
    let reads = Counter()
    func name() -> String {
      reads.increment()
      return "Library"
    }
    let system = System(scheme: .release, appName: name())
    #expect(reads.value == 0)
    #expect(system.appName() == "Library")
    #expect(system.scheme() == .release)
    #expect(reads.value == 1)
  }

  @Test func dependencies() async throws {
    let preview = Dependencies.preview()
    #expect(preview.system.scheme() == .debug)
    #expect(preview.system.appName() == "Library")
    #expect(preview.clients.catalog.ids() == [ShelfID("main")])
    #expect(preview.clients.search.name == "search mock")
    #expect(try await preview.clients.search.search(query: "a").count == 2)
    preview.clients.notifications.notify(.string("hi"))
    #expect((preview.clients.notifications as? NotificationsClientMock)?.delivered == ["hi"])

    let clients = Clients(
      search: SearchClientMock(id: "s", books: []),
      notifications: NotificationsClientMock(),
      catalog: CatalogClient(shelves: [])
    )
    let state = AppState()
    let dependencies = Dependencies(
      clients: clients, system: System(scheme: .debug, appName: "App"), state: state)
    #expect(dependencies.clients.search.id == "s")
    #expect(dependencies.clients.catalog.all().isEmpty)
    #expect(dependencies.system.appName() == "App")
    #expect(dependencies.state === state)
  }
}
