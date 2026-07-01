import Foundation

public enum BuildInfo {
    public static let appName = "Toucher"
    public static let version = "0.5.8"
    public static let bundleIdentifier = "com.amilabs.Toucher"
    public static let repositoryURL = "https://github.com/amilabs/Toucher"
    public static let repositoryDisplayText = "GitHub Repository"
    public static let repositoryOpenURL = "https://github.com/amilabs/Toucher?utm_source=toucher_app&utm_medium=about_window&utm_campaign=app_about"

    public static var buildDate: String {
        buildDate(from: Bundle.main)
    }

    public static func buildDate(from bundle: Bundle) -> String {
        if let value = bundle.object(forInfoDictionaryKey: "ToucherBuildDate") as? String,
           !value.isEmpty {
            return value
        }

        return "1970-01-01 00:00"
    }
}

public struct AboutToucherModel: Equatable, Sendable {
    public var appName: String
    public var version: String
    public var buildDate: String
    public var repositoryDisplayText: String
    public var repositoryOpenURL: String
    public var description: String
    public var copyright: String

    public init(
        appName: String = BuildInfo.appName,
        version: String = BuildInfo.version,
        buildDate: String = BuildInfo.buildDate,
        repositoryDisplayText: String = BuildInfo.repositoryDisplayText,
        repositoryOpenURL: String = BuildInfo.repositoryOpenURL,
        description: String = "Lightweight macOS window control with hotkeys and trackpad gestures.",
        copyright: String = "© Amilabs"
    ) {
        self.appName = appName
        self.version = version
        self.buildDate = buildDate
        self.repositoryDisplayText = repositoryDisplayText
        self.repositoryOpenURL = repositoryOpenURL
        self.description = description
        self.copyright = copyright
    }
}

public enum ToucherMainMenuModel {
    public static func userFacingTitles(accessibilityTrusted: Bool = true) -> [String] {
        StatusMenuPresentationModel.visibleTitles(accessibilityTrusted: accessibilityTrusted)
    }

    public static func accessibilityTitle(isTrusted: Bool) -> String {
        StatusMenuPresentationModel.settingsTitle(accessibilityTrusted: isTrusted)
    }
}

public enum ToucherSettingsModel {
    public static let visibleControlTitles = [
        "Enable trackpad gestures",
        "Animate window movement",
        "Animation steps",
        "Animation duration",
        "Accessibility Settings…",
        "Gesture Diagnostics…"
    ]

    public static let hiddenTechnicalControlTitles = [
        "Gesture backend",
        "Enable diagnostics/probe",
        "Invert gesture direction",
        "Raw gesture minimum distance",
        "Raw gesture dominance ratio",
        "Raw gesture cooldown"
    ]

    public static let animationStepRange = 3...32
    public static let animationDurationRange = 0.02...0.60
}

public enum ToucherMenuPolicy {
    public static let requiredTitles = [
        "About Toucher",
        "Settings",
        "Quit Toucher"
    ]

    public static let debugOnlyFragments = [
        "Status",
        "Gesture backend",
        "Raw multitouch active",
        "Accessibility trusted",
        "Toucher version:",
        "App bundle id:",
        "App bundle path:",
        "build path",
        "Last movement",
        "movement kind",
        "steps planned",
        "steps applied",
        "Raw devices",
        "Active touches",
        "Last raw",
        "Last public",
        "Event counters",
        "scroll"
    ]
}
