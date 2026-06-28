import Foundation
import WindowGesturesCore

public final class AnimatedAccessibilityWindowController: WindowControlling {
    public typealias Window = AccessibilityWindowController.Window

    private let base: AccessibilityWindowController
    private var timers: [String: Timer] = [:]

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
        try base.move(window, to: frame)
    }

    public func animatedMove(_ window: Window, to frame: Rect, duration: TimeInterval) throws {
        assertMainThread()
        let identifier = restoreIdentifier(for: window) ?? String(describing: ObjectIdentifier(window))
        cancelAnimation(for: identifier)

        let duration = min(0.5, max(0, duration))
        guard duration > 0 else {
            try base.move(window, to: frame)
            return
        }

        let startFrame = try base.frame(for: window)
        let frames = AnimationPlanner.frames(from: startFrame, to: frame, duration: duration)
        guard frames.count > 1 else {
            try base.move(window, to: frame)
            return
        }

        var index = 0
        let timer = Timer.scheduledTimer(withTimeInterval: duration / Double(max(1, frames.count - 1)), repeats: true) {
            [weak self, weak window] timer in
            guard let self,
                  let window else {
                timer.invalidate()
                return
            }

            if index >= frames.count {
                timer.invalidate()
                self.timers.removeValue(forKey: identifier)
                return
            }

            do {
                try self.base.move(window, to: frames[index])
            } catch {
                timer.invalidate()
                self.timers.removeValue(forKey: identifier)
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
