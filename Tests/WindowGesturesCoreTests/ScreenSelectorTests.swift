import XCTest
@testable import WindowGesturesCore

final class ScreenSelectorTests: XCTestCase {
    private let main = ScreenFrame(
        frame: Rect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: Rect(x: 0, y: 25, width: 1440, height: 875)
    )
    private let secondary = ScreenFrame(
        frame: Rect(x: 1440, y: 0, width: 1200, height: 800),
        visibleFrame: Rect(x: 1440, y: 0, width: 1200, height: 775)
    )
    private let third = ScreenFrame(
        frame: Rect(x: 2640, y: 0, width: 1000, height: 700),
        visibleFrame: Rect(x: 2640, y: 0, width: 1000, height: 675)
    )

    func testWindowCenteredOnSecondaryScreenUsesSecondaryVisibleFrame() {
        let window = Rect(x: 1600, y: 100, width: 400, height: 300)

        XCTAssertEqual(
            ScreenSelector.targetVisibleFrame(for: window, screens: [main, secondary], target: .current),
            secondary.visibleFrame
        )
    }

    func testPartiallyAcrossScreensUsesCenterRuleBeforeIntersection() {
        let window = Rect(x: 1300, y: 100, width: 400, height: 300)

        XCTAssertEqual(
            ScreenSelector.targetVisibleFrame(for: window, screens: [main, secondary], target: .current),
            secondary.visibleFrame
        )
    }

    func testPartiallyAcrossScreensFallsBackToLargestIntersectionWhenCenterOutsideScreens() {
        let window = Rect(x: 1000, y: 920, width: 500, height: 300)

        XCTAssertEqual(
            ScreenSelector.targetVisibleFrame(for: window, screens: [main, secondary], target: .current),
            main.visibleFrame
        )
    }

    func testNextScreenWithTwoScreensUsesOtherScreen() {
        let window = Rect(x: 100, y: 100, width: 400, height: 300)

        XCTAssertEqual(
            ScreenSelector.targetVisibleFrame(for: window, screens: [main, secondary], target: .next),
            secondary.visibleFrame
        )
    }

    func testNextScreenWithOneScreenStaysCurrent() {
        let window = Rect(x: 100, y: 100, width: 400, height: 300)

        XCTAssertEqual(
            ScreenSelector.targetVisibleFrame(for: window, screens: [main], target: .next),
            main.visibleFrame
        )
    }

    func testNextScreenWithThreeScreensUsesDeterministicOrder() {
        let window = Rect(x: 1500, y: 100, width: 400, height: 300)

        XCTAssertEqual(
            ScreenSelector.targetVisibleFrame(for: window, screens: [third, secondary, main], target: .next),
            third.visibleFrame
        )
    }
}
