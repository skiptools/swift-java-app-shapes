import Foundation
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: an extension, in this module, of another module's type.
extension Book {
  @JavaExport
  public func shareText() -> String {
    "\(title) (\(pages) pages)"
  }
}
