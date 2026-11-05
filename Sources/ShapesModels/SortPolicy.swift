import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: an unlabeled closure payload.
/// Gap: closure payloads over jextracted types aren't supported yet, and a single case can't be left out.
@JavaExport(false)
public enum SortPolicy {
  case custom((Book, Book) -> Bool)
  case byTitle
}
