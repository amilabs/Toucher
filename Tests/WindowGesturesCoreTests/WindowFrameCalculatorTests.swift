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

    func testMaximizeReturnsFullVisibleScreenFrame() {
        let visibleFrame = Rect(x: 12, y: 48, width: 1440, height: 812)

        let result = WindowFrameCalculator.frame(for: .maximize, in: visibleFrame)

        XCTAssertEqual(result, visibleFrame)
    }

    func testVerticalMaxCenterThirdFrameCalculationFor1440By900() {
        let visibleFrame = Rect(x: 0, y: 0, width: 1440, height: 900)

        let result = WindowFrameCalculator.frame(for: .verticalMaxCenterThird, in: visibleFrame)

        XCTAssertEqual(result, Rect(x: 480, y: 0, width: 480, height: 900))
    }

    func testVerticalMaxCenterThirdFrameCalculationFor2560By1440() {
        let visibleFrame = Rect(x: 0, y: 0, width: 2560, height: 1440)

        let result = WindowFrameCalculator.frame(for: .verticalMaxCenterThird, in: visibleFrame)

        assertRectEqual(
            result,
            Rect(x: 853.3333333333334, y: 0, width: 853.3333333333334, height: 1440)
        )
    }

    func testVerticalMaxCenterThirdUsesNonZeroVisibleFrameOrigin() {
        let visibleFrame = Rect(x: 100, y: 24, width: 1200, height: 776)

        let result = WindowFrameCalculator.frame(for: .verticalMaxCenterThird, in: visibleFrame)

        XCTAssertEqual(result, Rect(x: 500, y: 24, width: 400, height: 776))
    }

    func testVerticalMaxCenterThirdOddWidthIsDeterministic() {
        let visibleFrame = Rect(x: 0, y: 0, width: 1001, height: 700)

        let result = WindowFrameCalculator.frame(for: .verticalMaxCenterThird, in: visibleFrame)

        assertRectEqual(
            result,
            Rect(x: 333.66666666666663, y: 0, width: 333.6666666666667, height: 700)
        )
    }

    private func assertRectEqual(_ lhs: Rect, _ rhs: Rect, accuracy: Double = 0.000001) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: accuracy)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: accuracy)
        XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy)
        XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy)
    }
}
