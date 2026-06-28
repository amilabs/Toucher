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

public struct RawGestureDiagnosticSnapshot: Equatable, Sendable {
    public var minHorizontalDistance: Double
    public var dominanceRatio: Double
    public var maxGestureDuration: TimeInterval
    public var cooldown: TimeInterval
    public var lastGestureDuration: TimeInterval?
    public var lastGestureStartTimestamp: TimeInterval?
    public var lastGestureEndTimestamp: TimeInterval?
    public var lastGestureAccepted: Bool?
    public var lastRejectionReason: RawGestureIgnoredReason?

    public init(
        minHorizontalDistance: Double,
        dominanceRatio: Double,
        maxGestureDuration: TimeInterval,
        cooldown: TimeInterval,
        lastGestureDuration: TimeInterval? = nil,
        lastGestureStartTimestamp: TimeInterval? = nil,
        lastGestureEndTimestamp: TimeInterval? = nil,
        lastGestureAccepted: Bool? = nil,
        lastRejectionReason: RawGestureIgnoredReason? = nil
    ) {
        self.minHorizontalDistance = minHorizontalDistance
        self.dominanceRatio = dominanceRatio
        self.maxGestureDuration = maxGestureDuration
        self.cooldown = cooldown
        self.lastGestureDuration = lastGestureDuration
        self.lastGestureStartTimestamp = lastGestureStartTimestamp
        self.lastGestureEndTimestamp = lastGestureEndTimestamp
        self.lastGestureAccepted = lastGestureAccepted
        self.lastRejectionReason = lastRejectionReason
    }
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

    public let minHorizontalDistance: Double
    public let dominanceRatio: Double
    public let maxGestureDuration: TimeInterval
    public let cooldown: TimeInterval
    public let invertDirection: Bool
    private var state = State.idle
    private var lastTriggerTimestamp: TimeInterval?
    public private(set) var diagnostics: RawGestureDiagnosticSnapshot

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
        self.diagnostics = RawGestureDiagnosticSnapshot(
            minHorizontalDistance: minHorizontalDistance,
            dominanceRatio: dominanceRatio,
            maxGestureDuration: maxGestureDuration,
            cooldown: cooldown
        )
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
            recordRejected(reason, startTimestamp: nil, endTimestamp: sample.timestamp)
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
            diagnostics.lastGestureStartTimestamp = sample.timestamp
            diagnostics.lastGestureEndTimestamp = nil
            diagnostics.lastGestureDuration = nil
            diagnostics.lastGestureAccepted = nil
            diagnostics.lastRejectionReason = nil
            return .ignored(.tracking)

        case .tracking(let gesture):
            let duration = sample.timestamp - gesture.startTimestamp
            guard duration <= maxGestureDuration else {
                state = .completed
                recordRejected(.tooSlow, startTimestamp: gesture.startTimestamp, endTimestamp: sample.timestamp)
                return .ignored(.tooSlow)
            }

            let deltaX = sample.centroidX - gesture.startX
            let deltaY = sample.centroidY - gesture.startY
            let absX = abs(deltaX)
            let absY = abs(deltaY)

            guard absX >= minHorizontalDistance else {
                if absY >= minHorizontalDistance {
                    recordRejected(.vertical, startTimestamp: gesture.startTimestamp, endTimestamp: sample.timestamp)
                    return .ignored(.vertical)
                }

                recordRejected(.belowThreshold, startTimestamp: gesture.startTimestamp, endTimestamp: sample.timestamp)
                return .ignored(.belowThreshold)
            }

            guard absX >= absY * dominanceRatio else {
                recordRejected(.diagonal, startTimestamp: gesture.startTimestamp, endTimestamp: sample.timestamp)
                return .ignored(.diagonal)
            }

            guard !isCoolingDown(at: sample.timestamp) else {
                state = .completed
                recordRejected(.cooldown, startTimestamp: gesture.startTimestamp, endTimestamp: sample.timestamp)
                return .ignored(.cooldown)
            }

            lastTriggerTimestamp = sample.timestamp
            state = .completed
            recordAccepted(startTimestamp: gesture.startTimestamp, endTimestamp: sample.timestamp)
            let isRightSwipe = invertDirection ? deltaX < 0 : deltaX > 0
            return .action(isRightSwipe ? .rightHalf : .leftHalf)

        case .completed:
            recordRejected(.alreadyTriggered, startTimestamp: nil, endTimestamp: sample.timestamp)
            return .ignored(.alreadyTriggered)
        }
    }

    private func isCoolingDown(at timestamp: TimeInterval) -> Bool {
        guard let lastTriggerTimestamp else {
            return false
        }

        return timestamp - lastTriggerTimestamp < cooldown
    }

    private func recordAccepted(startTimestamp: TimeInterval, endTimestamp: TimeInterval) {
        diagnostics.lastGestureStartTimestamp = startTimestamp
        diagnostics.lastGestureEndTimestamp = endTimestamp
        diagnostics.lastGestureDuration = endTimestamp - startTimestamp
        diagnostics.lastGestureAccepted = true
        diagnostics.lastRejectionReason = nil
    }

    private func recordRejected(
        _ reason: RawGestureIgnoredReason,
        startTimestamp: TimeInterval?,
        endTimestamp: TimeInterval
    ) {
        diagnostics.lastGestureStartTimestamp = startTimestamp ?? diagnostics.lastGestureStartTimestamp
        diagnostics.lastGestureEndTimestamp = endTimestamp
        if let startTimestamp = diagnostics.lastGestureStartTimestamp {
            diagnostics.lastGestureDuration = endTimestamp - startTimestamp
        }
        diagnostics.lastGestureAccepted = false
        diagnostics.lastRejectionReason = reason
    }
}
