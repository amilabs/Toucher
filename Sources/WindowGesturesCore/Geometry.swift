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

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var center: (x: Double, y: Double) {
        (x + width / 2, y + height / 2)
    }

    public func contains(_ point: (x: Double, y: Double)) -> Bool {
        point.x >= minX &&
            point.x <= maxX &&
            point.y >= minY &&
            point.y <= maxY
    }

    public func contains(_ rect: Rect, tolerance: Double = 0.5) -> Bool {
        rect.minX >= minX - tolerance &&
            rect.minY >= minY - tolerance &&
            rect.maxX <= maxX + tolerance &&
            rect.maxY <= maxY + tolerance
    }

    public func intersectionArea(with other: Rect) -> Double {
        let intersectionMinX = max(minX, other.minX)
        let intersectionMinY = max(minY, other.minY)
        let intersectionMaxX = min(maxX, other.maxX)
        let intersectionMaxY = min(maxY, other.maxY)

        return max(0, intersectionMaxX - intersectionMinX) * max(0, intersectionMaxY - intersectionMinY)
    }

    public static func union(_ rects: [Rect]) -> Rect? {
        guard let first = rects.first else {
            return nil
        }

        let minX = rects.dropFirst().reduce(first.minX) { min($0, $1.minX) }
        let minY = rects.dropFirst().reduce(first.minY) { min($0, $1.minY) }
        let maxX = rects.dropFirst().reduce(first.maxX) { max($0, $1.maxX) }
        let maxY = rects.dropFirst().reduce(first.maxY) { max($0, $1.maxY) }

        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
    case discreteSteps(totalStepCount: Int, totalDuration: TimeInterval)
}

public enum DiscreteMovementDefaults {
    public static let enableDiscreteMovementSteps = true
    public static let totalStepCount = 32
    public static let totalDuration: TimeInterval = 0.10

    public static var movementMode: WindowMovementMode {
        enableDiscreteMovementSteps
            ? .discreteSteps(totalStepCount: totalStepCount, totalDuration: totalDuration)
            : .immediate
    }
}

public struct WindowCommandOptions: Equatable, Sendable {
    public var screenTarget: WindowScreenTarget
    public var movementMode: WindowMovementMode

    public init(
        screenTarget: WindowScreenTarget = .current,
        animateWindowMovement: Bool = false,
        animationDuration: TimeInterval = 0.10,
        animationSteps: Int = 32
    ) {
        self.screenTarget = screenTarget
        self.movementMode = animateWindowMovement
            ? .discreteSteps(
                totalStepCount: min(32, max(3, animationSteps)),
                totalDuration: min(0.60, max(0.02, animationDuration))
            )
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

public struct DiscreteMovementPlan: Equatable, Sendable {
    public var frames: [Rect]
    public var progressValues: [Double]
    public var totalDuration: TimeInterval
    public var movementKind: MovementDeltaKind
    public var startFrame: Rect
    public var targetFrame: Rect

    public init(
        frames: [Rect],
        progressValues: [Double],
        totalDuration: TimeInterval,
        movementKind: MovementDeltaKind,
        startFrame: Rect,
        targetFrame: Rect
    ) {
        self.frames = frames
        self.progressValues = progressValues
        self.totalDuration = totalDuration
        self.movementKind = movementKind
        self.startFrame = startFrame
        self.targetFrame = targetFrame
    }

    public var stepInterval: TimeInterval {
        guard !frames.isEmpty else {
            return 0
        }

        return totalDuration / Double(frames.count)
    }

    public var plannedStepCount: Int {
        frames.count
    }
}

public enum MovementDeltaKind: String, Equatable, Sendable {
    case positionOnly
    case sizeOnly
    case positionAndSize
    case noOp

    public static func classify(from currentFrame: Rect, to targetFrame: Rect, tolerance: Double = 0.5) -> MovementDeltaKind {
        let originChanged = abs(currentFrame.x - targetFrame.x) > tolerance ||
            abs(currentFrame.y - targetFrame.y) > tolerance
        let sizeChanged = abs(currentFrame.width - targetFrame.width) > tolerance ||
            abs(currentFrame.height - targetFrame.height) > tolerance

        switch (originChanged, sizeChanged) {
        case (false, false):
            return .noOp
        case (true, false):
            return .positionOnly
        case (false, true):
            return .sizeOnly
        case (true, true):
            return .positionAndSize
        }
    }
}

public enum MovementFramePlanner {
    public static let resizeHeavyStepCap = 10

    public static func plan(
        from currentFrame: Rect,
        to targetFrame: Rect,
        totalStepCount: Int,
        totalDuration: TimeInterval,
        tolerance: Double = 0.5
    ) -> DiscreteMovementPlan {
        let movementKind = MovementDeltaKind.classify(from: currentFrame, to: targetFrame, tolerance: tolerance)
        let requestedFrames = max(1, totalStepCount)
        let totalFrames: Int

        switch movementKind {
        case .positionOnly:
            totalFrames = requestedFrames
        case .sizeOnly, .positionAndSize:
            totalFrames = min(requestedFrames, resizeHeavyStepCap)
        case .noOp:
            totalFrames = 1
        }

        var frames: [Rect] = []
        var progressValues: [Double] = []
        var previousFrame = currentFrame

        for index in 1...totalFrames {
            let isFinal = index == totalFrames
            let progress = Double(index) / Double(totalFrames)
            let frame = isFinal ? targetFrame : interpolatedFrame(from: currentFrame, to: targetFrame, progress: progress)

            if !isFinal,
               shouldSkip(frame, after: previousFrame, movementKind: movementKind, tolerance: tolerance) {
                continue
            }

            frames.append(frame)
            progressValues.append(progress)
            previousFrame = frame
        }

        if frames.last != targetFrame {
            frames.append(targetFrame)
            progressValues.append(1)
        }

        return DiscreteMovementPlan(
            frames: frames,
            progressValues: progressValues,
            totalDuration: totalDuration,
            movementKind: movementKind,
            startFrame: currentFrame,
            targetFrame: targetFrame
        )
    }

    public static func interpolatedFrame(from currentFrame: Rect, to targetFrame: Rect, progress: Double) -> Rect {
        let clampedProgress = min(1, max(0, progress))
        if clampedProgress >= 1 {
            return targetFrame
        }

        return Rect(
            x: currentFrame.x + (targetFrame.x - currentFrame.x) * clampedProgress,
            y: currentFrame.y + (targetFrame.y - currentFrame.y) * clampedProgress,
            width: currentFrame.width + (targetFrame.width - currentFrame.width) * clampedProgress,
            height: currentFrame.height + (targetFrame.height - currentFrame.height) * clampedProgress
        )
    }

    private static func shouldSkip(
        _ frame: Rect,
        after previousFrame: Rect,
        movementKind: MovementDeltaKind,
        tolerance: Double
    ) -> Bool {
        let originDeltaIsTiny = abs(frame.x - previousFrame.x) <= tolerance &&
            abs(frame.y - previousFrame.y) <= tolerance
        let sizeDeltaIsTiny = abs(frame.width - previousFrame.width) < 1 &&
            abs(frame.height - previousFrame.height) < 1

        switch movementKind {
        case .positionOnly:
            return originDeltaIsTiny
        case .sizeOnly, .positionAndSize:
            return originDeltaIsTiny && sizeDeltaIsTiny
        case .noOp:
            return true
        }
    }
}

public struct DiscreteMovementRunner: Equatable, Sendable {
    public private(set) var plan: DiscreteMovementPlan
    public private(set) var appliedSteps: Int = 0
    public private(set) var skippedSteps: Int = 0
    public private(set) var lastAppliedFrame: Rect?
    public private(set) var isComplete = false

    private var lastProgressSlot = 0

    public init(plan: DiscreteMovementPlan) {
        self.plan = plan
        self.lastAppliedFrame = plan.startFrame
    }

    public mutating func nextFrame(elapsed: TimeInterval) -> Rect? {
        guard !isComplete else {
            return nil
        }

        let progress: Double
        if plan.totalDuration <= 0 {
            progress = 1
        } else {
            progress = min(1, max(0, elapsed / plan.totalDuration))
        }

        let slot = max(1, Int(ceil(progress * Double(plan.plannedStepCount))))
        skippedSteps += max(0, slot - lastProgressSlot - 1)
        lastProgressSlot = max(lastProgressSlot, slot)

        let isFinal = progress >= 1
        let frame = isFinal
            ? plan.targetFrame
            : MovementFramePlanner.interpolatedFrame(from: plan.startFrame, to: plan.targetFrame, progress: progress)

        if !isFinal,
           let lastAppliedFrame,
           frame.isEffectivelyEqual(to: lastAppliedFrame, tolerance: 0.5, sizeTolerance: 1) {
            skippedSteps += 1
            return nil
        }

        appliedSteps += 1
        lastAppliedFrame = frame
        isComplete = isFinal
        return frame
    }
}

public enum DiscreteMovementPlanner {
    public static func plan(
        from currentFrame: Rect,
        to targetFrame: Rect,
        totalStepCount: Int,
        totalDuration: TimeInterval
    ) -> DiscreteMovementPlan {
        MovementFramePlanner.plan(
            from: currentFrame,
            to: targetFrame,
            totalStepCount: totalStepCount,
            totalDuration: totalDuration
        )
    }
}

private extension Rect {
    func isEffectivelyEqual(to other: Rect, tolerance: Double, sizeTolerance: Double) -> Bool {
        abs(x - other.x) <= tolerance &&
            abs(y - other.y) <= tolerance &&
            abs(width - other.width) < sizeTolerance &&
            abs(height - other.height) < sizeTolerance
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

public struct AccessibilityCoordinateConverter: Equatable, Sendable {
    public var desktopUnion: Rect

    public init(desktopUnion: Rect) {
        self.desktopUnion = desktopUnion
    }

    public func accessibilityRect(fromAppKitRect rect: Rect) -> Rect {
        Rect(
            x: rect.minX,
            y: desktopUnion.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public func appKitRect(fromAccessibilityRect rect: Rect) -> Rect {
        Rect(
            x: rect.minX,
            y: desktopUnion.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

public enum ScreenGeometry {
    public static func desktopUnion(for screens: [ScreenFrame]) -> Rect? {
        Rect.union(screens.map(\.frame))
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
        if let largestIntersection = screens
            .map({ (screen: $0, area: $0.visibleFrame.intersectionArea(with: windowFrame)) })
            .filter({ $0.area > 0 })
            .max(by: { $0.area < $1.area })?
            .screen {
            return largestIntersection
        }

        let center = windowFrame.center
        if let containingCenter = screens.first(where: { $0.frame.contains(center) }) {
            return containingCenter
        }

        return screens.max {
            $0.frame.intersectionArea(with: windowFrame) < $1.frame.intersectionArea(with: windowFrame)
        }
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
