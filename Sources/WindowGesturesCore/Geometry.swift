import Foundation

public struct Rect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ScreenFrame: Equatable, Sendable {
    public var frame: Rect
    public var visibleFrame: Rect

    public init(frame: Rect, visibleFrame: Rect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum WindowAction: Equatable, Sendable {
    case leftHalf
    case rightHalf
    case maximize
    case verticalMaxCenterThird
    case restore
}

public enum WindowScreenTarget: Equatable, Sendable {
    case current
    case next
}

public enum WindowMovementMode: Equatable, Sendable {
    case immediate
    case animated(duration: TimeInterval)

    public var isAnimated: Bool {
        switch self {
        case .immediate:
            return false
        case .animated(let duration):
            return duration > 0
        }
    }
}

public struct WindowCommandOptions: Equatable, Sendable {
    public var screenTarget: WindowScreenTarget
    public var movementMode: WindowMovementMode

    public init(
        screenTarget: WindowScreenTarget = .current,
        animated: Bool = false,
        animationDuration: TimeInterval = 0.25
    ) {
        self.screenTarget = screenTarget
        self.movementMode = animated && animationDuration > 0
            ? .animated(duration: min(0.5, max(0, animationDuration)))
            : .immediate
    }

    public init(
        screenTarget: WindowScreenTarget = .current,
        movementMode: WindowMovementMode
    ) {
        self.screenTarget = screenTarget
        self.movementMode = movementMode
    }
}

public enum WindowFrameCalculator {
    public static func frame(for action: WindowAction, in visibleScreenFrame: Rect) -> Rect {
        switch action {
        case .leftHalf:
            let halfWidth = visibleScreenFrame.width / 2
            return Rect(
                x: visibleScreenFrame.x,
                y: visibleScreenFrame.y,
                width: halfWidth,
                height: visibleScreenFrame.height
            )
        case .rightHalf:
            let halfWidth = visibleScreenFrame.width / 2
            return Rect(
                x: visibleScreenFrame.x + halfWidth,
                y: visibleScreenFrame.y,
                width: halfWidth,
                height: visibleScreenFrame.height
            )
        case .maximize:
            return visibleScreenFrame
        case .verticalMaxCenterThird:
            let newWidth = visibleScreenFrame.width / 3
            return Rect(
                x: visibleScreenFrame.x + (visibleScreenFrame.width - newWidth) / 2,
                y: visibleScreenFrame.y,
                width: newWidth,
                height: visibleScreenFrame.height
            )
        case .restore:
            return visibleScreenFrame
        }
    }
}

public enum ScreenSelector {
    public static func targetVisibleFrame(
        for windowFrame: Rect,
        screens: [ScreenFrame],
        target: WindowScreenTarget
    ) -> Rect? {
        guard !screens.isEmpty else {
            return nil
        }

        let orderedScreens = screens.sortedForDeterministicTraversal()
        let current = currentScreen(for: windowFrame, screens: orderedScreens) ?? orderedScreens[0]

        switch target {
        case .current:
            return current.visibleFrame
        case .next:
            guard orderedScreens.count > 1,
                  let currentIndex = orderedScreens.firstIndex(of: current) else {
                return current.visibleFrame
            }

            let nextIndex = orderedScreens.index(after: currentIndex)
            return orderedScreens[nextIndex == orderedScreens.endIndex ? orderedScreens.startIndex : nextIndex].visibleFrame
        }
    }

    public static func currentScreen(for windowFrame: Rect, screens: [ScreenFrame]) -> ScreenFrame? {
        let center = windowFrame.center
        if let containingCenter = screens.first(where: { $0.frame.contains(center) }) {
            return containingCenter
        }

        return screens.max { lhs, rhs in
            lhs.frame.intersectionArea(with: windowFrame) < rhs.frame.intersectionArea(with: windowFrame)
        }
    }
}

public enum AnimationPlanner {
    public static let visibleFrameInterval: TimeInterval = 0.025

    public static func scheduledFrames(
        from start: Rect,
        to end: Rect,
        duration: TimeInterval,
        frameInterval: TimeInterval = AnimationPlanner.visibleFrameInterval
    ) -> [Rect] {
        let frames = frames(from: start, to: end, duration: duration, frameInterval: frameInterval)
        guard duration > 0 else {
            return frames
        }

        return Array(frames.dropFirst())
    }

    public static func frames(
        from start: Rect,
        to end: Rect,
        duration: TimeInterval,
        frameInterval: TimeInterval = AnimationPlanner.visibleFrameInterval
    ) -> [Rect] {
        guard duration > 0 else {
            return [end]
        }

        let steps = max(12, Int(ceil(duration / frameInterval)))
        return (0...steps).map { step in
            let progress = Double(step) / Double(steps)
            return interpolate(from: start, to: end, progress: easeOut(progress))
        }
    }

    public static func easeOut(_ progress: Double) -> Double {
        let clamped = min(1, max(0, progress))
        return 1 - pow(1 - clamped, 3)
    }

    private static func interpolate(from start: Rect, to end: Rect, progress: Double) -> Rect {
        Rect(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress,
            width: start.width + (end.width - start.width) * progress,
            height: start.height + (end.height - start.height) * progress
        )
    }
}

private extension Rect {
    var center: (x: Double, y: Double) {
        (x + width / 2, y + height / 2)
    }

    func contains(_ point: (x: Double, y: Double)) -> Bool {
        point.x >= x &&
            point.x <= x + width &&
            point.y >= y &&
            point.y <= y + height
    }

    func intersectionArea(with other: Rect) -> Double {
        let minX = max(x, other.x)
        let minY = max(y, other.y)
        let maxX = min(x + width, other.x + other.width)
        let maxY = min(y + height, other.y + other.height)

        return max(0, maxX - minX) * max(0, maxY - minY)
    }
}

private extension [ScreenFrame] {
    func sortedForDeterministicTraversal() -> [ScreenFrame] {
        sorted {
            if $0.frame.x == $1.frame.x {
                return $0.frame.y < $1.frame.y
            }

            return $0.frame.x < $1.frame.x
        }
    }
}
