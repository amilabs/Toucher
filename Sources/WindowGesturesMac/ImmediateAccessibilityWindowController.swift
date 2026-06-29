import Foundation
import WindowGesturesCore

public struct WindowMovementDiagnostics: Equatable, Sendable {
    public var lastMovementMode: String
    public var lastMovementKind: String
    public var lastMovementStepsPlanned: Int
    public var lastMovementStepsApplied: Int
    public var lastMovementStepsSkipped: Int
    public var lastMovementRequestedDuration: TimeInterval?
    public var lastMovementActualElapsedDuration: TimeInterval?
    public var lastStartFrame: Rect?
    public var lastTargetFrame: Rect?
    public var lastFinalReadbackFrame: Rect?
    public var lastMovementError: String?
    public var lastMovementFallbackUsed: Bool

    public init(
        lastMovementMode: String = "immediate",
        lastMovementKind: String = "noOp",
        lastMovementStepsPlanned: Int = 0,
        lastMovementStepsApplied: Int = 0,
        lastMovementStepsSkipped: Int = 0,
        lastMovementRequestedDuration: TimeInterval? = nil,
        lastMovementActualElapsedDuration: TimeInterval? = nil,
        lastStartFrame: Rect? = nil,
        lastTargetFrame: Rect? = nil,
        lastFinalReadbackFrame: Rect? = nil,
        lastMovementError: String? = nil,
        lastMovementFallbackUsed: Bool = false
    ) {
        self.lastMovementMode = lastMovementMode
        self.lastMovementKind = lastMovementKind
        self.lastMovementStepsPlanned = lastMovementStepsPlanned
        self.lastMovementStepsApplied = lastMovementStepsApplied
        self.lastMovementStepsSkipped = lastMovementStepsSkipped
        self.lastMovementRequestedDuration = lastMovementRequestedDuration
        self.lastMovementActualElapsedDuration = lastMovementActualElapsedDuration
        self.lastStartFrame = lastStartFrame
        self.lastTargetFrame = lastTargetFrame
        self.lastFinalReadbackFrame = lastFinalReadbackFrame
        self.lastMovementError = lastMovementError
        self.lastMovementFallbackUsed = lastMovementFallbackUsed
    }
}

public final class ImmediateAccessibilityWindowController: WindowControlling {
    public typealias Window = AccessibilityWindowController.Window

    private let base: AccessibilityWindowController
    public private(set) var diagnostics = WindowMovementDiagnostics()
    public var onDiagnosticsChange: (() -> Void)?
    private var pendingMovementWorkItem: DispatchWorkItem?
    private var movementSequenceID = 0
    private var activeDiscreteRunner: DiscreteMovementRunner?

    public init(base: AccessibilityWindowController = AccessibilityWindowController()) {
        self.base = base
    }

    public func focusedWindow() throws -> Window {
        try base.focusedWindow()
    }

    public func frame(for window: Window) throws -> Rect {
        try base.frame(for: window)
    }

    public func visibleScreenFrame(for window: Window) throws -> Rect {
        try base.visibleScreenFrame(for: window)
    }

    public func screens() throws -> [ScreenFrame] {
        try base.screens()
    }

    public func move(_ window: Window, to frame: Rect) throws {
        assertMainThread()
        cancelPendingMovement()
        movementSequenceID += 1

        do {
            try base.move(window, to: frame)
            diagnostics = WindowMovementDiagnostics(
                lastMovementMode: "immediate",
                lastMovementKind: "unknown",
                lastMovementStepsPlanned: 1,
                lastMovementStepsApplied: 1,
                lastMovementStepsSkipped: 0,
                lastMovementRequestedDuration: 0,
                lastMovementActualElapsedDuration: 0,
                lastStartFrame: nil,
                lastTargetFrame: frame,
                lastFinalReadbackFrame: try? base.frame(for: window),
                lastMovementError: nil,
                lastMovementFallbackUsed: false
            )
            onDiagnosticsChange?()
        } catch {
            diagnostics = WindowMovementDiagnostics(
                lastMovementMode: "immediate",
                lastMovementKind: "unknown",
                lastMovementStepsPlanned: 1,
                lastMovementStepsApplied: 0,
                lastMovementStepsSkipped: 0,
                lastMovementRequestedDuration: 0,
                lastMovementActualElapsedDuration: 0,
                lastStartFrame: nil,
                lastTargetFrame: frame,
                lastFinalReadbackFrame: nil,
                lastMovementError: String(describing: error),
                lastMovementFallbackUsed: false
            )
            onDiagnosticsChange?()
            throw error
        }
    }

    public func move(_ window: Window, to frame: Rect, movementMode: WindowMovementMode) throws {
        assertMainThread()

        switch movementMode {
        case .immediate:
            try move(window, to: frame)
        case .discreteSteps(let totalStepCount, let totalDuration):
            try moveWithDiscreteSteps(
                window,
                to: frame,
                totalStepCount: totalStepCount,
                totalDuration: totalDuration
            )
        }
    }

    public func restoreIdentifier(for window: Window) -> String? {
        base.restoreIdentifier(for: window)
    }

    public func screenGeometryDebugInfo(actionTargetFrame: Rect? = nil) -> String {
        base.screenGeometryDebugInfo(actionTargetFrame: actionTargetFrame)
    }

    private func moveWithDiscreteSteps(
        _ window: Window,
        to targetFrame: Rect,
        totalStepCount: Int,
        totalDuration: TimeInterval
    ) throws {
        cancelPendingMovement()
        movementSequenceID += 1
        let sequenceID = movementSequenceID

        let currentFrame = try base.frame(for: window)
        let movementStartTime = CFAbsoluteTimeGetCurrent()
        let plan = DiscreteMovementPlanner.plan(
            from: currentFrame,
            to: targetFrame,
            totalStepCount: totalStepCount,
            totalDuration: totalDuration
        )

        diagnostics = WindowMovementDiagnostics(
            lastMovementMode: "discreteSteps",
            lastMovementKind: plan.movementKind.rawValue,
            lastMovementStepsPlanned: plan.frames.count,
            lastMovementStepsApplied: 0,
            lastMovementStepsSkipped: 0,
            lastMovementRequestedDuration: totalDuration,
            lastMovementActualElapsedDuration: nil,
            lastStartFrame: currentFrame,
            lastTargetFrame: targetFrame,
            lastFinalReadbackFrame: nil,
            lastMovementError: nil,
            lastMovementFallbackUsed: false
        )
        onDiagnosticsChange?()

        activeDiscreteRunner = DiscreteMovementRunner(plan: plan)
        scheduleDiscreteStep(
            window: window,
            plan: plan,
            movementStartTime: movementStartTime,
            sequenceID: sequenceID
        )
    }

    private func scheduleDiscreteStep(
        window: Window,
        plan: DiscreteMovementPlan,
        movementStartTime: CFAbsoluteTime,
        sequenceID: Int
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.runDiscreteStep(
                window: window,
                plan: plan,
                movementStartTime: movementStartTime,
                sequenceID: sequenceID
            )
        }

        pendingMovementWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + plan.stepInterval, execute: workItem)
    }

    private func runDiscreteStep(
        window: Window,
        plan: DiscreteMovementPlan,
        movementStartTime: CFAbsoluteTime,
        sequenceID: Int
    ) {
        guard sequenceID == movementSequenceID,
              pendingMovementWorkItem?.isCancelled == false,
              var runner = activeDiscreteRunner else {
            return
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - movementStartTime
        guard let frame = runner.nextFrame(elapsed: elapsed) else {
            activeDiscreteRunner = runner
            if !runner.isComplete {
                scheduleDiscreteStep(
                    window: window,
                    plan: plan,
                    movementStartTime: movementStartTime,
                    sequenceID: sequenceID
                )
            }
            return
        }

        do {
            try base.move(window, to: frame)
            activeDiscreteRunner = runner
            let isFinalStep = runner.isComplete
            diagnostics = WindowMovementDiagnostics(
                lastMovementMode: "discreteSteps",
                lastMovementKind: plan.movementKind.rawValue,
                lastMovementStepsPlanned: plan.frames.count,
                lastMovementStepsApplied: runner.appliedSteps,
                lastMovementStepsSkipped: runner.skippedSteps,
                lastMovementRequestedDuration: plan.totalDuration,
                lastMovementActualElapsedDuration: isFinalStep ? CFAbsoluteTimeGetCurrent() - movementStartTime : nil,
                lastStartFrame: plan.startFrame,
                lastTargetFrame: plan.targetFrame,
                lastFinalReadbackFrame: isFinalStep ? (try? base.frame(for: window)) : nil,
                lastMovementError: nil,
                lastMovementFallbackUsed: false
            )

            if isFinalStep {
                pendingMovementWorkItem = nil
                activeDiscreteRunner = nil
            } else {
                scheduleDiscreteStep(
                    window: window,
                    plan: plan,
                    movementStartTime: movementStartTime,
                    sequenceID: sequenceID
                )
            }
            onDiagnosticsChange?()
        } catch {
            let fallbackResult = runner.isComplete
                ? (succeeded: false, finalReadbackFrame: nil, errorDescription: String(describing: error))
                : applyFinalFallback(window: window, targetFrame: plan.targetFrame)
            diagnostics = WindowMovementDiagnostics(
                lastMovementMode: "discreteSteps",
                lastMovementKind: plan.movementKind.rawValue,
                lastMovementStepsPlanned: plan.frames.count,
                lastMovementStepsApplied: runner.appliedSteps + (fallbackResult.succeeded ? 1 : 0),
                lastMovementStepsSkipped: runner.skippedSteps,
                lastMovementRequestedDuration: plan.totalDuration,
                lastMovementActualElapsedDuration: CFAbsoluteTimeGetCurrent() - movementStartTime,
                lastStartFrame: plan.startFrame,
                lastTargetFrame: plan.targetFrame,
                lastFinalReadbackFrame: fallbackResult.finalReadbackFrame,
                lastMovementError: fallbackResult.errorDescription ?? String(describing: error),
                lastMovementFallbackUsed: !runner.isComplete
            )
            onDiagnosticsChange?()
        }
    }

    private func applyFinalFallback(window: Window, targetFrame: Rect) -> (succeeded: Bool, finalReadbackFrame: Rect?, errorDescription: String?) {
        cancelPendingMovement()
        do {
            try base.move(window, to: targetFrame)
            return (true, try? base.frame(for: window), nil)
        } catch {
            return (false, nil, String(describing: error))
        }
    }

    private func cancelPendingMovement() {
        pendingMovementWorkItem?.cancel()
        pendingMovementWorkItem = nil
        activeDiscreteRunner = nil
    }

    private func assertMainThread() {
        precondition(Thread.isMainThread, "ImmediateAccessibilityWindowController must be used on the main thread")
    }
}
