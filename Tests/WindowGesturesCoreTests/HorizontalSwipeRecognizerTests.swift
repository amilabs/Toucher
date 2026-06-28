import XCTest
@testable import WindowGesturesCore

final class HorizontalSwipeRecognizerTests: XCTestCase {
    func testRightSwipeAboveThresholdReturnsRightHalf() {
        let recognizer = HorizontalSwipeRecognizer()

        let result = recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1))

        XCTAssertEqual(result, .action(.rightHalf))
    }

    func testLeftSwipeAboveThresholdReturnsLeftHalf() {
        let recognizer = HorizontalSwipeRecognizer()

        let result = recognizer.recognize(input(deltaX: -1, deltaY: 0, timestamp: 1))

        XCTAssertEqual(result, .action(.leftHalf))
    }

    func testVerticalMovementIsIgnored() {
        let recognizer = HorizontalSwipeRecognizer()

        let result = recognizer.recognize(input(deltaX: 0.6, deltaY: 3, timestamp: 1))

        XCTAssertEqual(result, .ignored(.diagonal))
    }

    func testDiagonalMovementIsIgnored() {
        let recognizer = HorizontalSwipeRecognizer()

        let result = recognizer.recognize(input(deltaX: 1, deltaY: 1, timestamp: 1))

        XCTAssertEqual(result, .ignored(.diagonal))
    }

    func testBelowThresholdMovementIsIgnored() {
        let recognizer = HorizontalSwipeRecognizer()

        let result = recognizer.recognize(input(deltaX: 0.1, deltaY: 0, timestamp: 1))

        XCTAssertEqual(result, .ignored(.belowThreshold))
    }

    func testDuplicateEventInsideCooldownIsIgnored() {
        let recognizer = HorizontalSwipeRecognizer()

        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1.1)), .ignored(.cooldown))
    }

    func testEventAfterCooldownIsAccepted() {
        let recognizer = HorizontalSwipeRecognizer()

        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(input(deltaX: -1, deltaY: 0, timestamp: 1.36)), .action(.leftHalf))
    }

    func testDirectionInversionOptionWorks() {
        let recognizer = HorizontalSwipeRecognizer(invertDirection: true)

        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1)), .action(.leftHalf))
        XCTAssertEqual(recognizer.recognize(input(deltaX: -1, deltaY: 0, timestamp: 1.36)), .action(.rightHalf))
    }

    func testRepeatedDuplicateSamplesInsideCooldownDoNotProduceExtraActions() {
        let recognizer = HorizontalSwipeRecognizer()

        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1)), .action(.rightHalf))
        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1.05)), .ignored(.cooldown))
        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1.1)), .ignored(.cooldown))
        XCTAssertEqual(recognizer.recognize(input(deltaX: 1, deltaY: 0, timestamp: 1.2)), .ignored(.cooldown))
    }

    private func input(deltaX: Double, deltaY: Double, timestamp: TimeInterval) -> SwipeGestureInput {
        SwipeGestureInput(
            deltaX: deltaX,
            deltaY: deltaY,
            timestamp: timestamp,
            source: .publicNSEventSwipe
        )
    }
}
