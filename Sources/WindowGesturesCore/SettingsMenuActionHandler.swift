public struct SettingsMenuActionHandler {
    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibilityAlert: () -> Void
    private let openSettings: () -> Void

    public init(
        isAccessibilityTrusted: @escaping () -> Bool,
        requestAccessibilityAlert: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibilityAlert = requestAccessibilityAlert
        self.openSettings = openSettings
    }

    public func handleSettingsSelected() {
        if !isAccessibilityTrusted() {
            requestAccessibilityAlert()
        }
        openSettings()
    }
}

public enum StatusMenuPresentationModel {
    public static func visibleTitles(accessibilityTrusted: Bool) -> [String] {
        [
            "About Toucher",
            settingsTitle(accessibilityTrusted: accessibilityTrusted),
            "Quit Toucher"
        ]
    }

    public static func settingsTitle(accessibilityTrusted: Bool) -> String {
        accessibilityTrusted ? "Settings" : "⚠ Settings — Accessibility required"
    }
}

public struct AccessibilityRecoverySnapshot: Equatable, Sendable {
    public var isTrusted: Bool
    public var isPolling: Bool
    public var settingsStatusText: String
    public var isSettingsWarningVisible: Bool

    public init(
        isTrusted: Bool,
        isPolling: Bool,
        settingsStatusText: String,
        isSettingsWarningVisible: Bool
    ) {
        self.isTrusted = isTrusted
        self.isPolling = isPolling
        self.settingsStatusText = settingsStatusText
        self.isSettingsWarningVisible = isSettingsWarningVisible
    }
}

public struct AccessibilityStateCoordinator {
    private var monitor = AccessibilityTrustMonitor()
    private var handledTransitionCount = 0
    private var lastSnapshot = AccessibilityRecoverySnapshot(
        isTrusted: false,
        isPolling: false,
        settingsStatusText: "Accessibility: Not enabled",
        isSettingsWarningVisible: true
    )

    public init() {}

    public mutating func settingsOpened(isTrusted: Bool) -> (snapshot: AccessibilityRecoverySnapshot, recoveryNeeded: Bool) {
        observe(isTrusted: isTrusted)
    }

    public mutating func observe(isTrusted: Bool) -> (snapshot: AccessibilityRecoverySnapshot, recoveryNeeded: Bool) {
        let trustSnapshot = monitor.observe(isTrusted: isTrusted)
        let transitionIsNew = trustSnapshot.transitionCount != handledTransitionCount
        let recoveryNeeded = transitionIsNew && trustSnapshot.lastTransition == .untrustedToTrusted
        if transitionIsNew {
            handledTransitionCount = trustSnapshot.transitionCount
        }
        lastSnapshot = AccessibilityRecoverySnapshot(
            isTrusted: trustSnapshot.isTrusted,
            isPolling: trustSnapshot.shouldPoll,
            settingsStatusText: trustSnapshot.isTrusted ? "Accessibility: Enabled" : "Accessibility: Not enabled",
            isSettingsWarningVisible: !trustSnapshot.isTrusted
        )
        return (lastSnapshot, recoveryNeeded)
    }

    public var snapshot: AccessibilityRecoverySnapshot {
        lastSnapshot
    }
}

public enum ToucherSettingsLayoutModel {
    public static let windowWidth = 540
    public static let windowHeight = 500
    public static let contentMargin = 24
    public static let sectionSpacing = 24
    public static let rowSpacing = 10
    public static let warningAreaHeight = 42

    public static let sectionTitles = [
        "Gestures",
        "Movement",
        "System Access",
        "Diagnostics"
    ]
}
