import XCTest
@testable import WindowGesturesCore

final class DiscreteMovementPlannerTests: XCTestCase {
    func testMovementDeltaKindClassifiesPositionOnly() {
        let current = Rect(x: 0, y: 0, width: 100, height: 100)
        let target = Rect(x: 50, y: 20, width: 100, height: 100)

        XCTAssertEqual(MovementDeltaKind.classify(from: current, to: target), .positionOnly)
    }

    func testMovementDeltaKindClassifiesSizeOnly() {
        let current = Rect(x: 0, y: 0, width: 100, height: 100)
        let target = Rect(x: 0, y: 0, width: 300, height: 200)

        XCTAssertEqual(MovementDeltaKind.classify(from: current, to: target), .sizeOnly)
    }

    func testMovementDeltaKindClassifiesPositionAndSize() {
        let current = Rect(x: 0, y: 0, width: 100, height: 100)
        let target = Rect(x: 50, y: 20, width: 300, height: 200)

        XCTAssertEqual(MovementDeltaKind.classify(from: current, to: target), .positionAndSize)
    }

    func testMovementDeltaKindClassifiesNoOpWithinTolerance() {
        let current = Rect(x: 0, y: 0, width: 100, height: 100)
        let target = Rect(x: 0.2, y: 0.2, width: 100.2, height: 100.2)

        XCTAssertEqual(MovementDeltaKind.classify(from: current, to: target), .noOp)
    }

    func testDiscreteMovementPlanHasIntermediateFramesAndExactFinalTarget() {
        let current = Rect(x: 100, y: 80, width: 400, height: 300)
        let target = Rect(x: 0, y: 0, width: 800, height: 600)

        let plan = DiscreteMovementPlanner.plan(
            from: current,
            to: target,
            totalStepCount: 4,
            totalDuration: 0.24
        )

        XCTAssertEqual(plan.frames.count, 4)
        XCTAssertNotEqual(plan.frames[0], current)
        XCTAssertEqual(plan.frames[3], target)
        XCTAssertEqual(plan.stepInterval, 0.06, accuracy: 0.0001)
    }

    func testDiscreteMovementPlanUsesLinearInterpolation() {
        let current = Rect(x: 100, y: 100, width: 400, height: 300)
        let target = Rect(x: 500, y: 300, width: 800, height: 500)

        let plan = DiscreteMovementPlanner.plan(
            from: current,
            to: target,
            totalStepCount: 4,
            totalDuration: 0.24
        )

        XCTAssertEqual(plan.frames, [
            Rect(x: 200, y: 150, width: 500, height: 350),
            Rect(x: 300, y: 200, width: 600, height: 400),
            Rect(x: 400, y: 250, width: 700, height: 450),
            target
        ])
    }

    func testDiscreteMovementPlanDoesNotApplyFinalTargetBeforeIntermediateFrames() {
        let current = Rect(x: 20, y: 40, width: 400, height: 300)
        let target = Rect(x: 0, y: 0, width: 1000, height: 800)

        let plan = DiscreteMovementPlanner.plan(
            from: current,
            to: target,
            totalStepCount: 4,
            totalDuration: 0.24
        )

        XCTAssertFalse(plan.frames.dropLast().contains(target))
        XCTAssertEqual(plan.frames.last, target)
    }

    func testDiscreteMovementPlanUsesRequestedDurationWithoutHiddenMinimumInterval() {
        let current = Rect(x: 0, y: 0, width: 100, height: 100)
        let target = Rect(x: 320, y: 160, width: 100, height: 100)

        let plan = DiscreteMovementPlanner.plan(
            from: current,
            to: target,
            totalStepCount: 32,
            totalDuration: 0.02
        )

        XCTAssertEqual(plan.frames.count, 32)
        XCTAssertEqual(plan.stepInterval, 0.02 / 32, accuracy: 0.000001)
        XCTAssertEqual(plan.frames.last, target)
    }

    func testPositionOnlyPlanCanUseThirtyTwoSamples() {
        let current = Rect(x: 0, y: 0, width: 500, height: 400)
        let target = Rect(x: 320, y: 160, width: 500, height: 400)

        let plan = MovementFramePlanner.plan(
            from: current,
            to: target,
            totalStepCount: 32,
            totalDuration: 0.02
        )

        XCTAssertEqual(plan.movementKind, .positionOnly)
        XCTAssertEqual(plan.frames.count, 32)
        XCTAssertEqual(plan.frames.last, target)
    }

    func testResizeHeavyPlanCapsEffectiveSamples() {
        let current = Rect(x: 0, y: 0, width: 500, height: 400)
        let target = Rect(x: 320, y: 160, width: 800, height: 700)

        let plan = MovementFramePlanner.plan(
            from: current,
            to: target,
            totalStepCount: 32,
            totalDuration: 0.02
        )

        XCTAssertEqual(plan.movementKind, .positionAndSize)
        XCTAssertLessThanOrEqual(plan.frames.count, 10)
        XCTAssertEqual(plan.frames.last, target)
    }

    func testProgressValuesAreMonotonic() {
        let current = Rect(x: 0, y: 0, width: 500, height: 400)
        let target = Rect(x: 320, y: 160, width: 500, height: 400)

        let plan = MovementFramePlanner.plan(
            from: current,
            to: target,
            totalStepCount: 8,
            totalDuration: 0.30
        )

        XCTAssertEqual(plan.progressValues, plan.progressValues.sorted())
        XCTAssertEqual(plan.progressValues.last, 1)
    }

    func testTinyRedundantSizeChangesAreSkippedButFinalTargetRemains() {
        let current = Rect(x: 0, y: 0, width: 500, height: 400)
        let target = Rect(x: 0, y: 0, width: 501, height: 401)

        let plan = MovementFramePlanner.plan(
            from: current,
            to: target,
            totalStepCount: 32,
            totalDuration: 0.02
        )

        XCTAssertLessThan(plan.frames.count, 10)
        XCTAssertEqual(plan.frames.last, target)
    }

    func testTimeBasedRunnerSkipsObsoleteFramesWhenTickIsLate() {
        let plan = MovementFramePlanner.plan(
            from: Rect(x: 0, y: 0, width: 500, height: 400),
            to: Rect(x: 320, y: 0, width: 500, height: 400),
            totalStepCount: 32,
            totalDuration: 0.02
        )
        var runner = DiscreteMovementRunner(plan: plan)

        let frame = runner.nextFrame(elapsed: 0.02)

        XCTAssertEqual(frame, plan.targetFrame)
        XCTAssertTrue(runner.isComplete)
        XCTAssertEqual(runner.appliedSteps, 1)
        XCTAssertGreaterThan(runner.skippedSteps, 0)
    }

    func testTimeBasedRunnerRecordsActualProgressFrame() {
        let plan = MovementFramePlanner.plan(
            from: Rect(x: 0, y: 0, width: 100, height: 100),
            to: Rect(x: 100, y: 0, width: 100, height: 100),
            totalStepCount: 4,
            totalDuration: 1.0
        )
        var runner = DiscreteMovementRunner(plan: plan)

        let frame = runner.nextFrame(elapsed: 0.5)

        XCTAssertEqual(frame, Rect(x: 50, y: 0, width: 100, height: 100))
        XCTAssertFalse(runner.isComplete)
    }

    func testPositionOnlyPlanCanApplyMoreFramesThanResizeHeavyPlan() {
        let positionOnly = MovementFramePlanner.plan(
            from: Rect(x: 0, y: 0, width: 500, height: 400),
            to: Rect(x: 320, y: 0, width: 500, height: 400),
            totalStepCount: 32,
            totalDuration: 0.02
        )
        let resizeHeavy = MovementFramePlanner.plan(
            from: Rect(x: 0, y: 0, width: 500, height: 400),
            to: Rect(x: 320, y: 0, width: 900, height: 800),
            totalStepCount: 32,
            totalDuration: 0.02
        )

        XCTAssertGreaterThan(positionOnly.frames.count, resizeHeavy.frames.count)
    }
}
