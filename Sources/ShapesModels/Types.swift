import Foundation
import ShapesUtil
import SwiftJavaAnnotations

public typealias VoidCallback = @MainActor () -> Void

/// Shape: a type used only from Swift. Public, not exported.
public struct CacheEntry {
  public let key: String
}
