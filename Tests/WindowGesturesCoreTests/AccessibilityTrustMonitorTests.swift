import XCTest
@testable import WindowGesturesCore

final class AccessibilityTrustMonitorTests: XCTestCase {
    func testInitialTrustedDoesNotPoll() {
        var monitor = AccessibilityTrustMonitor()

        let snapshot = monitor.observe(isTrusted: true)

        XCTAssertTrue(snapshot.isTrusted)
        XCTAssertFalse(snapshot.waitingForAccessibility)
        XCTAssertFalse(snapshot.shouldPoll)
        XCTAssertEqual(snapshot.transitionCount, 0)
        XCTAssertEqual(snapshot.lastTransition, .none)
    }

    func testInitialUntrustedPolls() {
        var monitor = AccessibilityTrustMonitor()

        let snapshot = monitor.observe(isTrusted: false)

        XCTAssertFalse(snapshot.isTrusted)
        XCTAssertTrue(snapshot.waitingForAccessibility)
        XCTAssertTrue(snapshot.shouldPoll)
        XCTAssertEqual(snapshot.transitionCount, 0)
    }

    func testUntrustedToTrustedStopsPollingAndRecordsTransitionOnce() {
        var monitor = AccessibilityTrustMonitor()

        _ = monitor.observe(isTrusted: false)
        let recovered = monitor.observe(isTrusted: true)
        let stillTrusted = monitor.observe(isTrusted: true)

        XCTAssertTrue(recovered.isTrusted)
        XCTAssertFalse(recovered.waitingForAccessibility)
        XCTAssertFalse(recovered.shouldPoll)
        XCTAssertEqual(recovered.transitionCount, 1)
        XCTAssertEqual(recovered.lastTransition, .untrustedToTrusted)
        XCTAssertEqual(stillTrusted.transitionCount, 1)
        XCTAssertEqual(stillTrusted.lastTransition, .untrustedToTrusted)
    }

    func testTrustedToUntrustedStartsPollingAndRecordsTransition() {
        var monitor = AccessibilityTrustMonitor()

        _ = monitor.observe(isTrusted: true)
        let blocked = monitor.observe(isTrusted: false)

        XCTAssertFalse(blocked.isTrusted)
        XCTAssertTrue(blocked.waitingForAccessibility)
        XCTAssertTrue(blocked.shouldPoll)
        XCTAssertEqual(blocked.transitionCount, 1)
        XCTAssertEqual(blocked.lastTransition, .trustedToUntrusted)
    }

    func testMarkWaitingForAccessibilityStartsPolling() {
        var monitor = AccessibilityTrustMonitor()

        _ = monitor.observe(isTrusted: false)
        let waiting = monitor.markWaitingForAccessibility()

        XCTAssertTrue(waiting.waitingForAccessibility)
        XCTAssertTrue(waiting.shouldPoll)
    }

    func testPollingPolicyKeepsMonitoringWhileSettingsIsOpenEvenWhenTrusted() {
        XCTAssertTrue(AccessibilityPollingPolicy.shouldPoll(
            isTrusted: true,
            waitingForAccessibility: false,
            settingsWindowOpen: true
        ))
    }

    func testPollingPolicyPollsWhileUntrustedWaitingEvenWhenSettingsIsClosed() {
        XCTAssertTrue(AccessibilityPollingPolicy.shouldPoll(
            isTrusted: false,
            waitingForAccessibility: true,
            settingsWindowOpen: false
        ))
    }

    func testPollingPolicyStopsWhenTrustedAndSettingsIsClosed() {
        XCTAssertFalse(AccessibilityPollingPolicy.shouldPoll(
            isTrusted: true,
            waitingForAccessibility: false,
            settingsWindowOpen: false
        ))
    }

    func testPermissionEvaluatorDeniesWhenProcessTrustIsFalse() {
        XCTAssertFalse(AccessibilityPermissionEvaluator.isTrusted(
            processTrusted: false,
            probeResult: .allowed
        ))
    }

    func testPermissionEvaluatorDeniesWhenFocusedApplicationProbeIsDenied() {
        XCTAssertFalse(AccessibilityPermissionEvaluator.isTrusted(
            processTrusted: true,
            probeResult: .denied
        ))
    }

    func testPermissionEvaluatorAllowsWhenProbeIsAllowed() {
        XCTAssertTrue(AccessibilityPermissionEvaluator.isTrusted(
            processTrusted: true,
            probeResult: .allowed
        ))
    }

    func testPermissionEvaluatorTreatsInconclusiveProbeAsTrustedToAvoidTransientFalseNegative() {
        XCTAssertTrue(AccessibilityPermissionEvaluator.isTrusted(
            processTrusted: true,
            probeResult: .inconclusive
        ))
    }
}
