import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: an enum with payloads, one of which carries the error that caused it.
@JavaExport
public enum LibraryError: Error, Sendable {
  case notFound(id: String)
  case failed(underlying: any Error)
  case offline
}
