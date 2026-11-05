import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a case with an unlabeled closure payload. Java creates the cases, tells them apart, and calls the
/// enum's methods; it doesn't read the closure back.
@JavaExport
public enum SortPolicy {
  case custom((Book, Book) -> Bool)
  case byTitle

  public func areInIncreasingOrder(_ lhs: Book, _ rhs: Book) -> Bool {
    switch self {
    case .custom(let areInIncreasingOrder): areInIncreasingOrder(lhs, rhs)
    case .byTitle: lhs.title < rhs.title
    }
  }
}
