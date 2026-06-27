import XCTest
@testable import WindowGesturesCore

final class WindowCommandHandlerTests: XCTestCase {
    func testPermissionDeniedPathDoesNotMoveWindow() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: false)
        let windows = MockWindowController(
            activeWindowID: "window-1",
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.leftHalf)

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testNoActionIsExecutedIfNoActiveWindowExists() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            activeWindowID: nil,
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .noActiveWindow)
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testMovesActiveWindowToCalculatedFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            activeWindowID: "window-1",
            visibleFrame: Rect(x: 0, y: 25, width: 1000, height: 775)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .moved(Rect(x: 500, y: 25, width: 500, height: 775)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 500, y: 25, width: 500, height: 775)])
    }
}

private struct MockPermissionChecker: PermissionChecking {
    var hasAccessibilityPermission: Bool

    func openAccessibilitySettings() {}
}

private final class MockWindowController: WindowControlling {
    typealias Window = String

    let activeWindowID: String?
    let visibleFrame: Rect?
    private(set) var movedFrames: [Rect] = []

    init(activeWindowID: String?, visibleFrame: Rect?) {
        self.activeWindowID = activeWindowID
        self.visibleFrame = visibleFrame
    }

    func activeWindow() -> String? {
        activeWindowID
    }

    func visibleScreenFrame(for window: String) -> Rect? {
        visibleFrame
    }

    func move(_ window: String, to frame: Rect) throws {
        movedFrames.append(frame)
    }
}
