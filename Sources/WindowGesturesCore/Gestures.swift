import Foundation

public enum GestureSource: Equatable, Sendable {
    case publicNSEventSwipe
}

public enum PublicGestureEventType: String, CaseIterable, Equatable, Sendable {
    case swipe
    case scrollWheel
    case beginGesture
    case endGesture
    case magnify
    case rotate
    case smartMagnify
}

public struct SwipeGestureInput: Equatable, Sendable {
    public var deltaX: Double
    public var deltaY: Double
    public var timestamp: TimeInterval
    public var source: GestureSource

    public init(deltaX: Double, deltaY: Double, timestamp: TimeInterval, source: GestureSource) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.timestamp = timestamp
        self.source = source
    }
}

public enum GestureIgnoredReason: String, Equatable, Sendable {
    case belowThreshold
    case diagonal
    case cooldown
    case noEventReceived
}

public enum GestureRecognitionResult: Equatable, Sendable {
    case action(WindowAction)
    case ignored(GestureIgnoredReason)
}

public protocol GestureMonitoring: AnyObject {
    var isActive: Bool { get }

    func start()
    func stop()
}

public struct PublicGestureEventInput: Equatable, Sendable {
    public var type: PublicGestureEventType
    public var timestamp: TimeInterval
    public var deltaX: Double?
    public var deltaY: Double?
    public var scrollingDeltaX: Double?
    public var scrollingDeltaY: Double?
    public var hasPreciseScrollingDeltas: Bool?
    public var isDirectionInvertedFromDevice: Bool?
    public var phase: String?
    public var momentumPhase: String?

    public init(
        type: PublicGestureEventType,
        timestamp: TimeInterval,
        deltaX: Double? = nil,
        deltaY: Double? = nil,
        scrollingDeltaX: Double? = nil,
        scrollingDeltaY: Double? = nil,
        hasPreciseScrollingDeltas: Bool? = nil,
        isDirectionInvertedFromDevice: Bool? = nil,
        phase: String? = nil,
        momentumPhase: String? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.scrollingDeltaX = scrollingDeltaX
        self.scrollingDeltaY = scrollingDeltaY
        self.hasPreciseScrollingDeltas = hasPreciseScrollingDeltas
        self.isDirectionInvertedFromDevice = isDirectionInvertedFromDevice
        self.phase = phase
        self.momentumPhase = momentumPhase
    }
}

public struct GestureDiagnosticCounters: Equatable, Sendable {
    public private(set) var swipe = 0
    public private(set) var scrollWheel = 0
    public private(set) var beginGesture = 0
    public private(set) var endGesture = 0
    public private(set) var magnify = 0
    public private(set) var rotate = 0
    public private(set) var smartMagnify = 0

    public init() {}

    public mutating func increment(_ type: PublicGestureEventType) {
        switch type {
        case .swipe:
            swipe += 1
        case .scrollWheel:
            scrollWheel += 1
        case .beginGesture:
            beginGesture += 1
        case .endGesture:
            endGesture += 1
        case .magnify:
            magnify += 1
        case .rotate:
            rotate += 1
        case .smartMagnify:
            smartMagnify += 1
        }
    }
}

public struct GestureDiagnosticSnapshot: Equatable, Sendable {
    public var lastEventType: PublicGestureEventType?
    public var lastTimestamp: TimeInterval?
    public var lastDeltaX: Double?
    public var lastDeltaY: Double?
    public var lastPhase: String?
    public var lastMomentumPhase: String?
    public var lastScrollDeltaX: Double?
    public var lastScrollDeltaY: Double?
    public var lastScrollScrollingDeltaX: Double?
    public var lastScrollScrollingDeltaY: Double?
    public var accumulatedScrollDeltaX: Double
    public var accumulatedScrollDeltaY: Double
    public var lastScrollHasPreciseScrollingDeltas: Bool?
    public var lastScrollIsDirectionInvertedFromDevice: Bool?
    public var counters: GestureDiagnosticCounters

    public init(
        lastEventType: PublicGestureEventType? = nil,
        lastTimestamp: TimeInterval? = nil,
        lastDeltaX: Double? = nil,
        lastDeltaY: Double? = nil,
        lastPhase: String? = nil,
        lastMomentumPhase: String? = nil,
        lastScrollDeltaX: Double? = nil,
        lastScrollDeltaY: Double? = nil,
        lastScrollScrollingDeltaX: Double? = nil,
        lastScrollScrollingDeltaY: Double? = nil,
        accumulatedScrollDeltaX: Double = 0,
        accumulatedScrollDeltaY: Double = 0,
        lastScrollHasPreciseScrollingDeltas: Bool? = nil,
        lastScrollIsDirectionInvertedFromDevice: Bool? = nil,
        counters: GestureDiagnosticCounters = GestureDiagnosticCounters()
    ) {
        self.lastEventType = lastEventType
        self.lastTimestamp = lastTimestamp
        self.lastDeltaX = lastDeltaX
        self.lastDeltaY = lastDeltaY
        self.lastPhase = lastPhase
        self.lastMomentumPhase = lastMomentumPhase
        self.lastScrollDeltaX = lastScrollDeltaX
        self.lastScrollDeltaY = lastScrollDeltaY
        self.lastScrollScrollingDeltaX = lastScrollScrollingDeltaX
        self.lastScrollScrollingDeltaY = lastScrollScrollingDeltaY
        self.accumulatedScrollDeltaX = accumulatedScrollDeltaX
        self.accumulatedScrollDeltaY = accumulatedScrollDeltaY
        self.lastScrollHasPreciseScrollingDeltas = lastScrollHasPreciseScrollingDeltas
        self.lastScrollIsDirectionInvertedFromDevice = lastScrollIsDirectionInvertedFromDevice
        self.counters = counters
    }
}

public final class GestureDiagnosticState {
    public private(set) var snapshot = GestureDiagnosticSnapshot()

    public init() {}

    public func record(_ input: PublicGestureEventInput) {
        var counters = snapshot.counters
        counters.increment(input.type)
        var lastScrollDeltaX = snapshot.lastScrollDeltaX
        var lastScrollDeltaY = snapshot.lastScrollDeltaY
        var lastScrollScrollingDeltaX = snapshot.lastScrollScrollingDeltaX
        var lastScrollScrollingDeltaY = snapshot.lastScrollScrollingDeltaY
        var accumulatedScrollDeltaX = snapshot.accumulatedScrollDeltaX
        var accumulatedScrollDeltaY = snapshot.accumulatedScrollDeltaY
        var lastScrollHasPreciseScrollingDeltas = snapshot.lastScrollHasPreciseScrollingDeltas
        var lastScrollIsDirectionInvertedFromDevice = snapshot.lastScrollIsDirectionInvertedFromDevice

        if input.type == .scrollWheel {
            if Self.isBeginningScrollPhase(input.phase) {
                accumulatedScrollDeltaX = 0
                accumulatedScrollDeltaY = 0
            }

            lastScrollDeltaX = input.deltaX
            lastScrollDeltaY = input.deltaY
            lastScrollScrollingDeltaX = input.scrollingDeltaX
            lastScrollScrollingDeltaY = input.scrollingDeltaY
            lastScrollHasPreciseScrollingDeltas = input.hasPreciseScrollingDeltas
            lastScrollIsDirectionInvertedFromDevice = input.isDirectionInvertedFromDevice
            accumulatedScrollDeltaX += input.scrollingDeltaX ?? input.deltaX ?? 0
            accumulatedScrollDeltaY += input.scrollingDeltaY ?? input.deltaY ?? 0
        }

        snapshot = GestureDiagnosticSnapshot(
            lastEventType: input.type,
            lastTimestamp: input.timestamp,
            lastDeltaX: input.deltaX,
            lastDeltaY: input.deltaY,
            lastPhase: input.phase,
            lastMomentumPhase: input.momentumPhase,
            lastScrollDeltaX: lastScrollDeltaX,
            lastScrollDeltaY: lastScrollDeltaY,
            lastScrollScrollingDeltaX: lastScrollScrollingDeltaX,
            lastScrollScrollingDeltaY: lastScrollScrollingDeltaY,
            accumulatedScrollDeltaX: accumulatedScrollDeltaX,
            accumulatedScrollDeltaY: accumulatedScrollDeltaY,
            lastScrollHasPreciseScrollingDeltas: lastScrollHasPreciseScrollingDeltas,
            lastScrollIsDirectionInvertedFromDevice: lastScrollIsDirectionInvertedFromDevice,
            counters: counters
        )
    }

    private static func isBeginningScrollPhase(_ phase: String?) -> Bool {
        guard let phase = phase?.lowercased() else {
            return false
        }

        return phase.contains("began") || phase.contains("maybegin")
    }
}

public final class HorizontalSwipeRecognizer {
    private let minimumDelta: Double
    private let dominanceRatio: Double
    private let cooldown: TimeInterval
    private let invertDirection: Bool
    private var lastAcceptedTimestamp: TimeInterval?

    public init(
        minimumDelta: Double = 0.5,
        dominanceRatio: Double = 2.0,
        cooldown: TimeInterval = 0.35,
        invertDirection: Bool = false
    ) {
        self.minimumDelta = minimumDelta
        self.dominanceRatio = dominanceRatio
        self.cooldown = cooldown
        self.invertDirection = invertDirection
    }

    public func recognize(_ input: SwipeGestureInput) -> GestureRecognitionResult {
        let absX = abs(input.deltaX)
        let absY = abs(input.deltaY)

        guard absX >= minimumDelta else {
            return .ignored(.belowThreshold)
        }

        guard absX > absY * dominanceRatio else {
            return .ignored(.diagonal)
        }

        if let lastAcceptedTimestamp,
           input.timestamp - lastAcceptedTimestamp < cooldown {
            return .ignored(.cooldown)
        }

        lastAcceptedTimestamp = input.timestamp

        let isRightSwipe = invertDirection ? input.deltaX < 0 : input.deltaX > 0
        return .action(isRightSwipe ? .rightHalf : .leftHalf)
    }

    public func recognize(publicEvent input: PublicGestureEventInput) -> GestureRecognitionResult? {
        guard input.type == .swipe,
              let deltaX = input.deltaX,
              let deltaY = input.deltaY else {
            return nil
        }

        return recognize(
            SwipeGestureInput(
                deltaX: deltaX,
                deltaY: deltaY,
                timestamp: input.timestamp,
                source: .publicNSEventSwipe
            )
        )
    }
}
