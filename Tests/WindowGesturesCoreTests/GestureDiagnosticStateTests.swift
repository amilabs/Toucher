import XCTest
@testable import WindowGesturesCore

final class GestureDiagnosticStateTests: XCTestCase {
    func testRecordingPublicEventUpdatesLastEventAndCounters() {
        let state = GestureDiagnosticState()

        state.record(
            PublicGestureEventInput(
                type: .scrollWheel,
                timestamp: 12.5,
                deltaX: 3,
                deltaY: -4,
                scrollingDeltaX: 30,
                scrollingDeltaY: -40,
                hasPreciseScrollingDeltas: true,
                isDirectionInvertedFromDevice: false,
                phase: "changed",
                momentumPhase: "none"
            )
        )

        XCTAssertEqual(state.snapshot.lastEventType, .scrollWheel)
        XCTAssertEqual(state.snapshot.lastTimestamp, 12.5)
        XCTAssertEqual(state.snapshot.lastDeltaX, 3)
        XCTAssertEqual(state.snapshot.lastDeltaY, -4)
        XCTAssertEqual(state.snapshot.lastScrollDeltaX, 3)
        XCTAssertEqual(state.snapshot.lastScrollDeltaY, -4)
        XCTAssertEqual(state.snapshot.lastScrollScrollingDeltaX, 30)
        XCTAssertEqual(state.snapshot.lastScrollScrollingDeltaY, -40)
        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaX, 30)
        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaY, -40)
        XCTAssertEqual(state.snapshot.lastScrollHasPreciseScrollingDeltas, true)
        XCTAssertEqual(state.snapshot.lastScrollIsDirectionInvertedFromDevice, false)
        XCTAssertEqual(state.snapshot.lastPhase, "changed")
        XCTAssertEqual(state.snapshot.lastMomentumPhase, "none")
        XCTAssertEqual(state.snapshot.counters.scrollWheel, 1)
        XCTAssertEqual(state.snapshot.counters.swipe, 0)
    }

    func testCountersTrackEachPublicEventType() {
        let state = GestureDiagnosticState()

        for type in PublicGestureEventType.allCases {
            state.record(PublicGestureEventInput(type: type, timestamp: 1))
        }

        XCTAssertEqual(state.snapshot.counters.swipe, 1)
        XCTAssertEqual(state.snapshot.counters.scrollWheel, 1)
        XCTAssertEqual(state.snapshot.counters.beginGesture, 1)
        XCTAssertEqual(state.snapshot.counters.endGesture, 1)
        XCTAssertEqual(state.snapshot.counters.magnify, 1)
        XCTAssertEqual(state.snapshot.counters.rotate, 1)
        XCTAssertEqual(state.snapshot.counters.smartMagnify, 1)
    }

    func testOnlySwipePublicEventsAreEligibleForWindowActions() {
        let recognizer = HorizontalSwipeRecognizer()

        let scrollResult = recognizer.recognize(
            publicEvent: PublicGestureEventInput(type: .scrollWheel, timestamp: 1, deltaX: 10, deltaY: 0)
        )
        let swipeResult = recognizer.recognize(
            publicEvent: PublicGestureEventInput(type: .swipe, timestamp: 2, deltaX: 10, deltaY: 0)
        )

        XCTAssertNil(scrollResult)
        XCTAssertEqual(swipeResult, .action(.rightHalf))
    }

    func testScrollAccumulationUsesScrollingDeltasAndResetsAtBeginningPhase() {
        let state = GestureDiagnosticState()

        state.record(
            PublicGestureEventInput(
                type: .scrollWheel,
                timestamp: 1,
                deltaX: 0,
                deltaY: 0,
                scrollingDeltaX: 2,
                scrollingDeltaY: -3,
                phase: "began"
            )
        )
        state.record(
            PublicGestureEventInput(
                type: .scrollWheel,
                timestamp: 1.1,
                deltaX: 0,
                deltaY: 0,
                scrollingDeltaX: 4,
                scrollingDeltaY: -5,
                phase: "changed"
            )
        )

        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaX, 6)
        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaY, -8)

        state.record(
            PublicGestureEventInput(
                type: .scrollWheel,
                timestamp: 2,
                deltaX: 0,
                deltaY: 0,
                scrollingDeltaX: -1,
                scrollingDeltaY: 7,
                phase: "began"
            )
        )

        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaX, -1)
        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaY, 7)
    }

    func testScrollAccumulationFallsBackToRawDeltas() {
        let state = GestureDiagnosticState()

        state.record(
            PublicGestureEventInput(
                type: .scrollWheel,
                timestamp: 1,
                deltaX: 3,
                deltaY: 4,
                phase: "changed"
            )
        )

        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaX, 3)
        XCTAssertEqual(state.snapshot.accumulatedScrollDeltaY, 4)
    }
}
