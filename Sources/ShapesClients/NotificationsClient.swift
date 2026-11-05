import Foundation
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a requirement taking a closure, so conformers must take the protocol's functional interface.
@JavaExport
public protocol NotificationsClient: Sendable {
  func onAuthError(_ handler: @escaping @Sendable () -> Void)
  func notify(_ message: Message)
}

@JavaExport
public final class NotificationsClientMock: NotificationsClient, @unchecked Sendable {
  private var handlers: [@Sendable () -> Void] = []
  public private(set) var delivered: [String] = []

  public init() {}

  public func onAuthError(_ handler: @escaping @Sendable () -> Void) {
    handlers.append(handler)
  }

  public func notify(_ message: Message) {
    switch message {
    case .string(let text): delivered.append(text)
    case .closed(let code, let reason): delivered.append("closed \(code) \(reason ?? "")")
    }
  }

  public func failAuth() {
    handlers.forEach { $0() }
  }

  public var deliveredCount: Int64 { Int64(delivered.count) }
}
