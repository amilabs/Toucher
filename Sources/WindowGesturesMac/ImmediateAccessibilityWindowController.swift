import Foundation
import WindowGesturesCore

public struct WindowMovementDiagnostics: Equatable, Sendable {
    public var lastMovementMode: String
    public var lastTargetFrame: Rect?
    public var lastFinalReadbackFrame: Rect?
    public var lastMovementError: String?

    public init(
        lastMovementMode: String = "immediate",
        lastTargetFrame: Rect? = nil,
        lastFinalReadbackFrame: Rect? = nil,
        lastMovementError: String? = nil
    ) {
        self.lastMovementMode = lastMovementMode
        self.lastTargetFrame = lastTargetFrame
        self.lastFinalReadbackFrame = lastFinalReadbackFrame
        self.lastMovementError = lastMovementError
    }
}

public final class ImmediateAccessibilityWindowController: WindowControlling {
    public typealias Window = AccessibilityWindowController.Window

    private let base: AccessibilityWindowController
    public private(set) var diagnostics = WindowMovementDiagnostics()

    public init(base: AccessibilityWindowController = AccessibilityWindowController()) {
        self.base = base
    }

    public func focusedWindow() throws -> Window {
        try base.focusedWindow()
    }

    public func frame(for window: Window) throws -> Rect {
        try base.frame(for: window)
    }

    public func visibleScreenFrame(for window: Window) throws -> Rect {
        try base.visibleScreenFrame(for: window)
    }

    public func screens() throws -> [ScreenFrame] {
        try base.screens()
    }

    public func move(_ window: Window, to frame: Rect) throws {
        assertMainThread()

        do {
            try base.move(window, to: frame)
            diagnostics = WindowMovementDiagnostics(
                lastMovementMode: "immediate",
                lastTargetFrame: frame,
                lastFinalReadbackFrame: try? base.frame(for: window),
                lastMovementError: nil
            )
        } catch {
            diagnostics = WindowMovementDiagnostics(
                lastMovementMode: "immediate",
                lastTargetFrame: frame,
                lastFinalReadbackFrame: nil,
                lastMovementError: String(describing: error)
            )
            throw error
        }
    }

    public func restoreIdentifier(for window: Window) -> String? {
        base.restoreIdentifier(for: window)
    }

    private func assertMainThread() {
        precondition(Thread.isMainThread, "ImmediateAccessibilityWindowController must be used on the main thread")
    }
}
