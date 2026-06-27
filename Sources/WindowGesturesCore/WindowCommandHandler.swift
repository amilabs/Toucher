import Foundation

public enum WindowMovementError: Error, Equatable, Sendable {
    case accessibilityPermissionMissing
    case noFocusedApplication
    case noFocusedWindow
    case unsupportedWindow
    case failedToReadWindowFrame
    case failedToSetWindowFrame
}

public enum WindowCommandResult: Equatable, Sendable {
    case moved(Rect)
    case failed(WindowMovementError)
}

public final class WindowCommandHandler<Permissions: PermissionChecking, Controller: WindowControlling> {
    private let permissions: Permissions
    private let windows: Controller

    public init(permissions: Permissions, windows: Controller) {
        self.permissions = permissions
        self.windows = windows
    }

    public func perform(_ action: WindowAction) -> WindowCommandResult {
        guard permissions.hasAccessibilityPermission else {
            return .failed(.accessibilityPermissionMissing)
        }

        do {
            let window = try windows.focusedWindow()
            let visibleScreenFrame = try windows.visibleScreenFrame(for: window)
            let targetFrame = WindowFrameCalculator.frame(for: action, in: visibleScreenFrame)
            try windows.move(window, to: targetFrame)
            return .moved(targetFrame)
        } catch let error as WindowMovementError {
            return .failed(error)
        } catch {
            return .failed(.failedToSetWindowFrame)
        }
    }
}
