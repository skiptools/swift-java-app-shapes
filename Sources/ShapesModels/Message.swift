import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a case named like the payload type of another case (`string(String)` makes a `Case.String`).
@JavaExport
public enum Message: Sendable {
  case string(String)
  case closed(code: Int64, reason: String?)
  /// Shape: an optional dictionary payload, a Kotlin `Map<String, String>?`.
  case event(name: String, metadata: [String: String]?)

  /// Shape: no type annotation, an enum case with a payload.
  public static let goodbye = Message.closed(code: 1000, reason: "bye")
}
