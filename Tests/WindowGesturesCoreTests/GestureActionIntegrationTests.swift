import XCTest
@testable import WindowGesturesCore

final class GestureActionIntegrationTests: XCTestCase {
    func testGestureActionUsesSameCommandPathAsHotKeyAction() {
        let recognizer = HorizontalSwipeRecognizer()
        let windows = MockGestureWindowController(
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(
            permissions: MockGesturePermissionChecker(hasAccessibilityPermission: true),
            windows: windows
        )

        let recognition = recognizer.recognize(
            SwipeGestureInput(deltaX: -1, deltaY: 0, timestamp: 1, source: .publicNSEventSwipe)
        )

        guard case .action(let action) = recognition else {
            return XCTFail("Expected gesture action")
        }

        XCTAssertEqual(handler.perform(action), .moved(Rect(x: 0, y: 0, width: 600, height: 800)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 0, y: 0, width: 600, height: 800)])
    }

    func testIgnoredGestureDoesNotMoveWindow() {
        let recognizer = HorizontalSwipeRecognizer()
        let windows = MockGestureWindowController(
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(
            permissions: MockGesturePermissionChecker(hasAccessibilityPermission: true),
            windows: windows
        )

        let recognition = recognizer.recognize(
            SwipeGestureInput(deltaX: 0.1, deltaY: 0, timestamp: 1, source: .publicNSEventSwipe)
        )

        if case .action(let action) = recognition {
            _ = handler.perform(action)
        }

        XCTAssertEqual(recognition, .ignored(.belowThreshold))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testDiagnosticNonSwipeEventDoesNotMoveWindow() {
        let diagnostics = GestureDiagnosticState()
        let recognizer = HorizontalSwipeRecognizer()
        let windows = MockGestureWindowController(
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(
            permissions: MockGesturePermissionChecker(hasAccessibilityPermission: true),
            windows: windows
        )
        let event = PublicGestureEventInput(
            type: .scrollWheel,
            timestamp: 1,
            deltaX: 10,
            deltaY: 0,
            phase: "changed"
        )

        diagnostics.record(event)
        if let recognition = recognizer.recognize(publicEvent: event),
           case .action(let action) = recognition {
            _ = handler.perform(action)
        }

        XCTAssertEqual(diagnostics.snapshot.counters.scrollWheel, 1)
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testRawGestureActionUsesSameCommandPathAsHotKeyAction() {
        let recognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35
        )
        let windows = MockGestureWindowController(
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(
            permissions: MockGesturePermissionChecker(hasAccessibilityPermission: true),
            windows: windows
        )

        _ = recognizer.recognize(RawTouchSample(activeTouchCount: 3, centroidX: 100, centroidY: 100, timestamp: 1))
        let recognition = recognizer.recognize(
            RawTouchSample(activeTouchCount: 3, centroidX: 70, centroidY: 100, timestamp: 1.1)
        )

        guard case .action(let action) = recognition else {
            return XCTFail("Expected raw gesture action")
        }

        XCTAssertEqual(handler.perform(action), .moved(Rect(x: 0, y: 0, width: 600, height: 800)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 0, y: 0, width: 600, height: 800)])
    }

    func testRawUpGestureUsesSameCommandPathAsSingleUpHotKeyAction() {
        let recognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35
        )
        let windows = MockGestureWindowController(
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(
            permissions: MockGesturePermissionChecker(hasAccessibilityPermission: true),
            windows: windows
        )

        _ = recognizer.recognize(RawTouchSample(activeTouchCount: 3, centroidX: 100, centroidY: 100, timestamp: 1))
        let recognition = recognizer.recognize(
            RawTouchSample(activeTouchCount: 3, centroidX: 100, centroidY: 130, timestamp: 1.1)
        )

        guard case .action(let action) = recognition else {
            return XCTFail("Expected raw up gesture action")
        }

        XCTAssertEqual(action, .maximize)
        XCTAssertEqual(handler.perform(action), .moved(Rect(x: 0, y: 0, width: 1200, height: 800)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 0, y: 0, width: 1200, height: 800)])
    }

    func testIgnoredRawGestureDoesNotMoveWindow() {
        let recognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35
        )
        let windows = MockGestureWindowController(
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(
            permissions: MockGesturePermissionChecker(hasAccessibilityPermission: true),
            windows: windows
        )

        let recognition = recognizer.recognize(
            RawTouchSample(activeTouchCount: 2, centroidX: 100, centroidY: 100, timestamp: 1)
        )
        if case .action(let action) = recognition {
            _ = handler.perform(action)
        }

        XCTAssertEqual(recognition, .ignored(.unsupportedFingerCount))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testRawBackendUnavailableDoesNotCrashStartupPath() {
        let backend = MockUnavailableGestureMonitor()

        XCTAssertNoThrow(backend.start())
        XCTAssertFalse(backend.isActive)
    }
}

private struct MockGesturePermissionChecker: PermissionChecking {
    var hasAccessibilityPermission: Bool

    func openAccessibilitySettings() {}
}

private final class MockUnavailableGestureMonitor: GestureMonitoring {
    private(set) var isActive = false

    func start() {}
    func stop() {}
}

private final class MockGestureWindowController: WindowControlling {
    typealias Window = String

    private(set) var currentFrame: Rect
    let visibleFrame: Rect
    private(set) var movedFrames: [Rect] = []

    init(currentFrame: Rect, visibleFrame: Rect) {
        self.currentFrame = currentFrame
        self.visibleFrame = visibleFrame
    }

    func focusedWindow() throws -> String {
        "window-1"
    }

    func frame(for window: String) throws -> Rect {
        currentFrame
    }

    func visibleScreenFrame(for window: String) throws -> Rect {
        visibleFrame
    }

    func move(_ window: String, to frame: Rect) throws {
        movedFrames.append(frame)
        currentFrame = frame
    }

    func restoreIdentifier(for window: String) -> String? {
        window
    }
}
