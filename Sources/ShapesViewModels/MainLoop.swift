import Foundation
import Observation
import ShapesClients
import ShapesDependencies
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

/// For the tests: runs the main run loop briefly, as Android's main looper would, so main-actor work
/// scheduled by async calls can run while the JVM main thread waits.
@JavaExport
public enum MainLoop {
  @MainActor
  public static func run(seconds: Double) {
    _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: seconds))
  }
}
