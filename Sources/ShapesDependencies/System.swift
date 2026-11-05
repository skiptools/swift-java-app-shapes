import Foundation
import ShapesClients
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: configuration read lazily through `@autoclosure` closures, one returning another module's enum.
public struct System: @unchecked Sendable {
  public let scheme: () -> Scheme
  public let appName: () -> String

  public init(
    scheme: @autoclosure @escaping () -> Scheme, appName: @autoclosure @escaping () -> String
  ) {
    self.scheme = scheme
    self.appName = appName
  }
}
