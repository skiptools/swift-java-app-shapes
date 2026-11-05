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
}
