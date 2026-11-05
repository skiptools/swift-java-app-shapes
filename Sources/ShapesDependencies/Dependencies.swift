import Foundation
import ShapesClients
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: the dependencies a view model reads.
public struct Dependencies: Sendable {
  public let clients: Clients
  public let system: System
  public let state: AppState

  public init(clients: Clients, system: System, state: AppState) {
    self.clients = clients
    self.system = system
    self.state = state
  }

  /// The dependencies the tests use: in-memory clients over a small catalog.
  public static func preview() -> Dependencies {
    let books = [
      Book(id: "1", title: "A Short History", pages: 120, genre: .history),
      Book(id: "2", title: "Cosmos", pages: 300, genre: .science),
      Book(id: "3", title: "A Long Story", pages: 450, genre: .fiction),
    ]
    let shelf = Shelf(id: ShelfID("main"), books: books, tags: ["new"])
    return Dependencies(
      clients: Clients(
        search: SearchClientMock(id: "mock", books: books),
        notifications: NotificationsClientMock(),
        catalog: CatalogClient(shelves: [shelf])
      ),
      system: System(scheme: .debug, appName: "Library"),
      state: AppState()
    )
  }
}
