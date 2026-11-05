import Foundation
import SwiftJavaAnnotations

/// Shape: platform-specific API. Only Android builds have it.
public enum Platform {
  public static func name() -> String {
    #if os(Android)
      "android"
    #else
      "apple"
    #endif
  }

  #if os(Android)
    /// Gap: jextract extracts every `#if` branch unless given a static build configuration, and the
    /// thunks don't keep the condition, so a macOS build sees a thunk for Android-only API.
    @JavaExport(false)
    public static func androidOnly() -> String {
      "android"
    }
  #endif
}
