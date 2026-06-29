import Foundation

public enum AccessibilityTrustTransition: String, Equatable, Sendable {
    case none
    case trustedToUntrusted
    case untrustedToTrusted
}

public struct AccessibilityTrustMonitorSnapshot: Equatable, Sendable {
    public var isTrusted: Bool
    public var waitingForAccessibility: Bool
    public var transitionCount: Int
    public var lastTransition: AccessibilityTrustTransition
    public var shouldPoll: Bool

    public init(
        isTrusted: Bool,
        waitingForAccessibility: Bool,
        transitionCount: Int,
        lastTransition: AccessibilityTrustTransition,
        shouldPoll: Bool
    ) {
        self.isTrusted = isTrusted
        self.waitingForAccessibility = waitingForAccessibility
        self.transitionCount = transitionCount
        self.lastTransition = lastTransition
        self.shouldPoll = shouldPoll
    }
}

public struct AccessibilityTrustMonitor: Equatable, Sendable {
    private var lastTrusted: Bool?
    private var waitingForAccessibility = false
    private var transitionCount = 0
    private var lastTransition: AccessibilityTrustTransition = .none

    public init() {}

    public mutating func markWaitingForAccessibility() -> AccessibilityTrustMonitorSnapshot {
        waitingForAccessibility = true
        return snapshot(isTrusted: lastTrusted ?? false)
    }

    public mutating func observe(isTrusted: Bool) -> AccessibilityTrustMonitorSnapshot {
        if let lastTrusted, lastTrusted != isTrusted {
            transitionCount += 1
            lastTransition = isTrusted ? .untrustedToTrusted : .trustedToUntrusted
        }

        lastTrusted = isTrusted
        waitingForAccessibility = !isTrusted
        return snapshot(isTrusted: isTrusted)
    }

    private func snapshot(isTrusted: Bool) -> AccessibilityTrustMonitorSnapshot {
        AccessibilityTrustMonitorSnapshot(
            isTrusted: isTrusted,
            waitingForAccessibility: waitingForAccessibility,
            transitionCount: transitionCount,
            lastTransition: lastTransition,
            shouldPoll: waitingForAccessibility && !isTrusted
        )
    }
}

public enum AccessibilityPollingPolicy {
    public static func shouldPoll(
        isTrusted: Bool,
        waitingForAccessibility: Bool,
        settingsWindowOpen: Bool
    ) -> Bool {
        settingsWindowOpen || (waitingForAccessibility && !isTrusted)
    }
}

public enum AccessibilityPermissionProbeResult: Equatable, Sendable {
    case allowed
    case denied
    case inconclusive
}

public enum AccessibilityPermissionEvaluator {
    public static func isTrusted(
        processTrusted: Bool,
        probeResult: AccessibilityPermissionProbeResult
    ) -> Bool {
        guard processTrusted else {
            return false
        }

        switch probeResult {
        case .allowed, .inconclusive:
            return true
        case .denied:
            return false
        }
    }
}
