import Foundation
import Testing

import ShapesClients
import ShapesModels

#if canImport(Combine)
  import Combine
#else
  import OpenCombine
#endif

struct ClientsTests {
  let books = [
    Book(id: "1", title: "Cosmos", pages: 300, genre: .science),
    Book(id: "2", title: "A Long Story", pages: 450),
  ]

  @Test func bookSharing() {
    #expect(books[0].shareText() == "Cosmos (300 pages)")
  }

  @Test func search() async throws {
    let client: any SearchClient = SearchClientMock(id: "mock", books: books)
    #expect(client.id == "mock")
    #expect(client.name == "search mock")
    #expect(client.uid() == "mock::uid")
    #expect(try await client.search(query: "cosmos").map(\.id) == ["1"])
    await #expect(throws: LibraryError.self) { try await client.search(query: "") }
  }

  @Test func catalog() {
    let shelf = Shelf(id: ShelfID("main"), books: books)
    let catalog = CatalogClient(shelves: [shelf])
    #expect(catalog.ids() == [ShelfID("main")])
    #expect(catalog.all()[ShelfID("main")]?.books == books)
  }

  @Test func lifecycleObserverFactory() {
    final class Observer: LifecycleObserver {
      let disposed: Counter
      init(disposed: Counter) { self.disposed = disposed }
      func dispose() { disposed.increment() }
    }
    let disposed = Counter()
    let factory = LifecycleObserverFactory { _ in Observer(disposed: disposed) }
    factory.observeOnce(id: "a")
    factory.observeOnce(id: "b")
    #expect(disposed.value == 2)
  }

  @Test func notifications() {
    let client = NotificationsClientMock()
    let failures = Counter()
    client.onAuthError { failures.increment() }
    client.onAuthError { failures.increment() }
    client.failAuth()
    #expect(failures.value == 2)

    let notifications: any NotificationsClient = client
    notifications.notify(.string("hello"))
    notifications.notify(.closed(code: 1000, reason: "bye"))
    notifications.notify(.closed(code: 1001, reason: nil))
    #expect(client.delivered == ["hello", "closed 1000 bye", "closed 1001 "])
    #expect(client.deliveredCount == 3)
  }

  @Test func downloadProgress() {
    let progress = DownloadProgress()
    var values: [Double] = []
    let subscription = progress.publisher.sink { values.append($0) }
    progress.advance(by: 0.5)
    progress.advance(by: 0.75)
    #expect(progress.current == 1)
    #expect(values == [0, 0.5, 1])
    subscription.cancel()
  }
}

final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int { lock.withLock { count } }

  func increment() {
    lock.withLock { count += 1 }
  }
}
