import UIKit
import XCTest

class RunnerTests: XCTestCase {
  func testRunnerLoads() {
    XCTAssertFalse(UIDevice.current.systemVersion.isEmpty)
  }
}
