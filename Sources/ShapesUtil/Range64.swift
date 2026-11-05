import Foundation
import SwiftJavaAnnotations

/// Shape: an identifier helper whose parameters are Java keywords.
public struct Range64: Hashable, Sendable {
  public let long: Int64
  public let short: Int64

  public init(long: Int64, short: Int64) {
    self.long = long
    self.short = short
  }

  /// Shape: a method named like a final `java.lang.Object` method.
  public func wait() -> Int64 {
    long - short
  }
}
