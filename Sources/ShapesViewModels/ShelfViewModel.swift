import Foundation
import Observation
import ShapesClients
import ShapesDependencies
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a main-actor `@Observable` view model with async loading and many kinds of callbacks.
@JavaExport
@MainActor
@Observable
public final class ShelfViewModel {
  @JavaExport
  public struct Callbacks: @unchecked Sendable {
    @JavaExport(false) public let onOpen: @MainActor (Book) -> Void
    @JavaExport(false) public let onSelect: @MainActor ([Book]) -> Void
    @JavaExport(false) public let onShareLinks: @MainActor ([URL]) -> Void
    @JavaExport(false) public let onVerify: @MainActor (String?, Int64?) -> Void
    @JavaExport(false) public let onShare: @MainActor (ShelfViewModel, Genre) async -> Void
    @JavaExport(false) public let onSetIcon: @MainActor (String?) async -> Void

    public init(
      onOpen: @escaping @MainActor (Book) -> Void = { _ in },
      onSelect: @escaping @MainActor ([Book]) -> Void = { _ in },
      onShareLinks: @escaping @MainActor ([URL]) -> Void = { _ in },
      onVerify: @escaping @MainActor (String?, Int64?) -> Void = { _, _ in },
      onShare: @escaping @MainActor (ShelfViewModel, Genre) async -> Void = { _, _ in },
      onSetIcon: @escaping @MainActor (String?) async -> Void = { _ in }
    ) {
      self.onOpen = onOpen
      self.onSelect = onSelect
      self.onShareLinks = onShareLinks
      self.onVerify = onVerify
      self.onShare = onShare
      self.onSetIcon = onSetIcon
    }
  }

  @ObservationIgnored private let dependencies: Dependencies
  @ObservationIgnored private let callbacks: Callbacks
  @ObservationIgnored private var seedProvider: ((String) -> [Book]?)?
  public private(set) var books: [Book] = []
  public private(set) var isLoading = false

  public init(dependencies: Dependencies, callbacks: Callbacks) {
    self.dependencies = dependencies
    self.callbacks = callbacks
  }

  public var appName: String { dependencies.system.appName() }

  public func load(query: String) async throws {
    isLoading = true
    defer { isLoading = false }
    books = try await dependencies.clients.search.search(query: query)
  }

  public func open(index: Int64) {
    callbacks.onOpen(books[Int(index)])
  }

  public func selectAll() {
    callbacks.onSelect(books)
    callbacks.onShareLinks(books.compactMap(\.coverURL))
  }

  public func verify(code: String?, attempt: Int64?) {
    callbacks.onVerify(code, attempt)
  }

  public func share(genre: Genre) async {
    await callbacks.onShare(self, genre)
  }

  public func setIcon(_ name: String?) async {
    await callbacks.onSetIcon(name)
  }

  /// Shape: a seed provider returning an optional array of entities.
  public func setSeedProvider(_ provider: @escaping (String) -> [Book]?) {
    seedProvider = provider
  }

  /// Shows the provider's books for `query` until a load replaces them; none when it has none.
  public func seed(query: String) {
    books = seedProvider?(query) ?? []
  }

  #if os(Android)
    /// Shape: Android-only API on a view model.
    /// Gap: see `Platform.androidOnly()`.
    @JavaExport(false)
    public func androidBackPressed() {}
  #endif
}
