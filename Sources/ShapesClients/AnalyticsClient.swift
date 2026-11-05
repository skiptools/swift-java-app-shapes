import Foundation
import SwiftJavaAnnotations

/// Shape: a protocol Kotlin implements whose requirements take dictionaries of `Any`, which Kotlin sees as
/// `Map<String, Any>` and `Map<Any, Any>`.
@JavaExport
public protocol AnalyticsClient: Sendable {
  func track(event: String, properties: [String: Any])
  func handlePush(_ userInfo: [AnyHashable: Any]) -> Bool
}

/// Shape: an optional dictionary of optional `Any` values, which Kotlin builds and reads as `Map<String, Any?>?`.
@JavaExport
public struct AnalyticsInput: @unchecked Sendable {
  public var id: String
  public var properties: [String: Any?]?

  public init(id: String, properties: [String: Any?]? = nil) {
    self.id = id
    self.properties = properties
  }
}

/// Calls the analytics client Kotlin implements.
@JavaExport
public final class AnalyticsRecorder: @unchecked Sendable {
  private let client: any AnalyticsClient
  private var counts: [String: Int64] = [:]

  public init(client: any AnalyticsClient) {
    self.client = client
  }

  /// Tracks the input's event with its non-`nil` properties.
  public func record(_ input: AnalyticsInput) {
    counts[input.id, default: 0] += 1
    client.track(event: input.id, properties: (input.properties ?? [:]).compactMapValues { $0 })
  }

  public func receivePush(_ userInfo: [AnyHashable: Any]) -> Bool {
    client.handlePush(userInfo)
  }

  /// Shape: a dictionary result, a Kotlin `Map<String, Long>`.
  public func eventCounts() -> [String: Int64] {
    counts
  }
}
