import XCTest
@testable import WindowGesturesCore

final class WindowFrameCalculatorTests: XCTestCase {
    func testLeftHalfFrameCalculation() {
        let visibleFrame = Rect(x: 10, y: 24, width: 1200, height: 776)

        let result = WindowFrameCalculator.frame(for: .leftHalf, in: visibleFrame)

        XCTAssertEqual(result, Rect(x: 10, y: 24, width: 600, height: 776))
    }

    func testRightHalfFrameCalculation() {
        let visibleFrame = Rect(x: 10, y: 24, width: 1200, height: 776)

        let result = WindowFrameCalculator.frame(for: .rightHalf, in: visibleFrame)

        XCTAssertEqual(result, Rect(x: 610, y: 24, width: 600, height: 776))
    }

    func testVisibleScreenFrameIsUsed() {
        let visibleFrame = Rect(x: 0, y: 48, width: 1440, height: 812)

        let result = WindowFrameCalculator.frame(for: .leftHalf, in: visibleFrame)

        XCTAssertEqual(result, Rect(x: 0, y: 48, width: 720, height: 812))
    }
}
