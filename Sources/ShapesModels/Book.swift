import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a Codable entity with Foundation values, a `default` (a Java keyword) and a field Java doesn't see.
@JavaExport
public struct Book: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let title: String
  public let pages: Int64
  public let genre: Genre
  public let coverURL: URL?
  public let published: Date
  @JavaExport(false)
  public let rawPayload: Data?

  public init(
    id: String, title: String, pages: Int64 = 100, genre: Genre = .fiction, coverURL: URL? = nil
  ) {
    self.id = id
    self.title = title
    self.pages = pages
    self.genre = genre
    self.coverURL = coverURL
    self.published = Date(timeIntervalSince1970: 0)
    self.rawPayload = nil
  }

  public static let `default` = Book(id: "0", title: "Untitled")

  /// Shape: an optional labeled tuple.
  public var pageRange: (first: Int64?, last: Int64?)? {
    pages > 0 ? (first: 1, last: pages) : nil
  }

  /// Shape: Codable plumbing, which Kotlin doesn't need.
  @JavaExport(false)
  public static func decode(_ data: Data) throws -> Book {
    try JSONDecoder().decode(Book.self, from: data)
  }
}
