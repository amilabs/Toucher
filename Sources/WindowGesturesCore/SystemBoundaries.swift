import Foundation

public protocol HotKeyRegistering: AnyObject {
    func register(_ hotKeys: [HotKey], handler: @escaping @Sendable (HotKey) -> Void) throws
    func unregisterAll()
}

public protocol PermissionChecking {
    var hasAccessibilityPermission: Bool { get }
    func openAccessibilitySettings()
}

public protocol WindowControlling {
    associatedtype Window

    func focusedWindow() throws -> Window
    func frame(for window: Window) throws -> Rect
    func visibleScreenFrame(for window: Window) throws -> Rect
    func screens() throws -> [ScreenFrame]
    func move(_ window: Window, to frame: Rect) throws
    func move(_ window: Window, to frame: Rect, movementMode: WindowMovementMode) throws
    func restoreIdentifier(for window: Window) -> String?
}

public extension WindowControlling {
    func screens() throws -> [ScreenFrame] {
        []
    }

    func move(_ window: Window, to frame: Rect, movementMode: WindowMovementMode) throws {
        switch movementMode {
        case .immediate:
            try move(window, to: frame)
        case .discreteSteps(let totalStepCount, let totalDuration):
            let currentFrame = try self.frame(for: window)
            let plan = DiscreteMovementPlanner.plan(
                from: currentFrame,
                to: frame,
                totalStepCount: totalStepCount,
                totalDuration: totalDuration
            )
            for plannedFrame in plan.frames {
                try move(window, to: plannedFrame)
            }
        }
    }
}
