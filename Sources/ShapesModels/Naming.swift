import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: accessors with clashing Java names.
@JavaExport
public struct Availability: Sendable {
  /// `isLive()`, as is `isLive` below.
  public let live: Bool
  public var isLive: Bool { live }
  public var title: String
  /// `getTitle()`, as is the instance property.
  public static var title: String { "Availability" }

  public init(live: Bool, title: String) {
    self.live = live
    self.title = title
  }
}

/// Shape: a default-argument overload that would be ambiguous: `init()` also matches the internal one.
@JavaExport
public struct Quantity: Sendable {
  public let value: Double

  init(units: Int64 = 0) {
    value = Double(units)
  }

  public init(amount: Double = 0) {
    value = amount
  }
}

/// Shape: a parameter named like the thunk's own locals.
@JavaExport
public struct Review: Sendable {
  public let summary: String

  public init(result: Rating?, comment: String) {
    summary = "\(result?.stars ?? 0): \(comment)"
  }
}

@JavaExport
public struct Rating: Sendable {
  public let stars: Int64

  public init(stars: Int64) {
    self.stars = stars
  }
}
