import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a hashable key used in dictionaries across modules.
@JavaExport
public struct ShelfID: Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

/// Shape: collections of entities: nested arrays, sets, optional primitive arrays.
@JavaExport
public struct Shelf: Sendable {
  public let id: ShelfID
  public let books: [Book]
  public let tags: Set<String>
  public let pageCounts: [Int64]?

  public init(id: ShelfID, books: [Book], tags: Set<String> = []) {
    self.id = id
    self.books = books
    self.tags = tags
    self.pageCounts = nil
  }

  private init(_ shelf: Shelf, pageCounts: [Int64]?) {
    id = shelf.id
    books = shelf.books
    tags = shelf.tags
    self.pageCounts = pageCounts
  }

  /// Shape: an optional array of primitives as a parameter.
  /// Gap: optional primitive arrays are supported as results, not yet as parameters.
  @JavaExport(false)
  public func withPageCounts(_ pageCounts: [Int64]?) -> Shelf {
    Shelf(self, pageCounts: pageCounts)
  }

  /// Shape: rows of entities.
  public func sections(size: Int64) -> [[Book]] {
    stride(from: 0, to: books.count, by: Int(size)).map {
      Array(books[$0..<min($0 + Int(size), books.count)])
    }
  }

  public static func merge(_ sections: [[Book]], id: ShelfID) -> Shelf {
    Shelf(id: id, books: sections.flatMap { $0 })
  }
}
