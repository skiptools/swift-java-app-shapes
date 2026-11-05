import Foundation
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

@JavaExport
public protocol SearchClient: Sendable {
  var id: String { get }
  var name: String { get }
  func search(query: String) async throws -> [Book]
}

/// Shape: a protocol extension implementing a requirement and adding a method.
extension SearchClient {
  public var name: String { "search \(id)" }

  public func uid() -> String {
    "\(id)::uid"
  }
}

/// Shape: a conformer that declares neither `name` nor `uid()`.
@JavaExport
public final class SearchClientMock: SearchClient {
  public let id: String
  private let books: [Book]

  public init(id: String, books: [Book]) {
    self.id = id
    self.books = books
  }

  public func search(query: String) async throws -> [Book] {
    guard !query.isEmpty else {
      throw LibraryError.notFound(id: query)
    }
    return books.filter { $0.title.localizedCaseInsensitiveContains(query) }
  }
}
