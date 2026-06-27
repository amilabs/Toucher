import XCTest
@testable import WindowGesturesCore

final class HotKeySequenceRecognizerTests: XCTestCase {
    func testFirstControlShiftUpReturnsMaximize() {
        let recognizer = HotKeySequenceRecognizer()

        let result = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.0)

        XCTAssertEqual(result, .maximize)
    }

    func testSecondControlShiftUpWithinIntervalReturnsVerticalMaxCenterThird() {
        let recognizer = HotKeySequenceRecognizer()

        _ = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.0)
        let result = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.4)

        XCTAssertEqual(result, .verticalMaxCenterThird)
    }

    func testSecondControlShiftUpAfterIntervalReturnsMaximize() {
        let recognizer = HotKeySequenceRecognizer()

        _ = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.0)
        let result = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.401)

        XCTAssertEqual(result, .maximize)
    }

    func testUnrelatedHotKeyResetsDoubleUpDetection() {
        let recognizer = HotKeySequenceRecognizer()

        _ = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.0)
        XCTAssertEqual(recognizer.action(for: HotKeyMapping.leftHalfHotKey, at: 1.1), .leftHalf)
        let result = recognizer.action(for: HotKeyMapping.doubleUpHotKey, at: 1.2)

        XCTAssertEqual(result, .maximize)
    }
}
