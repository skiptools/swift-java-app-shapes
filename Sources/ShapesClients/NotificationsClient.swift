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
    case .event(let name, let metadata):
      delivered.append("\(name) \((metadata ?? [:]).sorted { $0.key < $1.key }.map { "\($0)=\($1)" })")
    }
  }

  public func failAuth() {
    handlers.forEach { $0() }
  }

  public var deliveredCount: Int64 { Int64(delivered.count) }
}

/// Hands the notifications client Kotlin implements a Swift closure, which Kotlin calls back.
@JavaExport
public final class AuthMonitor: @unchecked Sendable {
  public private(set) var failures: Int64 = 0

  public init(notifications: any NotificationsClient) {
    notifications.onAuthError { [weak self] in self?.failures += 1 }
  }
}
