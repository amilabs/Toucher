import Foundation

public struct RawTouchSample: Equatable, Sendable {
    public var activeTouchCount: Int
    public var centroidX: Double
    public var centroidY: Double
    public var timestamp: TimeInterval

    public init(activeTouchCount: Int, centroidX: Double, centroidY: Double, timestamp: TimeInterval) {
        self.activeTouchCount = activeTouchCount
        self.centroidX = centroidX
        self.centroidY = centroidY
        self.timestamp = timestamp
    }
}

public enum RawGestureIgnoredReason: String, Equatable, Sendable {
    case tracking
    case unsupportedFingerCount
    case fingerCountChanged
    case vertical
    case diagonal
    case belowThreshold
    case tooSlow
    case cooldown
    case alreadyTriggered
}

public enum RawGestureRecognitionResult: Equatable, Sendable {
    case action(WindowAction)
    case ignored(RawGestureIgnoredReason)
}

public final class RawThreeFingerSwipeRecognizer {
    private struct TrackingGesture {
        var startX: Double
        var startY: Double
        var startTimestamp: TimeInterval
    }

    private enum State {
        case idle
        case tracking(TrackingGesture)
        case completed
    }

    private let minHorizontalDistance: Double
    private let dominanceRatio: Double
    private let maxGestureDuration: TimeInterval
    private let cooldown: TimeInterval
    private let invertDirection: Bool
    private var state = State.idle
    private var lastTriggerTimestamp: TimeInterval?

    public init(
        minHorizontalDistance: Double = 0.08,
        dominanceRatio: Double = 2.0,
        maxGestureDuration: TimeInterval = 0.8,
        cooldown: TimeInterval = 0.35,
        invertDirection: Bool = false
    ) {
        self.minHorizontalDistance = minHorizontalDistance
        self.dominanceRatio = dominanceRatio
        self.maxGestureDuration = maxGestureDuration
        self.cooldown = cooldown
        self.invertDirection = invertDirection
    }

    public func recognize(_ sample: RawTouchSample) -> RawGestureRecognitionResult {
        guard sample.activeTouchCount == 3 else {
            let reason: RawGestureIgnoredReason
            switch state {
            case .idle:
                reason = .unsupportedFingerCount
            case .tracking, .completed:
                reason = .fingerCountChanged
            }
            state = .idle
            return .ignored(reason)
        }

        switch state {
        case .idle:
            if isCoolingDown(at: sample.timestamp) {
                state = .completed
                return .ignored(.cooldown)
            }

            state = .tracking(
                TrackingGesture(
                    startX: sample.centroidX,
                    startY: sample.centroidY,
                    startTimestamp: sample.timestamp
                )
            )
            return .ignored(.tracking)

        case .tracking(let gesture):
            let duration = sample.timestamp - gesture.startTimestamp
            guard duration <= maxGestureDuration else {
                state = .completed
                return .ignored(.tooSlow)
            }

            let deltaX = sample.centroidX - gesture.startX
            let deltaY = sample.centroidY - gesture.startY
            let absX = abs(deltaX)
            let absY = abs(deltaY)

            guard absX >= minHorizontalDistance else {
                if absY >= minHorizontalDistance {
                    return .ignored(.vertical)
                }

                return .ignored(.belowThreshold)
            }

            guard absX >= absY * dominanceRatio else {
                return .ignored(.diagonal)
            }

            guard !isCoolingDown(at: sample.timestamp) else {
                state = .completed
                return .ignored(.cooldown)
            }

            lastTriggerTimestamp = sample.timestamp
            state = .completed
            let isRightSwipe = invertDirection ? deltaX < 0 : deltaX > 0
            return .action(isRightSwipe ? .rightHalf : .leftHalf)

        case .completed:
            return .ignored(.alreadyTriggered)
        }
    }

    private func isCoolingDown(at timestamp: TimeInterval) -> Bool {
        guard let lastTriggerTimestamp else {
            return false
        }

        return timestamp - lastTriggerTimestamp < cooldown
    }
}
