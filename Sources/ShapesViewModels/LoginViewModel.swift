import Foundation
import Observation
import ShapesClients
import ShapesDependencies
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

@JavaExport
@MainActor
@Observable
public final class LoginViewModel {
  /// Shape: callbacks typed with another module's `@MainActor` typealias, with defaults.
  @JavaExport
  public struct Callbacks: @unchecked Sendable {
    @JavaExport(false)
    public let didLogin: VoidCallback
    @JavaExport(false)
    public let didCancel: VoidCallback

    public init(didLogin: @escaping VoidCallback = {}, didCancel: @escaping VoidCallback = {}) {
      self.didLogin = didLogin
      self.didCancel = didCancel
    }
  }

  @ObservationIgnored private let callbacks: Callbacks
  public private(set) var email = ""

  public init(callbacks: Callbacks) {
    self.callbacks = callbacks
  }

  public func submit(email: String) {
    self.email = email
    email.isEmpty ? callbacks.didCancel() : callbacks.didLogin()
  }
}
