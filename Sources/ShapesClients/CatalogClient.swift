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
}
