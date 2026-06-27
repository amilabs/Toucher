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
}
