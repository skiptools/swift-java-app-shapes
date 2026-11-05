import Foundation
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a protocol Kotlin implements.
@JavaExport
public protocol LifecycleObserver: Sendable {
  func dispose()
}

/// Shape: a factory taking a closure that returns the protocol: Kotlin passes the closure, Swift calls it,
/// and it returns Kotlin's implementation.
@JavaExport
public struct LifecycleObserverFactory: Sendable {
  private let makeObserver: @Sendable (String) -> any LifecycleObserver

  /// Gap: Kotlin implementations of a protocol need `enableJavaCallbacks`, and a closure can't return one yet.
  @JavaExport(false)
  public init(makeObserver: @escaping @Sendable (String) -> any LifecycleObserver) {
    self.makeObserver = makeObserver
  }

  /// Makes an observer for `id`, and disposes of it.
  public func observeOnce(id: String) {
    makeObserver(id).dispose()
  }
}
