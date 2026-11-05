import Foundation
import Testing

import ShapesUtil

struct UtilTests {
  @Test func formatting() {
    #expect(Formatting.defaultPrecision == 2)
    #expect(Formatting.percent(0.5) == "50%")
    #expect(Formatting.percent(0.1234, precision: 1) == "12.3%")
    #expect(Formatting.dateFormatter().dateStyle == .medium)
  }

  @Test func autoclosureIsEvaluatedOnlyWhenNeeded() {
    var evaluations = 0
    func value() -> String {
      evaluations += 1
      return "shown"
    }
    #expect(Formatting.describe(value(), when: true) == "shown")
    #expect(Formatting.describe(value(), when: false) == "")
    #expect(evaluations == 1)
  }

  @Test func range() {
    let range = Range64(long: 10, short: 3)
    #expect(range.long == 10)
    #expect(range.short == 3)
    #expect(range.wait() == 7)
    #expect(range == Range64(long: 10, short: 3))
  }

  @Test func platform() {
    #if os(Android)
      #expect(Platform.name() == "android")
      #expect(Platform.androidOnly() == "android")
    #else
      #expect(Platform.name() == "apple")
    #endif
  }
}
