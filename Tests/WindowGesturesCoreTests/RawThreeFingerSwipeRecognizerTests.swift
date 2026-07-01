import XCTest
@testable import WindowGesturesCore

final class RawThreeFingerSwipeRecognizerTests: XCTestCase {
    func testStableThreeFingersMovingRightReturnsRightHalf() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
    }

    func testStableThreeFingersMovingLeftReturnsLeftHalf() {
        let recognizer = recognizer()

        enterPendingLeft(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 60, y: 100, t: 1.14)), .action(.leftHalf))
    }

    func testStableThreeFingersMovingUpReturnsMaximize() {
        let recognizer = recognizer()

        enterPendingUp(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 140, t: 1.14)), .action(.maximize))
    }

    func testStableThreeFingersMovingUpDoesNotReturnVerticalMaxCenterThird() {
        let recognizer = recognizer()

        enterPendingUp(recognizer)
        XCTAssertNotEqual(
            recognizer.recognize(sample(count: 3, x: 100, y: 140, t: 1.14)),
            .action(.verticalMaxCenterThird)
        )
    }

    func testTwoFingersMovingUpAreIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 100, y: 100, t: 1)), .ignored(.unsupportedFingerCount))
    }

    func testFourFingersMovingUpAreIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 4, x: 100, y: 100, t: 1)), .ignored(.unsupportedFingerCount))
    }

    func testFingerCountChangeCancelsGestureUntilFullLift() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 130, y: 100, t: 1.1)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.2)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.3)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.4)), .ignored(.tracking))
    }

    func testHorizontalMovementIsNotRecognizedAsUp() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
    }

    func testDiagonalMovementIsIgnored() {
        let recognizer = recognizer()

        startCandidate(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 120, t: 1.06)), .ignored(.diagonal))
    }

    func testShortMovementIsIgnored() {
        let recognizer = recognizer()

        startCandidate(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 105, y: 101, t: 1.06)), .ignored(.belowThreshold))
    }

    func testShortVerticalMovementIsIgnored() {
        let recognizer = recognizer()

        startCandidate(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 101, y: 105, t: 1.06)), .ignored(.belowThreshold))
    }

    func testSlowMovementBeyondMaxDurationIsIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 2)), .ignored(.tooSlow))
    }

    func testSlowUpMovementBeyondMaxDurationIsIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 140, t: 2)), .ignored(.tooSlow))
    }

    func testDuplicateCallbacksAfterTriggerAreIgnored() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 145, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
    }

    func testActionFiresOncePerPhysicalGesture() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 160, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.3)), .ignored(.unsupportedFingerCount))
    }

    func testCooldownPreventsDuplicateActionAfterGestureEnds() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.2)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 200, y: 100, t: 1.3)), .ignored(.cooldown))
    }

    func testUpGestureFiresOncePerPhysicalGesture() {
        let recognizer = recognizer()

        enterPendingUp(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 140, t: 1.14)), .action(.maximize))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 160, t: 1.2)), .ignored(.alreadyTriggered))
    }

    func testCooldownSuppressesDuplicateUpGesture() {
        let recognizer = recognizer()

        enterPendingUp(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 140, t: 1.14)), .action(.maximize))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.2)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 200, t: 1.3)), .ignored(.cooldown))
    }

    func testDirectionInversionWorks() {
        let recognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35,
            invertDirection: true
        )

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.leftHalf))
    }

    func testVerticalDirectionInversionWorks() {
        let recognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35,
            invertVerticalDirection: true
        )

        enterPendingDown(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 60, t: 1.14)), .action(.maximize))
    }

    func testUnsupportedFingerCountDoesNotOverwriteAcceptedDiagnostics() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
        let acceptedDiagnostics = recognizer.diagnostics

        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 140, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
        XCTAssertEqual(recognizer.diagnostics.lastGestureAccepted, acceptedDiagnostics.lastGestureAccepted)
        XCTAssertEqual(recognizer.diagnostics.lastGestureDuration, acceptedDiagnostics.lastGestureDuration)
        XCTAssertEqual(recognizer.diagnostics.lastAcceptedActiveTouchCount, 3)
    }

    func testExactlyThreeFingerRejectionUpdatesDiagnostics() {
        let recognizer = recognizer()

        startCandidate(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 105, y: 101, t: 1.06)), .ignored(.belowThreshold))

        XCTAssertEqual(recognizer.diagnostics.lastGestureAccepted, false)
        XCTAssertEqual(recognizer.diagnostics.lastRejectionReason, .belowThreshold)
        XCTAssertEqual(recognizer.diagnostics.lastGestureDuration ?? -1, 0.06, accuracy: 0.0001)
    }

    func testTwoFingerHorizontalMovementDoesNotTrigger() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 100, y: 100, t: 1.0)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 60, y: 101, t: 1.1)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 30, y: 102, t: 1.2)), .ignored(.unsupportedFingerCount))
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testTwoFingerVerticalMovementDoesNotTriggerMaximize() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 100, y: 100, t: 1.0)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 101, y: 140, t: 1.1)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 102, y: 180, t: 1.2)), .ignored(.unsupportedFingerCount))
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testLongTwoFingerScrollLikeSequenceDoesNotStartCandidate() {
        let recognizer = recognizer()

        for index in 0..<30 {
            let result = recognizer.recognize(
                sample(count: 2, x: 100 + Double(index * 6), y: 100 + Double(index), t: 1 + Double(index) * 0.03)
            )
            XCTAssertEqual(result, .ignored(.unsupportedFingerCount))
        }

        XCTAssertEqual(recognizer.diagnostics.recognizerState, .idle)
        XCTAssertNil(recognizer.diagnostics.candidateStartTouchCount)
        XCTAssertEqual(recognizer.diagnostics.candidateSampleCount, 0)
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testTwoToThreeToTwoBriefTransitionDoesNotTrigger() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 100, y: 100, t: 1.00)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.01)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 70, y: 100, t: 1.03)), .ignored(.fingerCountChanged))

        XCTAssertEqual(recognizer.diagnostics.recognizerState, .canceled)
        XCTAssertEqual(recognizer.diagnostics.candidateCanceledReason, .fingerCountChanged)
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testThreeToTwoBeforeThresholdCancelsAndNeverTriggers() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.0)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 105, y: 100, t: 1.05)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 40, y: 100, t: 1.10)), .ignored(.fingerCountChanged))

        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testThreeToFourCancelsAndNeverTriggers() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.0)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 4, x: 140, y: 100, t: 1.1)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 4, x: 180, y: 100, t: 1.2)), .ignored(.fingerCountChanged))

        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testAfterCancelReturningToThreeWithoutFullLiftDoesNotStartCandidate() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.0)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 105, y: 100, t: 1.1)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 60, y: 100, t: 1.2)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 20, y: 100, t: 1.3)), .ignored(.fingerCountChanged))

        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testAfterFullLiftFreshThreeFingerGestureCanTrigger() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.0)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 105, y: 100, t: 1.1)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.2)), .ignored(.unsupportedFingerCount))
        enterPendingLeft(recognizer, startTime: 1.3)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 60, y: 100, t: 1.44)), .action(.leftHalf))
    }

    func testAcceptedGestureThenTwoFingerScrollDoesNotTriggerAnotherAction() {
        let recognizer = recognizer()

        enterPendingLeft(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 60, y: 100, t: 1.14)), .action(.leftHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 20, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: -20, y: 100, t: 1.3)), .ignored(.alreadyTriggered))
    }

    func testCanceledGestureThenTwoFingerMovementDoesNotTrigger() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.0)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 100, y: 100, t: 1.1)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 30, y: 100, t: 1.2)), .ignored(.fingerCountChanged))
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testAlreadyTriggeredStateCannotTriggerAgainUntilAllTouchesLift() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 60, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 20, y: 100, t: 1.3)), .ignored(.alreadyTriggered))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.4)), .ignored(.unsupportedFingerCount))
    }

    func testThresholdCrossedWithFewerThanFourSamplesDoesNotTrigger() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.00)), .ignored(.tracking))
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.02)),
            .ignored(.insufficientStableSamples)
        )
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testValidGestureRequiresMinimumCandidateAgeBeforePending() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1.000)), .ignored(.tracking))
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.010)),
            .ignored(.insufficientStableSamples)
        )
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.020)),
            .ignored(.insufficientStableSamples)
        )
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 150, y: 100, t: 1.040)),
            .ignored(.insufficientStableSamples)
        )
        XCTAssertNotEqual(recognizer.diagnostics.recognizerState, .triggered)
    }

    func testPendingTriggerRequiresConfirmationDelay() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 135, y: 100, t: 1.10)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))
    }

    func testThreeCrossesThresholdThenTwoBeforeConfirmationCancels() {
        let recognizer = recognizer()

        enterPendingLeft(recognizer)
        XCTAssertEqual(
            recognizer.recognize(sample(count: 2, x: 60, y: 100, t: 1.08)),
            .ignored(.fingerCountChangedBeforeConfirmation)
        )
        XCTAssertEqual(recognizer.diagnostics.candidateCanceledReason, .fingerCountChangedBeforeConfirmation)
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testThreeCrossesThresholdThenLiftOffBeforeConfirmationCancels() {
        let recognizer = recognizer()

        enterPendingLeft(recognizer)
        XCTAssertEqual(
            recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.08)),
            .ignored(.liftedBeforeConfirmation)
        )
        XCTAssertEqual(recognizer.diagnostics.candidateCanceledReason, .liftedBeforeConfirmation)
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testPendingLeftChangingToDiagonalBeforeConfirmationCancels() {
        let recognizer = recognizer()

        enterPendingLeft(recognizer)
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 68, y: 80, t: 1.10)),
            .ignored(.directionChangedBeforeConfirmation)
        )
        XCTAssertEqual(recognizer.diagnostics.candidateCanceledReason, .directionChangedBeforeConfirmation)
        XCTAssertNil(recognizer.diagnostics.lastAcceptedActiveTouchCount)
    }

    func testPendingLeftChangingToRightBeforeConfirmationCancels() {
        let recognizer = recognizer()

        enterPendingLeft(recognizer)
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.10)),
            .ignored(.directionChangedBeforeConfirmation)
        )
        XCTAssertEqual(recognizer.diagnostics.candidateCanceledReason, .directionChangedBeforeConfirmation)
    }

    func testAcceptedGestureDiagnosticsRecordExactlyThreeTouches() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 140, y: 100, t: 1.14)), .action(.rightHalf))

        XCTAssertEqual(recognizer.diagnostics.lastAcceptedActiveTouchCount, 3)
        XCTAssertEqual(recognizer.diagnostics.recognizerState, .triggered)
    }

    func testPendingDiagnosticsExposeActionAndThresholdTime() {
        let recognizer = recognizer()

        enterPendingRight(recognizer)

        XCTAssertEqual(recognizer.diagnostics.recognizerState, .pendingTrigger)
        XCTAssertEqual(recognizer.diagnostics.pendingAction, .rightHalf)
        XCTAssertEqual(recognizer.diagnostics.thresholdCrossedTimestamp, 1.06)
        XCTAssertEqual(recognizer.diagnostics.confirmationDelay, 0.070, accuracy: 0.0001)
        XCTAssertEqual(recognizer.diagnostics.candidateSampleCount, 4)
    }

    private func recognizer() -> RawThreeFingerSwipeRecognizer {
        RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35,
            invertDirection: false
        )
    }

    private func startCandidate(_ recognizer: RawThreeFingerSwipeRecognizer, startTime: TimeInterval = 1.0) {
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: startTime)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 102, y: 100, t: startTime + 0.02)), .ignored(.belowThreshold))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 104, y: 100, t: startTime + 0.04)), .ignored(.belowThreshold))
    }

    private func enterPendingRight(_ recognizer: RawThreeFingerSwipeRecognizer, startTime: TimeInterval = 1.0) {
        startCandidate(recognizer, startTime: startTime)
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 130, y: 100, t: startTime + 0.06)),
            .ignored(.tracking)
        )
        XCTAssertEqual(recognizer.diagnostics.recognizerState, .pendingTrigger)
    }

    private func enterPendingLeft(_ recognizer: RawThreeFingerSwipeRecognizer, startTime: TimeInterval = 1.0) {
        startCandidate(recognizer, startTime: startTime)
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 70, y: 100, t: startTime + 0.06)),
            .ignored(.tracking)
        )
        XCTAssertEqual(recognizer.diagnostics.recognizerState, .pendingTrigger)
    }

    private func enterPendingUp(_ recognizer: RawThreeFingerSwipeRecognizer, startTime: TimeInterval = 1.0) {
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: startTime)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 102, t: startTime + 0.02)), .ignored(.belowThreshold))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 104, t: startTime + 0.04)), .ignored(.belowThreshold))
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 100, y: 130, t: startTime + 0.06)),
            .ignored(.tracking)
        )
        XCTAssertEqual(recognizer.diagnostics.recognizerState, .pendingTrigger)
    }

    private func enterPendingDown(_ recognizer: RawThreeFingerSwipeRecognizer, startTime: TimeInterval = 1.0) {
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: startTime)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 98, t: startTime + 0.02)), .ignored(.belowThreshold))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 96, t: startTime + 0.04)), .ignored(.belowThreshold))
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 100, y: 70, t: startTime + 0.06)),
            .ignored(.tracking)
        )
        XCTAssertEqual(recognizer.diagnostics.recognizerState, .pendingTrigger)
    }

    private func sample(count: Int, x: Double, y: Double, t: TimeInterval) -> RawTouchSample {
        RawTouchSample(activeTouchCount: count, centroidX: x, centroidY: y, timestamp: t)
    }
}
