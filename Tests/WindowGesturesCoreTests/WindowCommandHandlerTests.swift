import XCTest
@testable import WindowGesturesCore

final class WindowCommandHandlerTests: XCTestCase {
    func testPermissionDeniedPathDoesNotMoveWindow() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: false)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.leftHalf)

        XCTAssertEqual(result, .failed(.accessibilityPermissionMissing))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testNoActionIsExecutedIfNoFocusedApplicationExists() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .failure(.noFocusedApplication),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .failed(.noFocusedApplication))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testNoActionIsExecutedIfNoFocusedWindowExists() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .failure(.noFocusedWindow),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .failed(.noFocusedWindow))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testFailedToReadWindowFrameDoesNotMoveWindow() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            visibleFrameError: .failedToReadWindowFrame
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.leftHalf)

        XCTAssertEqual(result, .failed(.failedToReadWindowFrame))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testUnsupportedWindowDoesNotCrash() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600),
            moveError: .unsupportedWindow
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.leftHalf)

        XCTAssertEqual(result, .failed(.unsupportedWindow))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testFailedToSetWindowFrameDoesNotCrash() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600),
            moveError: .failedToSetWindowFrame
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .failed(.failedToSetWindowFrame))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testMovesActiveWindowToCalculatedFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
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

    let focusedWindowResult: Result<String, WindowMovementError>
    let visibleFrame: Rect?
    let visibleFrameError: WindowMovementError?
    let moveError: WindowMovementError?
    private(set) var movedFrames: [Rect] = []

    init(
        focusedWindowResult: Result<String, WindowMovementError>,
        visibleFrame: Rect? = nil,
        visibleFrameError: WindowMovementError? = nil,
        moveError: WindowMovementError? = nil
    ) {
        self.focusedWindowResult = focusedWindowResult
        self.visibleFrame = visibleFrame
        self.visibleFrameError = visibleFrameError
        self.moveError = moveError
    }

    func focusedWindow() throws -> String {
        try focusedWindowResult.get()
    }

    func visibleScreenFrame(for window: String) throws -> Rect {
        if let visibleFrameError {
            throw visibleFrameError
        }

        guard let visibleFrame else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        return visibleFrame
    }

    func move(_ window: String, to frame: Rect) throws {
        if let moveError {
            throw moveError
        }

        movedFrames.append(frame)
    }
}
