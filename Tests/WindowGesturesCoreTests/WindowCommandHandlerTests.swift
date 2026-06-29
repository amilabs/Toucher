import XCTest
@testable import WindowGesturesCore

final class WindowCommandHandlerTests: XCTestCase {
    func testPermissionDeniedPathDoesNotMoveWindow() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: false)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.leftHalf)

        XCTAssertEqual(result, .failed(.accessibilityPermissionMissing))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testActionPathRechecksAccessibilityPermissionEachTime() {
        let permissions = MutablePermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let firstResult = handler.perform(.leftHalf)
        permissions.hasAccessibilityPermission = false
        let secondResult = handler.perform(.rightHalf)

        XCTAssertEqual(firstResult, .moved(Rect(x: 0, y: 0, width: 500, height: 800)))
        XCTAssertEqual(secondResult, .failed(.accessibilityPermissionMissing))
        XCTAssertEqual(permissions.readCount, 2)
        XCTAssertEqual(windows.moveCallCount, 1)
    }

    func testNoActionIsExecutedIfNoFocusedApplicationExists() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .failure(.noFocusedApplication),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
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
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
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
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
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
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
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
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600),
            moveError: .failedToSetWindowFrame
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .failed(.failedToSetWindowFrame))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testAccessibilityLossDuringMoveReturnsPermissionMissing() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 800, height: 600),
            moveError: .accessibilityPermissionMissing
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .failed(.accessibilityPermissionMissing))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testMovesActiveWindowToCalculatedFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 25, width: 1000, height: 775)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf)

        XCTAssertEqual(result, .moved(Rect(x: 500, y: 25, width: 500, height: 775)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 500, y: 25, width: 500, height: 775)])
    }

    func testVerticalMaxCenterThirdMovesActiveWindowToCalculatedFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 25, width: 1200, height: 775)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.verticalMaxCenterThird)

        XCTAssertEqual(result, .moved(Rect(x: 400, y: 25, width: 400, height: 775)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 400, y: 25, width: 400, height: 775)])
    }

    func testMaximizeMovesActiveWindowToVisibleFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 25, width: 1200, height: 775)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.maximize)

        XCTAssertEqual(result, .moved(Rect(x: 0, y: 25, width: 1200, height: 775)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 0, y: 25, width: 1200, height: 775)])
    }

    func testRestoreWithoutStoredFrameDoesNothingGracefully() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 0, width: 500, height: 800),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.restore)

        XCTAssertEqual(result, .failed(.noStoredFrame))
        XCTAssertTrue(windows.movedFrames.isEmpty)
    }

    func testRestoreReturnsWindowToPreviousFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(.leftHalf)
        let result = handler.perform(.restore)

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames, [
            Rect(x: 0, y: 0, width: 500, height: 800),
            originalFrame
        ])
    }

    func testRestoreAfterMaximizeReturnsWindowToOriginalFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(.maximize)
        let result = handler.perform(.restore)

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames, [
            Rect(x: 0, y: 0, width: 1000, height: 800),
            originalFrame
        ])
    }

    func testRestoreAfterDoubleUpSequenceReturnsWindowToOriginalFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(.maximize)
        _ = handler.perform(.verticalMaxCenterThird)
        let result = handler.perform(.restore)

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames, [
            Rect(x: 0, y: 0, width: 1200, height: 800),
            Rect(x: 400, y: 0, width: 400, height: 800),
            originalFrame
        ])
    }

    func testRepeatedSnapsDoNotOverwriteOriginalRestoreFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(.leftHalf)
        _ = handler.perform(.rightHalf)
        _ = handler.perform(.maximize)
        _ = handler.perform(.verticalMaxCenterThird)
        let result = handler.perform(.restore)

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames, [
            Rect(x: 0, y: 0, width: 600, height: 800),
            Rect(x: 600, y: 0, width: 600, height: 800),
            Rect(x: 0, y: 0, width: 1200, height: 800),
            Rect(x: 400, y: 0, width: 400, height: 800),
            originalFrame
        ])
    }

    func testWithoutCommandUsesCurrentScreen() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let screens = [
            ScreenFrame(frame: Rect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 780)),
            ScreenFrame(frame: Rect(x: 1000, y: 0, width: 1200, height: 900), visibleFrame: Rect(x: 1000, y: 20, width: 1200, height: 880))
        ]
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 1100, y: 100, width: 500, height: 400),
            visibleFrame: screens[1].visibleFrame,
            screens: screens
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.leftHalf)

        XCTAssertEqual(result, .moved(Rect(x: 1000, y: 20, width: 600, height: 880)))
    }

    func testWithCommandAndTwoScreensUsesOtherScreen() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let screens = [
            ScreenFrame(frame: Rect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 780)),
            ScreenFrame(frame: Rect(x: 1000, y: 0, width: 1200, height: 900), visibleFrame: Rect(x: 1000, y: 20, width: 1200, height: 880))
        ]
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 1100, y: 100, width: 500, height: 400),
            visibleFrame: screens[1].visibleFrame,
            screens: screens
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(.rightHalf, options: WindowCommandOptions(screenTarget: .next))

        XCTAssertEqual(result, .moved(Rect(x: 500, y: 0, width: 500, height: 780)))
    }

    func testImmediateSetFramePathCallsMoveOnce() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 0, width: 500, height: 800),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(
            .leftHalf,
            options: WindowCommandOptions(animateWindowMovement: false, animationDuration: 0.25, animationSteps: 5)
        )

        XCTAssertEqual(result, .moved(Rect(x: 0, y: 0, width: 500, height: 800)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 0, y: 0, width: 500, height: 800)])
        XCTAssertEqual(windows.moveCallCount, 1)
    }

    func testAnimationSettingTrueUsesDiscreteMovementFrames() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(
            .rightHalf,
            options: WindowCommandOptions(animateWindowMovement: true, animationDuration: 0.25, animationSteps: 5)
        )

        XCTAssertEqual(result, .moved(Rect(x: 500, y: 0, width: 500, height: 800)))
        XCTAssertEqual(windows.movedFrames.count, 5)
        XCTAssertEqual(windows.movedFrames.last, Rect(x: 500, y: 0, width: 500, height: 800))
        XCTAssertEqual(windows.moveCallCount, 5)
    }

    func testAnimationSettingsAllowThirtyTwoStepsAndMinimumDuration() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 0, width: 500, height: 800),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(
            .rightHalf,
            options: WindowCommandOptions(animateWindowMovement: true, animationDuration: 0.02, animationSteps: 32)
        )

        XCTAssertEqual(result, .moved(Rect(x: 500, y: 0, width: 500, height: 800)))
        XCTAssertEqual(windows.movedFrames.count, 32)
        XCTAssertNotEqual(windows.movedFrames.first, Rect(x: 500, y: 0, width: 500, height: 800))
        XCTAssertEqual(windows.movedFrames.last, Rect(x: 500, y: 0, width: 500, height: 800))
        XCTAssertEqual(windows.moveCallCount, 32)
    }

    func testExplicitImmediateMovementModeUsesImmediateSetFramePath() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(
            .maximize,
            options: WindowCommandOptions(movementMode: .immediate)
        )

        XCTAssertEqual(result, .moved(Rect(x: 0, y: 0, width: 1000, height: 800)))
        XCTAssertEqual(windows.movedFrames, [Rect(x: 0, y: 0, width: 1000, height: 800)])
        XCTAssertEqual(windows.moveCallCount, 1)
    }

    func testDiscreteMovementModePlansFourFramesIncludingFinalTarget() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        let result = handler.perform(
            .leftHalf,
            options: WindowCommandOptions(movementMode: .discreteSteps(totalStepCount: 4, totalDuration: 0.24))
        )

        let target = Rect(x: 0, y: 0, width: 500, height: 800)
        XCTAssertEqual(result, .moved(target))
        XCTAssertEqual(windows.moveCallCount, 4)
        XCTAssertEqual(windows.movedFrames.count, 4)
        XCTAssertNotEqual(windows.movedFrames[0], target)
        XCTAssertEqual(windows.movedFrames[3], target)
    }

    func testDiscreteMovementModeUsesLinearInterpolation() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: Rect(x: 100, y: 100, width: 500, height: 400),
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(
            .leftHalf,
            options: WindowCommandOptions(movementMode: .discreteSteps(totalStepCount: 4, totalDuration: 0.24))
        )

        XCTAssertEqual(windows.movedFrames, [
            Rect(x: 75, y: 75, width: 500, height: 500),
            Rect(x: 50, y: 50, width: 500, height: 600),
            Rect(x: 25, y: 25, width: 500, height: 700),
            Rect(x: 0, y: 0, width: 500, height: 800)
        ])
    }

    func testDiscreteMovementDoesNotOverwriteRestoreFrameWithIntermediateFrames() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1000, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(
            .leftHalf,
            options: WindowCommandOptions(movementMode: .discreteSteps(totalStepCount: 4, totalDuration: 0.24))
        )
        let result = handler.perform(
            .restore,
            options: WindowCommandOptions(movementMode: .discreteSteps(totalStepCount: 4, totalDuration: 0.24))
        )

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames.last, originalFrame)
    }

    func testRestoreAfterAnimationSettingReturnsWindowToOriginalFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(
            .verticalMaxCenterThird,
            options: WindowCommandOptions(animateWindowMovement: true, animationDuration: 0.25, animationSteps: 5)
        )
        let result = handler.perform(.restore, options: WindowCommandOptions(animateWindowMovement: true, animationDuration: 0.25, animationSteps: 5))

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames.last, originalFrame)
    }

    func testAnimationSettingDoesNotOverwriteRestoreFrame() {
        let permissions = MockPermissionChecker(hasAccessibilityPermission: true)
        let originalFrame = Rect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockWindowController(
            focusedWindowResult: .success("window-1"),
            currentFrame: originalFrame,
            visibleFrame: Rect(x: 0, y: 0, width: 1200, height: 800)
        )
        let handler = WindowCommandHandler(permissions: permissions, windows: windows)

        _ = handler.perform(.leftHalf, options: WindowCommandOptions(animateWindowMovement: true, animationDuration: 0.25, animationSteps: 5))
        _ = handler.perform(.rightHalf, options: WindowCommandOptions(animateWindowMovement: true, animationDuration: 0.25, animationSteps: 5))
        let result = handler.perform(.restore)

        XCTAssertEqual(result, .moved(originalFrame))
        XCTAssertEqual(windows.movedFrames.last, originalFrame)
    }
}

private struct MockPermissionChecker: PermissionChecking {
    var hasAccessibilityPermission: Bool

    func openAccessibilitySettings() {}
}

private final class MutablePermissionChecker: PermissionChecking {
    var trusted: Bool
    private(set) var readCount = 0

    init(hasAccessibilityPermission: Bool) {
        self.trusted = hasAccessibilityPermission
    }

    var hasAccessibilityPermission: Bool {
        get {
            readCount += 1
            return trusted
        }
        set {
            trusted = newValue
        }
    }

    func openAccessibilitySettings() {}
}

private final class MockWindowController: WindowControlling {
    typealias Window = String

    let focusedWindowResult: Result<String, WindowMovementError>
    private(set) var currentFrame: Rect
    let visibleFrame: Rect?
    let screenFrames: [ScreenFrame]
    let visibleFrameError: WindowMovementError?
    let moveError: WindowMovementError?
    private(set) var movedFrames: [Rect] = []
    private(set) var moveCallCount = 0

    init(
        focusedWindowResult: Result<String, WindowMovementError>,
        currentFrame: Rect,
        visibleFrame: Rect? = nil,
        screens: [ScreenFrame] = [],
        visibleFrameError: WindowMovementError? = nil,
        moveError: WindowMovementError? = nil
    ) {
        self.focusedWindowResult = focusedWindowResult
        self.currentFrame = currentFrame
        self.visibleFrame = visibleFrame
        self.screenFrames = screens
        self.visibleFrameError = visibleFrameError
        self.moveError = moveError
    }

    func focusedWindow() throws -> String {
        try focusedWindowResult.get()
    }

    func frame(for window: String) throws -> Rect {
        currentFrame
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

    func screens() throws -> [ScreenFrame] {
        screenFrames
    }

    func move(_ window: String, to frame: Rect) throws {
        if let moveError {
            throw moveError
        }

        moveCallCount += 1
        movedFrames.append(frame)
        currentFrame = frame
    }

    func restoreIdentifier(for window: String) -> String? {
        window
    }
}
