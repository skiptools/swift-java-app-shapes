import Foundation
import ShapesModels
import SwiftJavaAnnotations

/// Shape: a protocol Kotlin implements whose requirements return optionals, and an `async` one taking an
/// optional, which Kotlin implements as a suspend-friendly `CompletableFuture`.
@JavaExport
public protocol DeviceClient: Sendable {
  func deviceId() -> String?
  func lastSeen() -> Int64?
  func lastBook() -> Book?
  func verify(code: String?) async throws -> Bool
}

/// Calls the device client Kotlin implements.
@JavaExport
public final class DeviceSession: Sendable {
  private let client: any DeviceClient

  public init(client: any DeviceClient) {
    self.client = client
  }

  public func describe() -> String {
    let seen = client.lastSeen().map(String.init) ?? "never"
    return "\(client.deviceId() ?? "none") \(seen) \(client.lastBook()?.title ?? "no book")"
  }

  public func verify(code: String?) async throws -> Bool {
    try await client.verify(code: code)
  }
}
