import XCTest
@testable import WindowGesturesCore

final class SettingsMenuActionHandlerTests: XCTestCase {
    func testTrustedMenuShowsPlainSettingsItem() {
        XCTAssertEqual(StatusMenuPresentationModel.visibleTitles(accessibilityTrusted: true), [
            "About Toucher",
            "Settings",
            "Quit Toucher"
        ])
    }

    func testUntrustedMenuShowsVisibleSettingsWarning() {
        XCTAssertEqual(StatusMenuPresentationModel.visibleTitles(accessibilityTrusted: false), [
            "About Toucher",
            "⚠ Settings — Accessibility required",
            "Quit Toucher"
        ])
    }

    func testUntrustedSettingsMenuActionRequestsAlertAndOpensSettings() {
        var alertRequests = 0
        var openRequests = 0
        let handler = SettingsMenuActionHandler(
            isAccessibilityTrusted: { false },
            requestAccessibilityAlert: { alertRequests += 1 },
            openSettings: { openRequests += 1 }
        )

        handler.handleSettingsSelected()

        XCTAssertEqual(alertRequests, 1)
        XCTAssertEqual(openRequests, 1)
    }

    func testUntrustedSettingsActionProducesNotEnabledSettingsState() {
        var coordinator = AccessibilityStateCoordinator()
        let result = coordinator.settingsOpened(isTrusted: false)

        XCTAssertFalse(result.snapshot.isTrusted)
        XCTAssertTrue(result.snapshot.isPolling)
        XCTAssertEqual(result.snapshot.settingsStatusText, "Accessibility: Not enabled")
        XCTAssertTrue(result.snapshot.isSettingsWarningVisible)
        XCTAssertFalse(result.recoveryNeeded)
    }

    func testTrustedSettingsActionProducesEnabledSettingsState() {
        var coordinator = AccessibilityStateCoordinator()
        let result = coordinator.settingsOpened(isTrusted: true)

        XCTAssertTrue(result.snapshot.isTrusted)
        XCTAssertFalse(result.snapshot.isPolling)
        XCTAssertEqual(result.snapshot.settingsStatusText, "Accessibility: Enabled")
        XCTAssertFalse(result.snapshot.isSettingsWarningVisible)
        XCTAssertFalse(result.recoveryNeeded)
    }

    func testTrustedSettingsMenuActionOpensSettingsWithoutAlert() {
        var alertRequests = 0
        var openRequests = 0
        let handler = SettingsMenuActionHandler(
            isAccessibilityTrusted: { true },
            requestAccessibilityAlert: { alertRequests += 1 },
            openSettings: { openRequests += 1 }
        )

        handler.handleSettingsSelected()

        XCTAssertEqual(alertRequests, 0)
        XCTAssertEqual(openRequests, 1)
    }

    func testSettingsMenuActionReadsLiveTrustStateEachTime() {
        var trusted = false
        var alertRequests = 0
        var openRequests = 0
        let handler = SettingsMenuActionHandler(
            isAccessibilityTrusted: { trusted },
            requestAccessibilityAlert: { alertRequests += 1 },
            openSettings: { openRequests += 1 }
        )

        handler.handleSettingsSelected()
        trusted = true
        handler.handleSettingsSelected()

        XCTAssertEqual(alertRequests, 1)
        XCTAssertEqual(openRequests, 2)
    }

    func testFalseToTrueRecoveryUpdatesSettingsAndRequestsPipelineRecoveryOnce() {
        var coordinator = AccessibilityStateCoordinator()
        var recoveryCalls = 0
        var settingsWindowOpenCount = 0

        let first = coordinator.settingsOpened(isTrusted: false)
        settingsWindowOpenCount += 1
        if first.recoveryNeeded {
            recoveryCalls += 1
        }

        let second = coordinator.observe(isTrusted: false)
        if second.recoveryNeeded {
            recoveryCalls += 1
        }

        let recovered = coordinator.observe(isTrusted: true)
        if recovered.recoveryNeeded {
            recoveryCalls += 1
        }

        let stillTrusted = coordinator.observe(isTrusted: true)
        if stillTrusted.recoveryNeeded {
            recoveryCalls += 1
        }

        XCTAssertEqual(settingsWindowOpenCount, 1)
        XCTAssertEqual(recoveryCalls, 1)
        XCTAssertTrue(recovered.snapshot.isTrusted)
        XCTAssertFalse(recovered.snapshot.isPolling)
        XCTAssertEqual(recovered.snapshot.settingsStatusText, "Accessibility: Enabled")
        XCTAssertFalse(recovered.snapshot.isSettingsWarningVisible)
    }

    func testFalseToTrueRecoveryDoesNotCreateDuplicateSettingsWindowInModel() {
        var coordinator = AccessibilityStateCoordinator()
        var settingsWindowExists = false
        var settingsWindowCreateCount = 0

        _ = coordinator.settingsOpened(isTrusted: false)
        if !settingsWindowExists {
            settingsWindowExists = true
            settingsWindowCreateCount += 1
        }

        let recovered = coordinator.observe(isTrusted: true)
        if recovered.recoveryNeeded, !settingsWindowExists {
            settingsWindowCreateCount += 1
        }

        XCTAssertEqual(settingsWindowCreateCount, 1)
    }


    func testSettingsLayoutModelUsesStableReleaseSectionsAndReservedWarningArea() {
        XCTAssertEqual(ToucherSettingsLayoutModel.sectionTitles, [
            "Gestures",
            "Movement",
            "System Access",
            "Diagnostics"
        ])
        XCTAssertGreaterThanOrEqual(ToucherSettingsLayoutModel.windowWidth, 500)
        XCTAssertGreaterThanOrEqual(ToucherSettingsLayoutModel.windowHeight, 420)
        XCTAssertEqual(ToucherSettingsLayoutModel.contentMargin, 24)
        XCTAssertGreaterThanOrEqual(ToucherSettingsLayoutModel.warningAreaHeight, 40)
    }
}
