import XCTest
@testable import WindowGesturesCore

final class AccessibilityCoordinateConverterTests: XCTestCase {
    func testSingleScreenTargetsStayInsideVisibleFrame() throws {
        let screen = ScreenFrame(
            frame: Rect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: Rect(x: 0, y: 25, width: 1440, height: 850)
        )

        try assertTargetsStayInsideVisibleFrame(on: screen, screens: [screen])
    }

    func testExternalDisplayRightUsesSelectedScreenCoordinates() throws {
        let main = ScreenFrame(
            frame: Rect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: Rect(x: 0, y: 25, width: 1440, height: 850)
        )
        let right = ScreenFrame(
            frame: Rect(x: 1440, y: 0, width: 2560, height: 1440),
            visibleFrame: Rect(x: 1440, y: 0, width: 2560, height: 1415)
        )

        let target = WindowFrameCalculator.frame(for: .leftHalf, in: right.visibleFrame)

        XCTAssertEqual(target.x, 1440)
        try assertRoundTrip(target, screens: [main, right])
        XCTAssertTrue(right.visibleFrame.contains(target))
    }

    func testExternalDisplayLeftKeepsNegativeX() throws {
        let main = ScreenFrame(
            frame: Rect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: Rect(x: 0, y: 25, width: 1440, height: 850)
        )
        let left = ScreenFrame(
            frame: Rect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: Rect(x: -1920, y: 0, width: 1920, height: 1055)
        )

        let target = WindowFrameCalculator.frame(for: .rightHalf, in: left.visibleFrame)

        XCTAssertLessThan(target.x, 0)
        try assertRoundTrip(target, screens: [left, main])
        XCTAssertTrue(left.visibleFrame.contains(target))
    }

    func testExternalDisplayAboveConvertsYCorrectly() throws {
        let main = ScreenFrame(
            frame: Rect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: Rect(x: 0, y: 25, width: 1440, height: 850)
        )
        let above = ScreenFrame(
            frame: Rect(x: 0, y: 900, width: 2560, height: 1440),
            visibleFrame: Rect(x: 0, y: 900, width: 2560, height: 1415)
        )

        let target = WindowFrameCalculator.frame(for: .maximize, in: above.visibleFrame)
        let axTarget = try converter(for: [main, above]).accessibilityRect(fromAppKitRect: target)

        XCTAssertEqual(axTarget.y, 25, accuracy: 0.001)
        try assertRoundTrip(target, screens: [main, above])
        XCTAssertTrue(above.visibleFrame.contains(target))
    }

    func testExternalDisplayBelowConvertsYCorrectly() throws {
        let main = ScreenFrame(
            frame: Rect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: Rect(x: 0, y: 25, width: 1440, height: 850)
        )
        let below = ScreenFrame(
            frame: Rect(x: 0, y: -1080, width: 1920, height: 1080),
            visibleFrame: Rect(x: 0, y: -1080, width: 1920, height: 1055)
        )

        let target = WindowFrameCalculator.frame(for: .maximize, in: below.visibleFrame)
        let axTarget = try converter(for: [below, main]).accessibilityRect(fromAppKitRect: target)

        XCTAssertEqual(axTarget.y, 925, accuracy: 0.001)
        try assertRoundTrip(target, screens: [below, main])
        XCTAssertTrue(below.visibleFrame.contains(target))
    }

    func testOffsetYRegressionFixtureDoesNotProduceVerticallyCenteredOffscreenTarget() throws {
        let main = ScreenFrame(
            frame: Rect(x: 0, y: -1117, width: 1728, height: 1117),
            visibleFrame: Rect(x: 0, y: -1079, width: 1728, height: 1041)
        )
        let target = WindowFrameCalculator.frame(for: .maximize, in: main.visibleFrame)
        let roundTripped = try roundTrip(target, screens: [main])

        XCTAssertEqual(roundTripped.y, main.visibleFrame.y, accuracy: 0.001)
        XCTAssertEqual(roundTripped.height, main.visibleFrame.height, accuracy: 0.001)
        XCTAssertTrue(main.visibleFrame.contains(roundTripped))
    }

    private func assertTargetsStayInsideVisibleFrame(on screen: ScreenFrame, screens: [ScreenFrame]) throws {
        for action in [WindowAction.leftHalf, .rightHalf, .maximize, .verticalMaxCenterThird] {
            let target = WindowFrameCalculator.frame(for: action, in: screen.visibleFrame)
            let roundTripped = try roundTrip(target, screens: screens)

            XCTAssertTrue(screen.visibleFrame.contains(roundTripped), "\(action) target should stay inside visible frame")
            if action == .maximize {
                XCTAssertEqual(roundTripped, screen.visibleFrame)
            }
        }
    }

    private func assertRoundTrip(_ rect: Rect, screens: [ScreenFrame]) throws {
        let roundTripped = try roundTrip(rect, screens: screens)

        XCTAssertEqual(roundTripped.x, rect.x, accuracy: 0.001)
        XCTAssertEqual(roundTripped.y, rect.y, accuracy: 0.001)
        XCTAssertEqual(roundTripped.width, rect.width, accuracy: 0.001)
        XCTAssertEqual(roundTripped.height, rect.height, accuracy: 0.001)
    }

    private func roundTrip(_ rect: Rect, screens: [ScreenFrame]) throws -> Rect {
        let converter = try converter(for: screens)
        let ax = converter.accessibilityRect(fromAppKitRect: rect)
        return converter.appKitRect(fromAccessibilityRect: ax)
    }

    private func converter(for screens: [ScreenFrame]) throws -> AccessibilityCoordinateConverter {
        guard let desktopUnion = ScreenGeometry.desktopUnion(for: screens) else {
            throw XCTSkip("missing desktop union")
        }

        return AccessibilityCoordinateConverter(desktopUnion: desktopUnion)
    }
}
