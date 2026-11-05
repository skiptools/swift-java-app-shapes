import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: a payloadless enum, a Java enum.
@JavaExport
public enum Genre: String, Codable, CaseIterable, Sendable {
  case fiction
  case history
  case science
}

/// Shape: an app scheme, returned by closures in another module.
@JavaExport
public enum Scheme: String, Sendable {
  case debug
  case release
}
