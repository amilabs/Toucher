import XCTest
@testable import WindowGesturesCore

final class AnimationPlannerTests: XCTestCase {
    func testAnimationPlanStartsAtCurrentFrameAndEndsAtTargetFrame() {
        let start = Rect(x: 0, y: 0, width: 100, height: 100)
        let end = Rect(x: 100, y: 50, width: 200, height: 150)

        let frames = AnimationPlanner.frames(from: start, to: end, duration: 0.25)

        XCTAssertEqual(frames.first, start)
        XCTAssertEqual(frames.last, end)
    }

    func testDurationZeroAppliesTargetImmediately() {
        let start = Rect(x: 0, y: 0, width: 100, height: 100)
        let end = Rect(x: 100, y: 50, width: 200, height: 150)

        XCTAssertEqual(AnimationPlanner.frames(from: start, to: end, duration: 0), [end])
    }

    func testEaseOutValuesAreMonotonic() {
        let values = stride(from: 0.0, through: 1.0, by: 0.1).map(AnimationPlanner.easeOut)

        XCTAssertEqual(values.first, 0)
        XCTAssertEqual(values.last, 1)
        XCTAssertTrue(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })
    }
}
