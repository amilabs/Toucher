import XCTest
@testable import WindowGesturesCore

final class BuildInfoTests: XCTestCase {
    func testAboutModelContainsReleaseInformation() {
        let model = AboutToucherModel(buildDate: "2026-06-29 12:00")

        XCTAssertEqual(model.appName, "Toucher")
        XCTAssertEqual(model.version, "0.5.7")
        XCTAssertEqual(model.repositoryDisplayText, "GitHub Repository")
        XCTAssertFalse(model.repositoryDisplayText.contains("utm_"))
        XCTAssertTrue(model.repositoryOpenURL.contains("utm_source=toucher_app"))
        XCTAssertTrue(model.repositoryOpenURL.contains("utm_medium=about_window"))
        XCTAssertTrue(model.repositoryOpenURL.contains("utm_campaign=app_about"))
        XCTAssertFalse(model.buildDate.isEmpty)
        XCTAssertTrue(model.description.contains("macOS window control"))

        let visibleAboutText = [
            model.appName,
            model.version,
            model.buildDate,
            model.repositoryDisplayText,
            model.description,
            model.copyright
        ].joined(separator: "\n")
        XCTAssertFalse(visibleAboutText.contains(BuildInfo.bundleIdentifier))
    }

    func testBuildDateFallbackIsFormattedAndNonEmpty() {
        let buildDate = BuildInfo.buildDate(from: Bundle(for: BuildInfoTests.self))

        XCTAssertFalse(buildDate.isEmpty)
        XCTAssertNotNil(buildDate.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$"#, options: .regularExpression))
    }

    func testMainMenuModelIncludesUserFacingItems() {
        let titles = ToucherMainMenuModel.userFacingTitles()

        XCTAssertEqual(titles.first, "About Toucher")
        XCTAssertEqual(titles, ["About Toucher", "Settings", "Quit Toucher"])
        XCTAssertTrue(titles.contains("Settings"))
        XCTAssertTrue(titles.contains("About Toucher"))
        XCTAssertTrue(titles.contains("Quit Toucher"))
        XCTAssertFalse(titles.contains("Gesture Diagnostics"))
        XCTAssertFalse(titles.contains("Accessibility Settings"))
        XCTAssertFalse(titles.contains("⚠️ Enable Accessibility Access"))
    }

    func testMainMenuModelExcludesDebugOnlyRows() {
        let titles = ToucherMainMenuModel.userFacingTitles().joined(separator: "\n")

        for fragment in ToucherMenuPolicy.debugOnlyFragments {
            XCTAssertFalse(titles.contains(fragment), "Main menu should not contain \(fragment)")
        }
    }

    func testAccessibilityMenuTitleDependsOnTrustState() {
        XCTAssertEqual(ToucherMainMenuModel.accessibilityTitle(isTrusted: true), "Settings")
        XCTAssertEqual(ToucherMainMenuModel.accessibilityTitle(isTrusted: false), "⚠ Settings — Accessibility required")
        XCTAssertEqual(ToucherMainMenuModel.userFacingTitles(accessibilityTrusted: false), [
            "About Toucher",
            "⚠ Settings — Accessibility required",
            "Quit Toucher"
        ])
    }

    func testSettingsModelHidesTechnicalControls() {
        XCTAssertTrue(ToucherSettingsModel.visibleControlTitles.contains("Enable trackpad gestures"))
        XCTAssertTrue(ToucherSettingsModel.visibleControlTitles.contains("Animate window movement"))
        XCTAssertTrue(ToucherSettingsModel.visibleControlTitles.contains("Animation steps"))
        XCTAssertTrue(ToucherSettingsModel.visibleControlTitles.contains("Animation duration"))
        XCTAssertTrue(ToucherSettingsModel.visibleControlTitles.contains("Accessibility Settings…"))
        XCTAssertTrue(ToucherSettingsModel.visibleControlTitles.contains("Gesture Diagnostics…"))
        XCTAssertTrue(ToucherSettingsModel.hiddenTechnicalControlTitles.contains("Gesture backend"))
        XCTAssertEqual(ToucherSettingsModel.animationStepRange, 3...32)
        XCTAssertEqual(ToucherSettingsModel.animationDurationRange, 0.02...0.60)
    }
}
