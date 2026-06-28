import AppKit
import WindowGesturesCore

public final class PublicNSEventSwipeBackend: GestureMonitoring {
    private static let monitoredEvents: NSEvent.EventTypeMask = [
        .swipe,
        .beginGesture,
        .endGesture,
        .magnify,
        .rotate,
        .smartMagnify,
        .scrollWheel
    ]

    // NSEvent returns opaque monitor tokens that must be strongly retained until stop().
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let handleInput: (PublicGestureEventInput) -> Void

    public private(set) var isActive = false

    public init(handleInput: @escaping (PublicGestureEventInput) -> Void) {
        self.handleInput = handleInput
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isActive else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.monitoredEvents) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.monitoredEvents) { [weak self] event in
            self?.handle(event)
            return event
        }

        isActive = globalMonitor != nil || localMonitor != nil
    }

    public func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        isActive = false
    }

    private func handle(_ event: NSEvent) {
        guard let type = PublicGestureEventType(event.type) else {
            return
        }
        let isScrollWheel = type == .scrollWheel

        handleInput(
            PublicGestureEventInput(
                type: type,
                timestamp: event.timestamp,
                deltaX: Double(event.deltaX),
                deltaY: Double(event.deltaY),
                scrollingDeltaX: isScrollWheel ? Double(event.scrollingDeltaX) : nil,
                scrollingDeltaY: isScrollWheel ? Double(event.scrollingDeltaY) : nil,
                hasPreciseScrollingDeltas: isScrollWheel ? event.hasPreciseScrollingDeltas : nil,
                isDirectionInvertedFromDevice: isScrollWheel ? event.isDirectionInvertedFromDevice : nil,
                phase: event.phase.debugDescriptionOrNil,
                momentumPhase: event.momentumPhase.debugDescriptionOrNil
            )
        )
    }
}

private extension PublicGestureEventType {
    init?(_ eventType: NSEvent.EventType) {
        switch eventType {
        case .swipe:
            self = .swipe
        case .beginGesture:
            self = .beginGesture
        case .endGesture:
            self = .endGesture
        case .magnify:
            self = .magnify
        case .rotate:
            self = .rotate
        case .smartMagnify:
            self = .smartMagnify
        case .scrollWheel:
            self = .scrollWheel
        default:
            return nil
        }
    }
}

private extension NSEvent.Phase {
    var debugDescriptionOrNil: String? {
        guard !isEmpty else {
            return nil
        }

        var values: [String] = []
        if contains(.mayBegin) {
            values.append("mayBegin")
        }
        if contains(.began) {
            values.append("began")
        }
        if contains(.stationary) {
            values.append("stationary")
        }
        if contains(.changed) {
            values.append("changed")
        }
        if contains(.ended) {
            values.append("ended")
        }
        if contains(.cancelled) {
            values.append("cancelled")
        }

        if values.isEmpty {
            return "raw:\(rawValue)"
        }

        return values.joined(separator: "|")
    }
}
