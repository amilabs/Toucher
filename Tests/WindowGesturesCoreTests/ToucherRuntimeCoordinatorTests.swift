import XCTest
@testable import WindowGesturesCore

final class ToucherRuntimeCoordinatorTests: XCTestCase {
    func testDefaultSettingsDisableAnimation() {
        XCTAssertFalse(ToucherSettingsSnapshot().animationEnabled)
    }

    func testApplySettingsStopsOldBackendBeforeStartingNewBackend() {
        let recorder = LifecycleRecorder()
        let raw = MockGestureBackend(name: "raw", recorder: recorder)
        let publicBackend = MockGestureBackend(name: "public", recorder: recorder)
        let handler = MockActionHandler()
        let coordinator = ToucherRuntimeCoordinator(
            settings: ToucherSettingsSnapshot(gestureBackend: .raw),
            actionHandler: handler,
            rawBackend: raw,
            publicBackend: publicBackend
        )

        coordinator.applySettings(ToucherSettingsSnapshot(gestureBackend: .raw))
        coordinator.applySettings(ToucherSettingsSnapshot(gestureBackend: .public))

        XCTAssertEqual(recorder.events, ["stop raw", "start raw", "stop raw", "start public"])
    }

    func testChangingBackendRawToOffStopsRaw() {
        let recorder = LifecycleRecorder()
        let raw = MockGestureBackend(name: "raw", recorder: recorder)
        let publicBackend = MockGestureBackend(name: "public", recorder: recorder)
        let coordinator = ToucherRuntimeCoordinator(
            settings: ToucherSettingsSnapshot(gestureBackend: .raw),
            actionHandler: MockActionHandler(),
            rawBackend: raw,
            publicBackend: publicBackend
        )

        coordinator.applySettings(ToucherSettingsSnapshot(gestureBackend: .raw))
        coordinator.applySettings(ToucherSettingsSnapshot(enableGestures: false, gestureBackend: .raw))

        XCTAssertEqual(recorder.events, ["stop raw", "start raw", "stop raw"])
        XCTAssertFalse(raw.isRunning)
    }

    func testChangingBackendOffToRawStartsRaw() {
        let recorder = LifecycleRecorder()
        let raw = MockGestureBackend(name: "raw", recorder: recorder)
        let publicBackend = MockGestureBackend(name: "public", recorder: recorder)
        let coordinator = ToucherRuntimeCoordinator(
            settings: ToucherSettingsSnapshot(enableGestures: false, gestureBackend: .raw),
            actionHandler: MockActionHandler(),
            rawBackend: raw,
            publicBackend: publicBackend
        )

        coordinator.applySettings(ToucherSettingsSnapshot(enableGestures: true, gestureBackend: .raw))

        XCTAssertEqual(recorder.events, ["start raw"])
        XCTAssertTrue(raw.isRunning)
    }

    func testChangingAnimationEnabledDoesNotRestartGestureBackend() {
        let recorder = LifecycleRecorder()
        let raw = MockGestureBackend(name: "raw", recorder: recorder)
        let publicBackend = MockGestureBackend(name: "public", recorder: recorder)
        let coordinator = ToucherRuntimeCoordinator(
            settings: ToucherSettingsSnapshot(gestureBackend: .raw),
            actionHandler: MockActionHandler(),
            rawBackend: raw,
            publicBackend: publicBackend
        )

        coordinator.applySettings(ToucherSettingsSnapshot(gestureBackend: .raw))
        recorder.events.removeAll()
        coordinator.applySettings(ToucherSettingsSnapshot(gestureBackend: .raw, animationEnabled: true))

        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testChangingAnimationEnabledDoesNotCallActionHandler() {
        let coordinator = ToucherRuntimeCoordinator(
            actionHandler: MockActionHandler(),
            rawBackend: MockGestureBackend(name: "raw", recorder: LifecycleRecorder()),
            publicBackend: MockGestureBackend(name: "public", recorder: LifecycleRecorder())
        )

        coordinator.applySettings(ToucherSettingsSnapshot(animationEnabled: true))

        XCTAssertEqual(coordinator.settings.animationEnabled, true)
    }

    func testHandleActionPassesCurrentAnimationSettings() {
        let handler = MockActionHandler()
        let coordinator = ToucherRuntimeCoordinator(
            actionHandler: handler,
            rawBackend: MockGestureBackend(name: "raw", recorder: LifecycleRecorder()),
            publicBackend: MockGestureBackend(name: "public", recorder: LifecycleRecorder())
        )
        coordinator.setAnimationEnabled(true)

        _ = coordinator.handleAction(.leftHalf, screenTarget: .next)

        XCTAssertEqual(handler.actions, [.leftHalf])
        XCTAssertEqual(handler.options, [
            WindowCommandOptions(screenTarget: .next, animated: true, animationDuration: 0.25)
        ])
    }

    func testSettingsAreClamped() {
        let snapshot = ToucherSettingsSnapshot(
            animationDuration: 2,
            rawMinDistance: -1,
            rawDominanceRatio: 0,
            rawCooldown: 5
        )

        XCTAssertEqual(snapshot.animationDuration, 0.5)
        XCTAssertEqual(snapshot.rawMinDistance, 0.001)
        XCTAssertEqual(snapshot.rawDominanceRatio, 1)
        XCTAssertEqual(snapshot.rawCooldown, 2)
    }
}

private final class LifecycleRecorder {
    var events: [String] = []
}

private final class MockGestureBackend: GestureBackendLifecycle {
    private let name: String
    private let recorder: LifecycleRecorder
    private(set) var isRunning = false

    init(name: String, recorder: LifecycleRecorder) {
        self.name = name
        self.recorder = recorder
    }

    func start() {
        recorder.events.append("start \(name)")
        isRunning = true
    }

    func stop() {
        recorder.events.append("stop \(name)")
        isRunning = false
    }
}

private final class MockActionHandler: WindowActionHandling {
    private(set) var actions: [WindowAction] = []
    private(set) var options: [WindowCommandOptions] = []

    func perform(_ action: WindowAction, options: WindowCommandOptions) -> WindowCommandResult {
        actions.append(action)
        self.options.append(options)
        return .moved(Rect(x: 0, y: 0, width: 1, height: 1))
    }
}
