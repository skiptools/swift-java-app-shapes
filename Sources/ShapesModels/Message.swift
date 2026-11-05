import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a case named like the payload type of another case (`string(String)` makes a `Case.String`).
@JavaExport
public enum Message: Sendable {
  case string(String)
  case closed(code: Int64, reason: String?)
}
