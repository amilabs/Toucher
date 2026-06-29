import Foundation

public enum ToucherGestureBackendPreference: String, Equatable, Sendable, CaseIterable {
    case raw
    case `public`
    case off
}

public struct ToucherSettingsSnapshot: Equatable, Sendable {
    public var enableGestures: Bool
    public var gestureBackend: ToucherGestureBackendPreference
    public var enableDiagnostics: Bool
    public var invertGestureDirection: Bool
    public var animateWindowMovement: Bool
    public var animationDuration: TimeInterval
    public var animationSteps: Int
    public var rawMinDistance: Double
    public var rawDominanceRatio: Double
    public var rawCooldown: TimeInterval

    public init(
        enableGestures: Bool = true,
        gestureBackend: ToucherGestureBackendPreference = .raw,
        enableDiagnostics: Bool = false,
        invertGestureDirection: Bool = false,
        animateWindowMovement: Bool = true,
        animationDuration: TimeInterval = 0.10,
        animationSteps: Int = 32,
        rawMinDistance: Double = 0.08,
        rawDominanceRatio: Double = 2.0,
        rawCooldown: TimeInterval = 0.35
    ) {
        self.enableGestures = enableGestures
        self.gestureBackend = gestureBackend
        self.enableDiagnostics = enableDiagnostics
        self.invertGestureDirection = invertGestureDirection
        self.animateWindowMovement = animateWindowMovement
        self.animationDuration = min(0.60, max(0.02, animationDuration))
        self.animationSteps = min(32, max(3, animationSteps))
        self.rawMinDistance = max(0.001, rawMinDistance)
        self.rawDominanceRatio = max(1, rawDominanceRatio)
        self.rawCooldown = min(2, max(0, rawCooldown))
    }

    public var effectiveGestureBackend: ToucherGestureBackendPreference {
        enableGestures ? gestureBackend : .off
    }
}

public protocol GestureBackendLifecycle: AnyObject {
    var isRunning: Bool { get }
    func start()
    func stop()
}

public protocol WindowActionHandling: AnyObject {
    func perform(_ action: WindowAction, options: WindowCommandOptions) -> WindowCommandResult
}

public final class ToucherRuntimeCoordinator<ActionHandler: WindowActionHandling> {
    public private(set) var settings: ToucherSettingsSnapshot

    private let actionHandler: ActionHandler
    private let rawBackend: GestureBackendLifecycle
    private let publicBackend: GestureBackendLifecycle
    private var currentBackend: ToucherGestureBackendPreference
    private var isHandlingAction = false

    public init(
        settings: ToucherSettingsSnapshot = ToucherSettingsSnapshot(),
        actionHandler: ActionHandler,
        rawBackend: GestureBackendLifecycle,
        publicBackend: GestureBackendLifecycle
    ) {
        self.settings = settings
        self.actionHandler = actionHandler
        self.rawBackend = rawBackend
        self.publicBackend = publicBackend
        self.currentBackend = .off
    }

    public func applySettings(_ newSettings: ToucherSettingsSnapshot) {
        let oldBackend = settings.effectiveGestureBackend
        settings = newSettings
        let newBackend = newSettings.effectiveGestureBackend

        guard oldBackend != newBackend || currentBackend != newBackend else {
            return
        }

        stopBackend(oldBackend)
        startBackend(newBackend)
        currentBackend = newBackend
    }

    public func restartGestureBackendIfNeeded() {
        let backend = settings.effectiveGestureBackend
        stopBackend(currentBackend)
        startBackend(backend)
        currentBackend = backend
    }

    public func setAnimateWindowMovement(_ isEnabled: Bool) {
        settings.animateWindowMovement = isEnabled
    }

    public var movementMode: WindowMovementMode {
        settings.animateWindowMovement
            ? .discreteSteps(totalStepCount: settings.animationSteps, totalDuration: settings.animationDuration)
            : .immediate
    }

    @discardableResult
    public func handleAction(
        _ action: WindowAction,
        screenTarget: WindowScreenTarget = .current
    ) -> WindowCommandResult {
        precondition(!isHandlingAction, "ToucherRuntimeCoordinator action handling must be serialized")
        isHandlingAction = true
        defer { isHandlingAction = false }

        return actionHandler.perform(
            action,
            options: WindowCommandOptions(
                screenTarget: screenTarget,
                movementMode: movementMode
            )
        )
    }

    private func stopBackend(_ backend: ToucherGestureBackendPreference) {
        switch backend {
        case .raw:
            rawBackend.stop()
        case .public:
            publicBackend.stop()
        case .off:
            break
        }
    }

    private func startBackend(_ backend: ToucherGestureBackendPreference) {
        switch backend {
        case .raw:
            rawBackend.start()
        case .public:
            publicBackend.start()
        case .off:
            break
        }
    }
}

extension WindowCommandHandler: WindowActionHandling {}
