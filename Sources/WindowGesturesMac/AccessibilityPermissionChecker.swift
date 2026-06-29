import AppKit
import ApplicationServices
import WindowGesturesCore

public struct AccessibilityTrustProvider: PermissionChecking {
    public init() {}

    public var hasAccessibilityPermission: Bool {
        AccessibilityPermissionEvaluator.isTrusted(
            processTrusted: AXIsProcessTrusted(),
            probeResult: focusedApplicationProbeResult()
        )
    }

    public func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]

        for value in urls {
            guard let url = URL(string: value), NSWorkspace.shared.open(url) else {
                continue
            }

            return
        }
    }

    private func focusedApplicationProbeResult() -> AccessibilityPermissionProbeResult {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApplication: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApplication
        )

        switch result {
        case .success:
            return .allowed
        case .apiDisabled, .failure, .illegalArgument:
            return .denied
        case .cannotComplete, .noValue:
            return .inconclusive
        default:
            return .denied
        }
    }
}

public typealias AccessibilityPermissionChecker = AccessibilityTrustProvider
