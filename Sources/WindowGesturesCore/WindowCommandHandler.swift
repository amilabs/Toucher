import Foundation

public enum WindowCommandResult: Equatable, Sendable {
    case moved(Rect)
    case permissionDenied
    case noActiveWindow
    case visibleScreenUnavailable
    case moveFailed(String)
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
            return .permissionDenied
        }

        guard let window = windows.activeWindow() else {
            return .noActiveWindow
        }

        guard let visibleScreenFrame = windows.visibleScreenFrame(for: window) else {
            return .visibleScreenUnavailable
        }

        let targetFrame = WindowFrameCalculator.frame(for: action, in: visibleScreenFrame)

        do {
            try windows.move(window, to: targetFrame)
            return .moved(targetFrame)
        } catch {
            return .moveFailed(String(describing: error))
        }
    }
}
