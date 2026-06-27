import XCTest
@testable import WindowGesturesCore

final class HotKeyMappingTests: XCTestCase {
    func testControlShiftLeftMapsToLeftHalf() {
        let hotKey = HotKey(key: .leftArrow, modifiers: [.control, .shift])

        XCTAssertEqual(HotKeyMapping.action(for: hotKey), .leftHalf)
    }

    func testControlShiftRightMapsToRightHalf() {
        let hotKey = HotKey(key: .rightArrow, modifiers: [.control, .shift])

        XCTAssertEqual(HotKeyMapping.action(for: hotKey), .rightHalf)
    }

    func testControlShiftDownMapsToRestore() {
        let hotKey = HotKey(key: .downArrow, modifiers: [.control, .shift])

        XCTAssertEqual(HotKeyMapping.action(for: hotKey), .restore)
    }

    func testControlShiftUpMapsToMaximize() {
        let recognizer = HotKeySequenceRecognizer()
        let hotKey = HotKey(key: .upArrow, modifiers: [.control, .shift])

        XCTAssertEqual(recognizer.action(for: hotKey, at: 10.0), .maximize)
    }

    func testControlShiftDoubleUpMapsToVerticalMaxCenterThird() {
        let recognizer = HotKeySequenceRecognizer()
        let hotKey = HotKey(key: .upArrow, modifiers: [.control, .shift])

        XCTAssertEqual(recognizer.action(for: hotKey, at: 10.0), .maximize)
        XCTAssertEqual(recognizer.action(for: hotKey, at: 10.3), .verticalMaxCenterThird)
    }
}
