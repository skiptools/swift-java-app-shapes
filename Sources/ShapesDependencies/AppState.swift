import Foundation
import ShapesClients
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a generic wrapper for persisted values.
/// Gap: generic classes used with type arguments (`StateValue<Int64>`) aren't supported yet.
@JavaExport(false)
public final class StateValue<Value: Sendable>: @unchecked Sendable {
  public var value: Value

  public init(_ value: Value) {
    self.value = value
  }
}

/// Shape: app state with values Java reads, and one it doesn't.
public final class AppState: @unchecked Sendable {
  @JavaExport(false)
  public let launchCount = StateValue<Int64>(0)
  public private(set) var shelves: [ShelfID: Shelf] = [:]
  public private(set) var reader: Reader?

  public init() {}

  public func load(from catalog: CatalogClient) {
    shelves = catalog.all()
  }

  /// Shape: an async function taking an optional entity.
  public func connect(reader: Reader?) async {
    self.reader = reader
  }

  /// Shape: an async throwing function taking an entity.
  public func borrow(_ book: Book) async throws -> Loan {
    guard reader != nil else {
      throw LibraryError.offline
    }
    return Loan(book: book, days: 14)
  }
}

public struct Reader: Sendable {
  public let name: String

  public init(name: String) {
    self.name = name
  }
}

public struct Loan: Sendable {
  public let book: Book
  public let days: Int64

  public init(book: Book, days: Int64) {
    self.book = book
    self.days = days
  }
}
