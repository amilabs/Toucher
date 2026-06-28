import Foundation

public enum WindowMovementError: Error, Equatable, Sendable {
    case accessibilityPermissionMissing
    case noFocusedApplication
    case noFocusedWindow
    case unsupportedWindow
    case failedToReadWindowFrame
    case failedToSetWindowFrame
    case noStoredFrame
}

public enum WindowCommandResult: Equatable, Sendable {
    case moved(Rect)
    case failed(WindowMovementError)
}

public final class WindowCommandHandler<Permissions: PermissionChecking, Controller: WindowControlling> {
    private let permissions: Permissions
    private let windows: Controller
    private var restoreFrames: [String: Rect] = [:]

    public init(permissions: Permissions, windows: Controller) {
        self.permissions = permissions
        self.windows = windows
    }

    public func perform(_ action: WindowAction, options: WindowCommandOptions = WindowCommandOptions()) -> WindowCommandResult {
        guard permissions.hasAccessibilityPermission else {
            return .failed(.accessibilityPermissionMissing)
        }

        do {
            let window = try windows.focusedWindow()
            let restoreIdentifier = windows.restoreIdentifier(for: window)

            if action == .restore {
                guard let restoreIdentifier,
                      let restoreFrame = restoreFrames[restoreIdentifier] else {
                    return .failed(.noStoredFrame)
                }

            try move(window, to: restoreFrame, options: options)
            restoreFrames.removeValue(forKey: restoreIdentifier)
            return .moved(restoreFrame)
            }

            if let restoreIdentifier, restoreFrames[restoreIdentifier] == nil {
                restoreFrames[restoreIdentifier] = try windows.frame(for: window)
            }

            let windowFrame = try windows.frame(for: window)
            let visibleScreenFrame = try targetVisibleScreenFrame(
                for: window,
                windowFrame: windowFrame,
                screenTarget: options.screenTarget
            )
            let targetFrame = WindowFrameCalculator.frame(for: action, in: visibleScreenFrame)
            try move(window, to: targetFrame, options: options)
            return .moved(targetFrame)
        } catch let error as WindowMovementError {
            return .failed(error)
        } catch {
            return .failed(.failedToSetWindowFrame)
        }
    }

    private func targetVisibleScreenFrame(
        for window: Controller.Window,
        windowFrame: Rect,
        screenTarget: WindowScreenTarget
    ) throws -> Rect {
        let screens = try windows.screens()
        if let selectedFrame = ScreenSelector.targetVisibleFrame(
            for: windowFrame,
            screens: screens,
            target: screenTarget
        ) {
            return selectedFrame
        }

        return try windows.visibleScreenFrame(for: window)
    }

    private func move(
        _ window: Controller.Window,
        to frame: Rect,
        options: WindowCommandOptions
    ) throws {
        switch options.movementMode {
        case .immediate:
            try windows.move(window, to: frame)
        case .animated(let duration):
            guard duration > 0 else {
                try windows.move(window, to: frame)
                return
            }

            try windows.animatedMove(window, to: frame, duration: duration)
            return
        }
    }
}
