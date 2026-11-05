import Foundation
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

// Combine on Apple platforms; elsewhere OpenCombine, which implements the same API.
#if canImport(Combine)
  import Combine
#else
  import OpenCombine
#endif

/// Shape: Combine state, observed from Swift; Java reads the current value.
@JavaExport
public final class DownloadProgress: @unchecked Sendable {
  private let subject = CurrentValueSubject<Double, Never>(0)

  public init() {}

  @JavaExport(false)
  public var publisher: AnyPublisher<Double, Never> {
    subject.eraseToAnyPublisher()
  }

  public var current: Double { subject.value }

  public func advance(by amount: Double) {
    subject.send(min(1, subject.value + amount))
  }

  /// Shape: an `AsyncStream` of values, which finishes when the download completes.
  public func updates() -> AsyncStream<Double> {
    AsyncStream { continuation in
      nonisolated(unsafe) let subscription = subject.sink { value in
        continuation.yield(value)
        if value >= 1 {
          continuation.finish()
        }
      }
      continuation.onTermination = { _ in subscription.cancel() }
    }
  }

  /// How many times `waitUntilComplete()` was cancelled.
  public private(set) var cancellations: Int64 = 0

  /// Shape: a long-running `async` function that stops when its task is cancelled.
  public func waitUntilComplete() async throws {
    do {
      while current < 1 {
        try await Task.sleep(nanoseconds: 10_000_000)
      }
    } catch {
      cancellations += 1
      throw error
    }
  }
}
