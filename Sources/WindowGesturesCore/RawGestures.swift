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
    case horizontal
    case wrongDirection
    case diagonal
    case belowThreshold
    case tooSlow
    case cooldown
    case alreadyTriggered
    case fingerCountChangedBeforeConfirmation
    case liftedBeforeConfirmation
    case directionChangedBeforeConfirmation
    case insufficientStableSamples
    case confirmationTimeoutOrExpired
}

public enum RawGestureRecognitionResult: Equatable, Sendable {
    case action(WindowAction)
    case ignored(RawGestureIgnoredReason)
}

public enum RawGestureRecognizerState: String, Equatable, Sendable {
    case idle
    case candidateThreeFinger
    case pendingTrigger
    case triggered
    case canceled
}

public struct RawGestureDiagnosticSnapshot: Equatable, Sendable {
    public var recognizerState: RawGestureRecognizerState
    public var currentActiveTouchCount: Int
    public var candidateStartTouchCount: Int?
    public var candidateSampleCount: Int
    public var candidateCanceledReason: RawGestureIgnoredReason?
    public var pendingAction: WindowAction?
    public var thresholdCrossedTimestamp: TimeInterval?
    public var confirmationDelay: TimeInterval
    public var lastAcceptedActiveTouchCount: Int?
    public var minHorizontalDistance: Double
    public var minVerticalDistance: Double
    public var dominanceRatio: Double
    public var maxGestureDuration: TimeInterval
    public var cooldown: TimeInterval
    public var lastGestureDuration: TimeInterval?
    public var lastGestureStartTimestamp: TimeInterval?
    public var lastGestureEndTimestamp: TimeInterval?
    public var lastGestureAccepted: Bool?
    public var lastRejectionReason: RawGestureIgnoredReason?

    public init(
        recognizerState: RawGestureRecognizerState = .idle,
        currentActiveTouchCount: Int = 0,
        candidateStartTouchCount: Int? = nil,
        candidateSampleCount: Int = 0,
        candidateCanceledReason: RawGestureIgnoredReason? = nil,
        pendingAction: WindowAction? = nil,
        thresholdCrossedTimestamp: TimeInterval? = nil,
        confirmationDelay: TimeInterval = 0,
        lastAcceptedActiveTouchCount: Int? = nil,
        minHorizontalDistance: Double,
        minVerticalDistance: Double,
        dominanceRatio: Double,
        maxGestureDuration: TimeInterval,
        cooldown: TimeInterval,
        lastGestureDuration: TimeInterval? = nil,
        lastGestureStartTimestamp: TimeInterval? = nil,
        lastGestureEndTimestamp: TimeInterval? = nil,
        lastGestureAccepted: Bool? = nil,
        lastRejectionReason: RawGestureIgnoredReason? = nil
    ) {
        self.recognizerState = recognizerState
        self.currentActiveTouchCount = currentActiveTouchCount
        self.candidateStartTouchCount = candidateStartTouchCount
        self.candidateSampleCount = candidateSampleCount
        self.candidateCanceledReason = candidateCanceledReason
        self.pendingAction = pendingAction
        self.thresholdCrossedTimestamp = thresholdCrossedTimestamp
        self.confirmationDelay = confirmationDelay
        self.lastAcceptedActiveTouchCount = lastAcceptedActiveTouchCount
        self.minHorizontalDistance = minHorizontalDistance
        self.minVerticalDistance = minVerticalDistance
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
    private struct CandidateGesture {
        var startX: Double
        var startY: Double
        var startTimestamp: TimeInterval
        var sampleCount: Int
    }

    private struct PendingTrigger {
        var candidate: CandidateGesture
        var action: WindowAction
        var thresholdCrossedTimestamp: TimeInterval
    }

    private enum State {
        case idle
        case candidateThreeFinger(CandidateGesture)
        case pendingTrigger(PendingTrigger)
        case triggered
        case canceled
    }

    private enum ActionEvaluation {
        case action(WindowAction)
        case ignored(RawGestureIgnoredReason)
    }

    private static let requiredExactThreeFingerSampleCount = 4
    private static let minimumCandidateAge: TimeInterval = 0.050
    private static let triggerConfirmationDelay: TimeInterval = 0.070

    public let minHorizontalDistance: Double
    public let minVerticalDistance: Double
    public let dominanceRatio: Double
    public let maxGestureDuration: TimeInterval
    public let cooldown: TimeInterval
    public let invertDirection: Bool
    public let invertVerticalDirection: Bool
    private var state = State.idle
    private var lastTriggerTimestamp: TimeInterval?
    public private(set) var diagnostics: RawGestureDiagnosticSnapshot

    public init(
        minHorizontalDistance: Double = 0.08,
        minVerticalDistance: Double? = nil,
        dominanceRatio: Double = 2.0,
        maxGestureDuration: TimeInterval = 0.8,
        cooldown: TimeInterval = 0.35,
        invertDirection: Bool = false,
        invertVerticalDirection: Bool = false
    ) {
        self.minHorizontalDistance = minHorizontalDistance
        self.minVerticalDistance = minVerticalDistance ?? minHorizontalDistance
        self.dominanceRatio = dominanceRatio
        self.maxGestureDuration = maxGestureDuration
        self.cooldown = cooldown
        self.invertDirection = invertDirection
        self.invertVerticalDirection = invertVerticalDirection
        self.diagnostics = RawGestureDiagnosticSnapshot(
            confirmationDelay: Self.triggerConfirmationDelay,
            minHorizontalDistance: minHorizontalDistance,
            minVerticalDistance: minVerticalDistance ?? minHorizontalDistance,
            dominanceRatio: dominanceRatio,
            maxGestureDuration: maxGestureDuration,
            cooldown: cooldown
        )
    }

    public func recognize(_ sample: RawTouchSample) -> RawGestureRecognitionResult {
        diagnostics.currentActiveTouchCount = sample.activeTouchCount

        guard sample.activeTouchCount == 3 else {
            return handleNonThreeFingerSample(sample)
        }

        switch state {
        case .idle:
            guard !isCoolingDown(at: sample.timestamp) else {
                transitionToCanceled(reason: .cooldown)
                return .ignored(.cooldown)
            }

            let candidate = CandidateGesture(
                startX: sample.centroidX,
                startY: sample.centroidY,
                startTimestamp: sample.timestamp,
                sampleCount: 1
            )
            state = .candidateThreeFinger(candidate)
            diagnostics.recognizerState = .candidateThreeFinger
            diagnostics.candidateStartTouchCount = 3
            diagnostics.candidateSampleCount = candidate.sampleCount
            diagnostics.candidateCanceledReason = nil
            diagnostics.pendingAction = nil
            diagnostics.thresholdCrossedTimestamp = nil
            diagnostics.lastGestureStartTimestamp = sample.timestamp
            diagnostics.lastGestureEndTimestamp = nil
            diagnostics.lastGestureDuration = nil
            diagnostics.lastGestureAccepted = nil
            diagnostics.lastRejectionReason = nil
            return .ignored(.tracking)

        case .candidateThreeFinger(var candidate):
            candidate.sampleCount += 1
            state = .candidateThreeFinger(candidate)
            diagnostics.candidateSampleCount = candidate.sampleCount

            let duration = sample.timestamp - candidate.startTimestamp
            guard duration <= maxGestureDuration else {
                transitionToCanceled(reason: .tooSlow)
                recordRejected(.tooSlow, startTimestamp: candidate.startTimestamp, endTimestamp: sample.timestamp)
                return .ignored(.tooSlow)
            }

            switch evaluateAction(candidate: candidate, sample: sample) {
            case .ignored(let reason):
                recordRejected(reason, startTimestamp: candidate.startTimestamp, endTimestamp: sample.timestamp)
                return .ignored(reason)
            case .action(let action):
                guard candidate.sampleCount >= Self.requiredExactThreeFingerSampleCount,
                      duration >= Self.minimumCandidateAge else {
                    recordRejected(
                        .insufficientStableSamples,
                        startTimestamp: candidate.startTimestamp,
                        endTimestamp: sample.timestamp
                    )
                    return .ignored(.insufficientStableSamples)
                }

                let pending = PendingTrigger(
                    candidate: candidate,
                    action: action,
                    thresholdCrossedTimestamp: sample.timestamp
                )
                transitionToPending(pending)
                return .ignored(.tracking)
            }

        case .pendingTrigger(var pending):
            pending.candidate.sampleCount += 1
            state = .pendingTrigger(pending)
            diagnostics.candidateSampleCount = pending.candidate.sampleCount

            let duration = sample.timestamp - pending.candidate.startTimestamp
            guard duration <= maxGestureDuration else {
                transitionToCanceled(reason: .confirmationTimeoutOrExpired)
                recordRejected(
                    .confirmationTimeoutOrExpired,
                    startTimestamp: pending.candidate.startTimestamp,
                    endTimestamp: sample.timestamp
                )
                return .ignored(.confirmationTimeoutOrExpired)
            }

            switch evaluateAction(candidate: pending.candidate, sample: sample) {
            case .ignored:
                transitionToCanceled(reason: .directionChangedBeforeConfirmation)
                recordRejected(
                    .directionChangedBeforeConfirmation,
                    startTimestamp: pending.candidate.startTimestamp,
                    endTimestamp: sample.timestamp
                )
                return .ignored(.directionChangedBeforeConfirmation)
            case .action(let action):
                guard action == pending.action else {
                    transitionToCanceled(reason: .directionChangedBeforeConfirmation)
                    recordRejected(
                        .directionChangedBeforeConfirmation,
                        startTimestamp: pending.candidate.startTimestamp,
                        endTimestamp: sample.timestamp
                    )
                    return .ignored(.directionChangedBeforeConfirmation)
                }

                guard sample.timestamp - pending.thresholdCrossedTimestamp >= Self.triggerConfirmationDelay else {
                    return .ignored(.tracking)
                }

                guard !isCoolingDown(at: sample.timestamp) else {
                    transitionToCanceled(reason: .cooldown)
                    recordRejected(.cooldown, startTimestamp: pending.candidate.startTimestamp, endTimestamp: sample.timestamp)
                    return .ignored(.cooldown)
                }

                lastTriggerTimestamp = sample.timestamp
                transitionToTriggered()
                recordAccepted(startTimestamp: pending.candidate.startTimestamp, endTimestamp: sample.timestamp)
                return .action(action)
            }

        case .triggered:
            return .ignored(.alreadyTriggered)

        case .canceled:
            return .ignored(.fingerCountChanged)
        }
    }

    private func handleNonThreeFingerSample(_ sample: RawTouchSample) -> RawGestureRecognitionResult {
        switch state {
        case .idle:
            diagnostics.recognizerState = .idle
            return .ignored(.unsupportedFingerCount)

        case .candidateThreeFinger(let candidate):
            let reason = sample.activeTouchCount == 0
                ? RawGestureIgnoredReason.liftedBeforeConfirmation
                : RawGestureIgnoredReason.fingerCountChanged
            transitionOrResetAfterPreTriggerCancel(reason: reason, activeTouchCount: sample.activeTouchCount)
            recordRejected(reason, startTimestamp: candidate.startTimestamp, endTimestamp: sample.timestamp)
            return .ignored(reason)

        case .pendingTrigger(let pending):
            let reason = sample.activeTouchCount == 0
                ? RawGestureIgnoredReason.liftedBeforeConfirmation
                : RawGestureIgnoredReason.fingerCountChangedBeforeConfirmation
            transitionOrResetAfterPreTriggerCancel(reason: reason, activeTouchCount: sample.activeTouchCount)
            recordRejected(reason, startTimestamp: pending.candidate.startTimestamp, endTimestamp: sample.timestamp)
            return .ignored(reason)

        case .triggered:
            if sample.activeTouchCount == 0 {
                resetSession()
                return .ignored(.unsupportedFingerCount)
            }
            return .ignored(.alreadyTriggered)

        case .canceled:
            if sample.activeTouchCount == 0 {
                resetSession()
                return .ignored(.unsupportedFingerCount)
            }
            return .ignored(.fingerCountChanged)
        }
    }

    private func evaluateAction(candidate: CandidateGesture, sample: RawTouchSample) -> ActionEvaluation {
        let deltaX = sample.centroidX - candidate.startX
        let deltaY = sample.centroidY - candidate.startY
        let absX = abs(deltaX)
        let absY = abs(deltaY)

        let isHorizontalCandidate = absX >= minHorizontalDistance
        let isVerticalCandidate = absY >= minVerticalDistance
        guard isHorizontalCandidate || isVerticalCandidate else {
            return .ignored(.belowThreshold)
        }

        if isVerticalCandidate,
           absY >= absX * dominanceRatio {
            let isUpSwipe = invertVerticalDirection ? deltaY < 0 : deltaY > 0
            guard isUpSwipe else {
                return .ignored(.wrongDirection)
            }
            return .action(.maximize)
        }

        guard isHorizontalCandidate,
              absX >= absY * dominanceRatio else {
            return .ignored(.diagonal)
        }

        let isRightSwipe = invertDirection ? deltaX < 0 : deltaX > 0
        return .action(isRightSwipe ? .rightHalf : .leftHalf)
    }

    private func resetSession() {
        state = .idle
        diagnostics.recognizerState = .idle
        diagnostics.candidateStartTouchCount = nil
        diagnostics.candidateSampleCount = 0
        diagnostics.candidateCanceledReason = nil
        diagnostics.pendingAction = nil
        diagnostics.thresholdCrossedTimestamp = nil
    }

    private func transitionOrResetAfterPreTriggerCancel(reason: RawGestureIgnoredReason, activeTouchCount: Int) {
        if activeTouchCount == 0 {
            state = .idle
            diagnostics.recognizerState = .idle
        } else {
            state = .canceled
            diagnostics.recognizerState = .canceled
        }
        diagnostics.candidateStartTouchCount = nil
        diagnostics.candidateSampleCount = 0
        diagnostics.candidateCanceledReason = reason
        diagnostics.pendingAction = nil
        diagnostics.thresholdCrossedTimestamp = nil
    }

    private func transitionToPending(_ pending: PendingTrigger) {
        state = .pendingTrigger(pending)
        diagnostics.recognizerState = .pendingTrigger
        diagnostics.pendingAction = pending.action
        diagnostics.thresholdCrossedTimestamp = pending.thresholdCrossedTimestamp
        diagnostics.candidateStartTouchCount = 3
        diagnostics.candidateSampleCount = pending.candidate.sampleCount
        diagnostics.candidateCanceledReason = nil
    }

    private func transitionToTriggered() {
        state = .triggered
        diagnostics.recognizerState = .triggered
        diagnostics.candidateStartTouchCount = nil
        diagnostics.candidateSampleCount = 0
        diagnostics.candidateCanceledReason = nil
        diagnostics.pendingAction = nil
        diagnostics.thresholdCrossedTimestamp = nil
    }

    private func transitionToCanceled(reason: RawGestureIgnoredReason) {
        state = .canceled
        diagnostics.recognizerState = .canceled
        diagnostics.candidateStartTouchCount = nil
        diagnostics.candidateSampleCount = 0
        diagnostics.candidateCanceledReason = reason
        diagnostics.pendingAction = nil
        diagnostics.thresholdCrossedTimestamp = nil
    }

    private func isCoolingDown(at timestamp: TimeInterval) -> Bool {
        guard let lastTriggerTimestamp else {
            return false
        }

        return timestamp - lastTriggerTimestamp < cooldown
    }

    private func recordAccepted(startTimestamp: TimeInterval, endTimestamp: TimeInterval) {
        diagnostics.lastAcceptedActiveTouchCount = 3
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
