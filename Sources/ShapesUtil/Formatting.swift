import Foundation
import SwiftJavaAnnotations

public enum Formatting {
  /// Shape: no type annotation, inferred from the literal.
  public static let defaultPrecision = 2

  public static func percent(_ value: Double, precision: Int64 = 0) -> String {
    String(format: "%.\(precision)f%%", value * 100)
  }

  /// Shape: a Foundation formatter used from Swift only. Public, but not for Java.
  @JavaExport(false)
  public static func dateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
  }

  /// Shape: an `@autoclosure` argument, evaluated only when needed.
  public static func describe(_ value: @autoclosure () -> String, when condition: Bool) -> String {
    condition ? value() : ""
  }
}
