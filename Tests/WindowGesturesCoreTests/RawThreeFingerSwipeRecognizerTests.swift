import XCTest
@testable import WindowGesturesCore

final class RawThreeFingerSwipeRecognizerTests: XCTestCase {
    func testExactlyThreeFingersMovingRightReturnsRightHalf() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 102, t: 1.1)), .action(.rightHalf))
    }

    func testExactlyThreeFingersMovingLeftReturnsLeftHalf() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 70, y: 102, t: 1.1)), .action(.leftHalf))
    }

    func testExactlyThreeFingersMovingUpReturnsMaximize() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 102, y: 130, t: 1.1)),
            .action(.maximize)
        )
    }

    func testExactlyThreeFingersMovingUpDoesNotReturnVerticalMaxCenterThird() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertNotEqual(
            recognizer.recognize(sample(count: 3, x: 102, y: 130, t: 1.1)),
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

    func testFingerCountChangeCancelsGesture() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 130, y: 100, t: 1.1)), .ignored(.fingerCountChanged))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.2)), .ignored(.tracking))
    }

    func testHorizontalMovementIsNotRecognizedAsUp() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 102, t: 1.1)), .action(.rightHalf))
    }

    func testDiagonalMovementIsIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 120, t: 1.1)), .ignored(.diagonal))
    }

    func testShortMovementIsIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 105, y: 101, t: 1.1)), .ignored(.belowThreshold))
    }

    func testShortVerticalMovementIsIgnored() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 101, y: 105, t: 1.1)), .ignored(.belowThreshold))
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

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.1)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 145, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
    }

    func testActionFiresOncePerPhysicalGesture() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.1)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 160, y: 100, t: 1.2)), .ignored(.alreadyTriggered))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.3)), .ignored(.unsupportedFingerCount))
    }

    func testCooldownPreventsDuplicateActionAfterGestureEnds() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.1)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(sample(count: 0, x: 0, y: 0, t: 1.2)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 200, y: 100, t: 1.3)), .ignored(.cooldown))
    }

    func testUpGestureFiresOncePerPhysicalGesture() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 130, t: 1.1)), .action(.maximize))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 160, t: 1.2)), .ignored(.alreadyTriggered))
    }

    func testCooldownSuppressesDuplicateUpGesture() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 130, t: 1.1)), .action(.maximize))
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

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 102, t: 1.1)), .action(.leftHalf))
    }

    func testVerticalDirectionInversionWorks() {
        let recognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: 10,
            dominanceRatio: 2,
            maxGestureDuration: 0.8,
            cooldown: 0.35,
            invertVerticalDirection: true
        )

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(
            recognizer.recognize(sample(count: 3, x: 102, y: 70, t: 1.1)),
            .action(.maximize)
        )
    }

    func testUnsupportedFingerCountDoesNotOverwriteAcceptedDiagnostics() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 130, y: 100, t: 1.1)), .action(.rightHalf))
        let acceptedDiagnostics = recognizer.diagnostics

        XCTAssertEqual(recognizer.recognize(sample(count: 2, x: 140, y: 100, t: 1.2)), .ignored(.unsupportedFingerCount))
        XCTAssertEqual(recognizer.diagnostics, acceptedDiagnostics)
    }

    func testExactlyThreeFingerRejectionUpdatesDiagnostics() {
        let recognizer = recognizer()

        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 100, y: 100, t: 1)), .ignored(.tracking))
        XCTAssertEqual(recognizer.recognize(sample(count: 3, x: 105, y: 101, t: 1.1)), .ignored(.belowThreshold))

        XCTAssertEqual(recognizer.diagnostics.lastGestureAccepted, false)
        XCTAssertEqual(recognizer.diagnostics.lastRejectionReason, .belowThreshold)
        XCTAssertEqual(recognizer.diagnostics.lastGestureDuration ?? -1, 0.1, accuracy: 0.0001)
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

    private func sample(count: Int, x: Double, y: Double, t: TimeInterval) -> RawTouchSample {
        RawTouchSample(activeTouchCount: count, centroidX: x, centroidY: y, timestamp: t)
    }
}
