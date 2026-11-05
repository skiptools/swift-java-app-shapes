import Foundation
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: dictionaries and sets of another module's types.
@JavaExport
public struct CatalogClient: Sendable {
  private let shelves: [ShelfID: Shelf]

  public init(shelves: [Shelf]) {
    self.shelves = Dictionary(uniqueKeysWithValues: shelves.map { ($0.id, $0) })
  }

  public func all() -> [ShelfID: Shelf] {
    shelves
  }

  public func ids() -> Set<ShelfID> {
    Set(shelves.keys)
  }

  /// Shape: a protocol, of another module, returned by a closure.
  /// Gap: closures returning `any P` aren't supported yet.
  @JavaExport(false)
  public func makeSearch() -> () -> any SearchClient {
    let books = shelves.values.flatMap(\.books)
    return { SearchClientMock(id: "catalog", books: books) }
  }
}
