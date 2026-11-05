import Foundation
import ShapesUtil
import SwiftJavaAnnotations

/// Shape: overloads whose Java signatures differ but whose native ones don't (both take a pointer).
@JavaExport
public struct Cover: Sendable {
  public let summary: String

  public init(image: ImageCover) {
    summary = "image \(image.url.absoluteString)"
  }

  public init(text: TextCover) {
    summary = "text \(text.title)"
  }

  /// Shape: no type annotation, a property read off a new value.
  public static let placeholderTitle = TextCover(title: "Untitled").title
}

@JavaExport
public struct ImageCover: Sendable {
  public let url: URL

  public init(url: URL) {
    self.url = url
  }
}

@JavaExport
public struct TextCover: Sendable {
  public let title: String

  public init(title: String) {
    self.title = title
  }
}
