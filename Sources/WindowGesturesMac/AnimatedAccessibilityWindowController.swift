import Foundation
import WindowGesturesCore

public struct WindowAnimationDiagnostics: Equatable, Sendable {
    public var lastMovementMode: String
    public var lastAnimationFramesCount: Int
    public var lastAnimationDuration: TimeInterval

    public init(
        lastMovementMode: String = "none",
        lastAnimationFramesCount: Int = 0,
        lastAnimationDuration: TimeInterval = 0
    ) {
        self.lastMovementMode = lastMovementMode
        self.lastAnimationFramesCount = lastAnimationFramesCount
        self.lastAnimationDuration = lastAnimationDuration
    }
}

public final class AnimatedAccessibilityWindowController: WindowControlling {
    public typealias Window = AccessibilityWindowController.Window

    private let base: AccessibilityWindowController
    private var timers: [String: Timer] = [:]
    public private(set) var diagnostics = WindowAnimationDiagnostics()

    public init(
        base: AccessibilityWindowController = AccessibilityWindowController()
    ) {
        self.base = base
    }

    deinit {
        cancelAllAnimations()
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
        let identifier = restoreIdentifier(for: window) ?? String(describing: ObjectIdentifier(window))
        cancelAnimation(for: identifier)
        diagnostics = WindowAnimationDiagnostics(
            lastMovementMode: "immediate",
            lastAnimationFramesCount: 0,
            lastAnimationDuration: 0
        )
        try base.move(window, to: frame)
    }

    public func animatedMove(_ window: Window, to frame: Rect, duration: TimeInterval) throws {
        assertMainThread()
        let identifier = restoreIdentifier(for: window) ?? String(describing: ObjectIdentifier(window))
        cancelAnimation(for: identifier)

        let duration = min(0.5, max(0, duration))
        guard duration > 0 else {
            diagnostics = WindowAnimationDiagnostics(
                lastMovementMode: "immediate",
                lastAnimationFramesCount: 0,
                lastAnimationDuration: 0
            )
            try base.move(window, to: frame)
            return
        }

        let startFrame = try base.frame(for: window)
        let frames = AnimationPlanner.frames(from: startFrame, to: frame, duration: duration)
        guard frames.count > 1 else {
            diagnostics = WindowAnimationDiagnostics(
                lastMovementMode: "immediate",
                lastAnimationFramesCount: 0,
                lastAnimationDuration: 0
            )
            try base.move(window, to: frame)
            return
        }

        let scheduledFrames = AnimationPlanner.scheduledFrames(from: startFrame, to: frame, duration: duration)
        guard let finalFrame = scheduledFrames.last,
              finalFrame == frame else {
            try base.move(window, to: frame)
            return
        }

        diagnostics = WindowAnimationDiagnostics(
            lastMovementMode: "animated",
            lastAnimationFramesCount: scheduledFrames.count,
            lastAnimationDuration: duration
        )

        var index = 0
        let timer = Timer.scheduledTimer(withTimeInterval: duration / Double(max(1, scheduledFrames.count)), repeats: true) {
            [weak self, weak window] timer in
            guard let self,
                  let window else {
                timer.invalidate()
                return
            }

            if index >= scheduledFrames.count {
                timer.invalidate()
                self.timers.removeValue(forKey: identifier)
                return
            }

            do {
                try self.base.move(window, to: scheduledFrames[index])
            } catch {
                timer.invalidate()
                self.timers.removeValue(forKey: identifier)
                return
            }

            if index == scheduledFrames.count - 1 {
                timer.invalidate()
                self.timers.removeValue(forKey: identifier)
                return
            }

            index += 1
        }
        timers[identifier] = timer
    }

    public func cancelAnimations() {
        assertMainThread()
        cancelAllAnimations()
    }

    public func restoreIdentifier(for window: Window) -> String? {
        base.restoreIdentifier(for: window)
    }

    private func cancelAnimation(for identifier: String) {
        timers[identifier]?.invalidate()
        timers.removeValue(forKey: identifier)
    }

    private func cancelAllAnimations() {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
    }

    private func assertMainThread() {
        precondition(Thread.isMainThread, "AnimatedAccessibilityWindowController must be used on the main thread")
    }
}
