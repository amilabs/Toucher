import AppKit
import WindowGesturesCore
import WindowGesturesMac

private typealias ToucherBackendPreference = ToucherGestureBackendPreference

private final class ToucherSettings {
    private enum Key {
        static let enableGestures = "enableGestures"
        static let gestureBackend = "gestureBackend"
        static let enableDiagnostics = "enableDiagnostics"
        static let invertGestureDirection = "invertGestureDirection"
        static let animationEnabled = "animationEnabled"
        static let animationDuration = "animationDuration"
        static let snapFeedbackEnabled = "snapFeedbackEnabled"
        static let snapFeedbackDuration = "snapFeedbackDuration"
        static let animateWindowMovement = "animateWindowMovement"
        static let animationStepCount = "animationStepCount"
        static let movementAnimationDuration = "movementAnimationDuration"
        static let movementAnimationSteps = "movementAnimationSteps"
        static let rawMinDistance = "rawMinDistance"
        static let rawDominanceRatio = "rawDominanceRatio"
        static let rawCooldown = "rawCooldown"
    }

    private let defaults: UserDefaults
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hasAnimateWindowMovement = defaults.object(forKey: Key.animateWindowMovement) != nil
        let hasAnimationStepCount = defaults.object(forKey: Key.animationStepCount) != nil
        let hasAnimationDuration = defaults.object(forKey: Key.animationDuration) != nil
        let legacyMovementAnimationSteps = defaults.object(forKey: Key.movementAnimationSteps) as? Int
        let legacyMovementAnimationDuration = defaults.object(forKey: Key.movementAnimationDuration) as? Double
        let legacySnapFeedbackEnabled = defaults.object(forKey: Key.snapFeedbackEnabled) != nil &&
            defaults.bool(forKey: Key.snapFeedbackEnabled)
        let legacyAnimationEnabled = defaults.object(forKey: Key.animationEnabled) != nil &&
            defaults.bool(forKey: Key.animationEnabled)
        let legacySnapFeedbackDuration = defaults.object(forKey: Key.snapFeedbackDuration) as? Double
        let legacyAnimationDuration = defaults.object(forKey: Key.animationDuration) as? Double
        defaults.register(defaults: [
            Key.enableGestures: true,
            Key.gestureBackend: ToucherBackendPreference.raw.rawValue,
            Key.enableDiagnostics: false,
            Key.invertGestureDirection: false,
            Key.animationEnabled: false,
            Key.animationDuration: 0.10,
            Key.snapFeedbackEnabled: false,
            Key.snapFeedbackDuration: 0.20,
            Key.animateWindowMovement: true,
            Key.animationStepCount: 32,
            Key.movementAnimationDuration: 0.10,
            Key.movementAnimationSteps: 32,
            Key.rawMinDistance: 0.08,
            Key.rawDominanceRatio: 2.0,
            Key.rawCooldown: 0.35
        ])
        if !hasAnimateWindowMovement, legacySnapFeedbackEnabled || legacyAnimationEnabled {
            defaults.set(true, forKey: Key.animateWindowMovement)
        }
        if !hasAnimationStepCount,
           let legacyMovementAnimationSteps {
            defaults.set(min(32, max(3, legacyMovementAnimationSteps)), forKey: Key.animationStepCount)
        }
        if !hasAnimationStepCount {
            defaults.set(true, forKey: Key.animateWindowMovement)
        }
        if !hasAnimationDuration {
            let migratedDuration = legacyMovementAnimationDuration ?? legacySnapFeedbackDuration ?? legacyAnimationDuration
            if let migratedDuration {
                defaults.set(min(0.60, max(0.02, migratedDuration)), forKey: Key.animationDuration)
            }
        }
    }

    var enableGestures: Bool {
        get { defaults.bool(forKey: Key.enableGestures) }
        set { set(newValue, forKey: Key.enableGestures) }
    }

    var gestureBackend: ToucherBackendPreference {
        get {
            ToucherBackendPreference(rawValue: defaults.string(forKey: Key.gestureBackend) ?? "") ?? .raw
        }
        set { set(newValue.rawValue, forKey: Key.gestureBackend) }
    }

    var enableDiagnostics: Bool {
        get { defaults.bool(forKey: Key.enableDiagnostics) }
        set { set(newValue, forKey: Key.enableDiagnostics) }
    }

    var invertGestureDirection: Bool {
        get { defaults.bool(forKey: Key.invertGestureDirection) }
        set { set(newValue, forKey: Key.invertGestureDirection) }
    }

    var animateWindowMovement: Bool {
        get { defaults.bool(forKey: Key.animateWindowMovement) }
        set { set(newValue, forKey: Key.animateWindowMovement) }
    }

    var movementAnimationDuration: TimeInterval {
        get { min(0.60, max(0.02, defaults.double(forKey: Key.animationDuration))) }
        set {
            let clamped = min(0.60, max(0.02, newValue))
            defaults.set(clamped, forKey: Key.movementAnimationDuration)
            set(clamped, forKey: Key.animationDuration)
        }
    }

    var movementAnimationSteps: Int {
        get { min(32, max(3, defaults.integer(forKey: Key.animationStepCount))) }
        set {
            let clamped = min(32, max(3, newValue))
            defaults.set(clamped, forKey: Key.movementAnimationSteps)
            set(clamped, forKey: Key.animationStepCount)
        }
    }

    var rawMinDistance: Double {
        get { max(0.001, defaults.double(forKey: Key.rawMinDistance)) }
        set { set(max(0.001, newValue), forKey: Key.rawMinDistance) }
    }

    var rawDominanceRatio: Double {
        get { max(1, defaults.double(forKey: Key.rawDominanceRatio)) }
        set { set(max(1, newValue), forKey: Key.rawDominanceRatio) }
    }

    var rawCooldown: TimeInterval {
        get { min(2, max(0, defaults.double(forKey: Key.rawCooldown))) }
        set { set(min(2, max(0, newValue)), forKey: Key.rawCooldown) }
    }

    var snapshot: ToucherSettingsSnapshot {
        ToucherSettingsSnapshot(
            enableGestures: enableGestures,
            gestureBackend: gestureBackend,
            enableDiagnostics: enableDiagnostics,
            invertGestureDirection: invertGestureDirection,
            animateWindowMovement: animateWindowMovement,
            animationDuration: movementAnimationDuration,
            animationSteps: movementAnimationSteps,
            rawMinDistance: rawMinDistance,
            rawDominanceRatio: rawDominanceRatio,
            rawCooldown: rawCooldown
        )
    }

    private func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = ToucherSettings()
    private let permissionChecker = AccessibilityTrustProvider()
    private let hotKeyRegistrar = CarbonHotKeyRegistrar()
    private lazy var windowController = ImmediateAccessibilityWindowController()
    private let gestureRecognizer = HorizontalSwipeRecognizer(invertDirection: false)
    private let invertRawVerticalDirection = false
    private var rawGestureRecognizer = RawThreeFingerSwipeRecognizer()
    private let gestureDiagnostics = GestureDiagnosticState()
    private var commandHandler: WindowCommandHandler<AccessibilityTrustProvider, ImmediateAccessibilityWindowController>?
    private var hotKeyCoordinator: HotKeyCoordinator<CarbonHotKeyRegistrar>?
    private var gestureBackend: GestureMonitoring?
    private var publicGestureBackend: PublicNSEventSwipeBackend?
    private var rawGestureBackend: RawMultitouchBackend?
    private var gestureProbeWindowController: GestureProbeWindowController?
    private var gestureBackendDescription = "off"
    private var rawMultitouchStatus = RawMultitouchBackendStatus()
    private var lastRawCentroidDeltaDescription = "none"
    private var lastRawGestureDescription = "none"
    private var lastRawGestureActionDescription = "none"
    private var lastRawGestureIgnoredReasonDescription = "none"
    private var lastAcceptedRawGestureDescription = "none"
    private var lastAcceptedRawDeltaDescription = "none"
    private var lastAcceptedRawDurationDescription = "none"
    private var rawCallbacksCount = 0
    private var rawRecognizedGesturesCount = 0
    private var rawLeftGesturesCount = 0
    private var rawRightGesturesCount = 0
    private var rawUpGesturesCount = 0
    private var rawIgnoredGesturesCount = 0
    private var rawUnsupportedFingerCountCount = 0
    private var rawCanceledGesturesCount = 0
    private var rawEventRingBuffer: [String] = []
    private var lastRawGestureStartX: Double?
    private var lastRawGestureStartY: Double?
    private var lastAXActionAttempted = "none"
    private var lastAXActionResult = "none"
    private var lastAXError = "none"
    private var accessibilityTrustMonitor = AccessibilityTrustMonitor()
    private var accessibilityTrustSnapshot = AccessibilityTrustMonitorSnapshot(
        isTrusted: false,
        waitingForAccessibility: false,
        transitionCount: 0,
        lastTransition: .none,
        shouldPoll: false
    )
    private var accessibilityLastCheckedDescription = "never"
    private var accessibilityPollTimer: Timer?
    private var settingsWindowController: SettingsWindowController?
    private var pendingSettingsApply = false
    private var appliedSettingsSnapshot = ToucherSettingsSnapshot()
    private var statusItem: NSStatusItem?
    private let appNameMenuItem = NSMenuItem(title: "Toucher", action: nil, keyEquivalent: "")
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let lastMovementModeMenuItem = NSMenuItem(title: "Last movement mode: none", action: nil, keyEquivalent: "")
    private let lastMovementKindMenuItem = NSMenuItem(title: "Last movement kind: none", action: nil, keyEquivalent: "")
    private let animateMovementEnabledMenuItem = NSMenuItem(title: "Animate movement enabled: unknown", action: nil, keyEquivalent: "")
    private let animationStepsSettingMenuItem = NSMenuItem(title: "Animation steps setting: 0", action: nil, keyEquivalent: "")
    private let animationDurationSettingMenuItem = NSMenuItem(title: "Animation duration setting: 0.00s", action: nil, keyEquivalent: "")
    private let lastMovementStepsPlannedMenuItem = NSMenuItem(title: "Last movement steps planned: 0", action: nil, keyEquivalent: "")
    private let lastMovementStepsAppliedMenuItem = NSMenuItem(title: "Last movement steps applied: 0", action: nil, keyEquivalent: "")
    private let lastMovementStepsSkippedMenuItem = NSMenuItem(title: "Last movement steps skipped: 0", action: nil, keyEquivalent: "")
    private let lastMovementRequestedDurationMenuItem = NSMenuItem(title: "Last movement requested duration: none", action: nil, keyEquivalent: "")
    private let lastMovementActualElapsedDurationMenuItem = NSMenuItem(title: "Last movement actual elapsed duration: none", action: nil, keyEquivalent: "")
    private let lastMovementStartFrameMenuItem = NSMenuItem(title: "Last movement start frame: none", action: nil, keyEquivalent: "")
    private let lastMovementTargetFrameMenuItem = NSMenuItem(title: "Last movement target frame: none", action: nil, keyEquivalent: "")
    private let lastMovementFinalFrameMenuItem = NSMenuItem(title: "Last movement final readback frame: none", action: nil, keyEquivalent: "")
    private let lastMovementErrorMenuItem = NSMenuItem(title: "Last movement error: none", action: nil, keyEquivalent: "")
    private let lastMovementFallbackUsedMenuItem = NSMenuItem(title: "Last movement fallback used: no", action: nil, keyEquivalent: "")
    private let accessibilityTrustedMenuItem = NSMenuItem(title: "Accessibility trusted: unknown", action: nil, keyEquivalent: "")
    private let appBundleIDMenuItem = NSMenuItem(title: "App bundle id: unknown", action: nil, keyEquivalent: "")
    private let appBundlePathMenuItem = NSMenuItem(title: "App bundle path: unknown", action: nil, keyEquivalent: "")
    private let gesturesEnabledMenuItem = NSMenuItem(title: "Gestures enabled: unknown", action: nil, keyEquivalent: "")
    private let gestureBackendMenuItem = NSMenuItem(title: "Gesture backend: raw multitouch", action: nil, keyEquivalent: "")
    private let gestureMonitorMenuItem = NSMenuItem(title: "Gesture monitor: inactive", action: nil, keyEquivalent: "")
    private let rawMultitouchAvailableMenuItem = NSMenuItem(title: "Raw multitouch available: unknown", action: nil, keyEquivalent: "")
    private let rawMultitouchActiveMenuItem = NSMenuItem(title: "Raw multitouch active: unknown", action: nil, keyEquivalent: "")
    private let rawDevicesFoundMenuItem = NSMenuItem(title: "Raw devices found: 0", action: nil, keyEquivalent: "")
    private let rawActiveTouchesMenuItem = NSMenuItem(title: "Active touches: 0", action: nil, keyEquivalent: "")
    private let lastRawGestureMenuItem = NSMenuItem(title: "Last raw gesture: none", action: nil, keyEquivalent: "")
    private let lastRawCentroidDeltaMenuItem = NSMenuItem(title: "Last raw centroid dx/dy: none", action: nil, keyEquivalent: "")
    private let lastRawGestureActionMenuItem = NSMenuItem(title: "Last raw gesture action: none", action: nil, keyEquivalent: "")
    private let lastRawGestureIgnoredReasonMenuItem = NSMenuItem(title: "Last raw ignored reason: none", action: nil, keyEquivalent: "")
    private let lastRawErrorMenuItem = NSMenuItem(title: "Last raw error: none", action: nil, keyEquivalent: "")
    private let gestureProbeMenuItem = NSMenuItem(title: "Diagnostics window: inactive", action: nil, keyEquivalent: "")
    private let lastPublicEventTypeMenuItem = NSMenuItem(title: "Last public event type: none", action: nil, keyEquivalent: "")
    private let lastPublicEventTimestampMenuItem = NSMenuItem(title: "Last public event timestamp: none", action: nil, keyEquivalent: "")
    private let lastPublicEventDeltaMenuItem = NSMenuItem(title: "Last public event dx/dy: none", action: nil, keyEquivalent: "")
    private let lastScrollDeltaMenuItem = NSMenuItem(title: "Last scroll deltaX/deltaY: none", action: nil, keyEquivalent: "")
    private let lastScrollScrollingDeltaMenuItem = NSMenuItem(title: "Last scroll scrollingDeltaX/scrollingDeltaY: none", action: nil, keyEquivalent: "")
    private let accumulatedScrollDeltaMenuItem = NSMenuItem(title: "Accumulated scroll dx/dy: none", action: nil, keyEquivalent: "")
    private let lastScrollPreciseMenuItem = NSMenuItem(title: "Last scroll precise: unknown", action: nil, keyEquivalent: "")
    private let lastScrollDirectionInvertedMenuItem = NSMenuItem(title: "Last scroll direction inverted: unknown", action: nil, keyEquivalent: "")
    private let lastPublicEventPhaseMenuItem = NSMenuItem(title: "Last public event phase: none", action: nil, keyEquivalent: "")
    private let lastPublicEventMomentumPhaseMenuItem = NSMenuItem(title: "Last public event momentumPhase: none", action: nil, keyEquivalent: "")
    private let eventCountersMenuItem = NSMenuItem(title: "Event counters: none", action: nil, keyEquivalent: "")
    private let lastGestureEventMenuItem = NSMenuItem(title: "Last gesture event: none", action: nil, keyEquivalent: "")
    private let lastGestureActionMenuItem = NSMenuItem(title: "Last gesture action: none", action: nil, keyEquivalent: "")
    private let lastGestureIgnoredReasonMenuItem = NSMenuItem(title: "Last gesture ignored reason: noEventReceived", action: nil, keyEquivalent: "")
    private let settingsMenuItem = NSMenuItem(
        title: StatusMenuPresentationModel.settingsTitle(accessibilityTrusted: true),
        action: #selector(openSettingsFromMenu),
        keyEquivalent: ""
    )
    private let accessibilitySettingsActionItem = NSMenuItem(
        title: ToucherMainMenuModel.accessibilityTitle(isTrusted: true),
        action: #selector(openAccessibilitySettings),
        keyEquivalent: ""
    )
    private var lastGestureEventDescription = "none"
    private var lastGestureActionDescription = "none"
    private var lastGestureIgnoredReasonDescription = GestureIgnoredReason.noEventReceived.rawValue
    private var aboutWindowController: AboutWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBarItem()
        settings.onChange = { [weak self] in
            self?.applySettingsChange()
        }
        appliedSettingsSnapshot = settings.snapshot
        rebuildRawRecognizer()
        refreshAXMovementLayer()

        guard let commandHandler else {
            setStatus("Could not initialize window control")
            return
        }
        configureGestureBackend(commandHandler: commandHandler)

        hotKeyCoordinator = HotKeyCoordinator(registrar: hotKeyRegistrar) { [weak self] action, options in
            self?.performWindowAction(action, screenTarget: options.screenTarget) ?? .failed(.failedToSetWindowFrame)
        }

        do {
            try hotKeyCoordinator?.start()
            showInitialStatus()
        } catch {
            setStatus("Hotkeys unavailable")
            NSLog("Toucher failed to register hotkeys: \(String(describing: error))")
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        _ = checkAccessibilityTrust(reason: "app became active")
        refreshDebugInfo()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopAccessibilityPolling(force: true)
        hotKeyCoordinator?.stop()
        stopGestureBackends()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        _ = checkAccessibilityTrust(reason: "menu open")
        refreshDebugInfo()
    }
}

private extension AppDelegate {
    static func makeStatusIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let stroke = NSColor.labelColor
        stroke.setStroke()

        let scaleX = size.width / 18
        let scaleY = size.height / 18
        func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> NSRect {
            NSRect(x: x * scaleX, y: y * scaleY, width: width * scaleX, height: height * scaleY)
        }

        let trackpad = NSBezierPath(roundedRect: rect(2.5, 3, 13, 11), xRadius: 3 * scaleX, yRadius: 3 * scaleY)
        trackpad.lineWidth = 1.4 * min(scaleX, scaleY)
        trackpad.stroke()

        for x in [6.0, 9.0, 12.0] {
            let dot = NSBezierPath(ovalIn: rect(x - 0.8, 10, 1.6, 1.6))
            stroke.setFill()
            dot.fill()
        }

        let line = NSBezierPath()
        line.move(to: NSPoint(x: 5.2 * scaleX, y: 6.2 * scaleY))
        line.line(to: NSPoint(x: 12.8 * scaleX, y: 6.2 * scaleY))
        line.lineWidth = 1.2 * min(scaleX, scaleY)
        line.stroke()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Toucher"
        return image
    }

    func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = Self.makeStatusIcon()
            button.title = ""
        }

        let menu = NSMenu()
        menu.delegate = self
        appNameMenuItem.isEnabled = false
        statusMenuItem.isEnabled = false
        lastMovementModeMenuItem.isEnabled = false
        lastMovementKindMenuItem.isEnabled = false
        animateMovementEnabledMenuItem.isEnabled = false
        animationStepsSettingMenuItem.isEnabled = false
        animationDurationSettingMenuItem.isEnabled = false
        lastMovementStepsPlannedMenuItem.isEnabled = false
        lastMovementStepsAppliedMenuItem.isEnabled = false
        lastMovementStepsSkippedMenuItem.isEnabled = false
        lastMovementRequestedDurationMenuItem.isEnabled = false
        lastMovementActualElapsedDurationMenuItem.isEnabled = false
        lastMovementStartFrameMenuItem.isEnabled = false
        lastMovementTargetFrameMenuItem.isEnabled = false
        lastMovementFinalFrameMenuItem.isEnabled = false
        lastMovementErrorMenuItem.isEnabled = false
        lastMovementFallbackUsedMenuItem.isEnabled = false
        accessibilityTrustedMenuItem.isEnabled = false
        appBundleIDMenuItem.isEnabled = false
        appBundlePathMenuItem.isEnabled = false
        gesturesEnabledMenuItem.isEnabled = false
        gestureBackendMenuItem.isEnabled = false
        gestureMonitorMenuItem.isEnabled = false
        rawMultitouchAvailableMenuItem.isEnabled = false
        rawMultitouchActiveMenuItem.isEnabled = false
        rawDevicesFoundMenuItem.isEnabled = false
        rawActiveTouchesMenuItem.isEnabled = false
        lastRawGestureMenuItem.isEnabled = false
        lastRawCentroidDeltaMenuItem.isEnabled = false
        lastRawGestureActionMenuItem.isEnabled = false
        lastRawGestureIgnoredReasonMenuItem.isEnabled = false
        lastRawErrorMenuItem.isEnabled = false
        gestureProbeMenuItem.isEnabled = false
        lastPublicEventTypeMenuItem.isEnabled = false
        lastPublicEventTimestampMenuItem.isEnabled = false
        lastPublicEventDeltaMenuItem.isEnabled = false
        lastScrollDeltaMenuItem.isEnabled = false
        lastScrollScrollingDeltaMenuItem.isEnabled = false
        accumulatedScrollDeltaMenuItem.isEnabled = false
        lastScrollPreciseMenuItem.isEnabled = false
        lastScrollDirectionInvertedMenuItem.isEnabled = false
        lastPublicEventPhaseMenuItem.isEnabled = false
        lastPublicEventMomentumPhaseMenuItem.isEnabled = false
        eventCountersMenuItem.isEnabled = false
        lastGestureEventMenuItem.isEnabled = false
        lastGestureActionMenuItem.isEnabled = false
        lastGestureIgnoredReasonMenuItem.isEnabled = false
        let aboutItem = NSMenuItem(
            title: "About Toucher",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)

        let quitItem = NSMenuItem(
            title: "Quit Toucher",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    func configureGestureBackend(
        commandHandler: WindowCommandHandler<AccessibilityTrustProvider, ImmediateAccessibilityWindowController>
    ) {
        stopGestureBackends()
        guard settings.enableGestures else {
            gestureBackendDescription = "off"
            refreshDebugInfo()
            return
        }

        switch selectedGestureBackendPreference() {
        case .off:
            gestureBackendDescription = "off"
            refreshDebugInfo()
        case .public:
            startPublicGestureBackend(commandHandler: commandHandler, primary: true)
        case .raw:
            _ = startRawGestureBackend(commandHandler: commandHandler)
        }
    }

    func selectedGestureBackendPreference() -> ToucherBackendPreference {
        let environmentValue = ProcessInfo.processInfo.environment["WINDOWGESTURES_GESTURE_BACKEND"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let environmentValue,
           let preference = ToucherBackendPreference(rawValue: environmentValue) {
            return preference
        }

        return settings.gestureBackend
    }

    func startPublicGestureBackend(
        commandHandler: WindowCommandHandler<AccessibilityTrustProvider, ImmediateAccessibilityWindowController>,
        primary: Bool
    ) {
        guard publicGestureBackend == nil else {
            return
        }

        let backend = PublicNSEventSwipeBackend { [weak self, commandHandler] input in
            DispatchQueue.main.async {
                self?.handlePublicGestureEvent(input, commandHandler: commandHandler)
            }
        }
        publicGestureBackend = backend
        if primary {
            gestureBackend = backend
            gestureBackendDescription = "public NSEvent"
        }
        backend.start()
        refreshDebugInfo()
    }

    func startRawGestureBackend(
        commandHandler: WindowCommandHandler<AccessibilityTrustProvider, ImmediateAccessibilityWindowController>
    ) -> Bool {
        let backend = RawMultitouchBackend(
            handleSample: { [weak self, commandHandler] sample in
                DispatchQueue.main.async {
                    self?.handleRawTouchSample(sample, commandHandler: commandHandler)
                }
            },
            handleStatus: { [weak self] status in
                DispatchQueue.main.async {
                    self?.rawMultitouchStatus = status
                    self?.refreshDebugInfo()
                    if let self {
                        self.scheduleMovementDiagnosticsUpdate()
                    }
                }
            }
        )
        rawGestureBackend = backend
        gestureBackend = backend
        gestureBackendDescription = "raw multitouch"
        backend.start()
        rawMultitouchStatus = backend.status
        refreshDebugInfo()
        if backend.isActive,
           settings.enableDiagnostics {
            startPublicGestureBackend(commandHandler: commandHandler, primary: false)
        }
        if !backend.isActive,
           settings.gestureBackend == .raw,
           ProcessInfo.processInfo.environment["WINDOWGESTURES_GESTURE_BACKEND"] == nil {
            startPublicGestureBackend(commandHandler: commandHandler, primary: true)
        }

        return backend.isActive
    }

    func stopGestureBackends() {
        rawGestureBackend?.stop()
        publicGestureBackend?.stop()
        rawGestureBackend = nil
        publicGestureBackend = nil
        gestureBackend = nil
        rawMultitouchStatus = RawMultitouchBackendStatus()
    }

    func showInitialStatus() {
        if checkAccessibilityTrust(reason: "initial status") {
            setStatus("Ready")
        } else {
            setStatus("Accessibility required")
        }
    }

    func show(_ result: WindowCommandResult) {
        switch result {
        case .moved:
            setStatus("Moved active window")
        case .failed(.accessibilityPermissionMissing):
            setStatus("Accessibility required")
        case .failed(.noFocusedApplication), .failed(.noFocusedWindow):
            setStatus("No active window found")
        case .failed(.unsupportedWindow):
            setStatus("Focused window cannot be resized")
        case .failed(.failedToReadWindowFrame):
            setStatus("Could not read active window")
        case .failed(.failedToSetWindowFrame):
            setStatus("Could not move active window")
        case .failed(.noStoredFrame):
            setStatus("No previous window frame")
        }
    }

    func setStatus(_ value: String) {
        refreshDebugInfo()
        setStatusTitleOnly(value)
    }

    func setStatusTitleOnly(_ value: String) {
        statusMenuItem.title = "Status: \(value)"
        statusItem?.button?.toolTip = "Toucher - \(value)"
    }

    func refreshDebugInfo() {
        let isTrusted = checkAccessibilityTrust(reason: "diagnostics refresh")
        let trusted = isTrusted ? "yes" : "no"
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let bundlePath = Bundle.main.bundleURL.path
        let gestureMonitor = gestureBackend?.isActive == true ? "active" : "inactive"
        let gestureProbe = gestureProbeWindowController?.isWindowOpen == true ? "active" : "inactive"
        let diagnostics = gestureDiagnostics.snapshot
        let movementDiagnostics = windowController.diagnostics
        let showVerboseDiagnostics = settings.enableDiagnostics ||
            settings.gestureBackend == .public ||
            gestureProbeWindowController?.isWindowOpen == true
        let showPublicDiagnostics = showVerboseDiagnostics

        settingsMenuItem.title = StatusMenuPresentationModel.settingsTitle(accessibilityTrusted: isTrusted)
        accessibilitySettingsActionItem.title = ToucherMainMenuModel.accessibilityTitle(isTrusted: isTrusted)
        accessibilityTrustedMenuItem.title = "Accessibility trusted: \(trusted)"
        lastMovementModeMenuItem.title = "Last movement mode: \(movementDiagnostics.lastMovementMode)"
        lastMovementKindMenuItem.title = "Last movement kind: \(movementDiagnostics.lastMovementKind)"
        animateMovementEnabledMenuItem.title = "Animate movement: \(settings.animateWindowMovement ? "On" : "Off")"
        animationStepsSettingMenuItem.title = "Animation steps setting: \(settings.movementAnimationSteps)"
        animationDurationSettingMenuItem.title = String(format: "Animation duration setting: %.2fs", settings.movementAnimationDuration)
        lastMovementStepsPlannedMenuItem.title = "Last movement steps planned: \(movementDiagnostics.lastMovementStepsPlanned)"
        lastMovementStepsAppliedMenuItem.title = "Last movement steps applied: \(movementDiagnostics.lastMovementStepsApplied)"
        lastMovementStepsSkippedMenuItem.title = "Last movement steps skipped: \(movementDiagnostics.lastMovementStepsSkipped)"
        lastMovementRequestedDurationMenuItem.title = "Last movement requested duration: \(formatDuration(movementDiagnostics.lastMovementRequestedDuration))"
        lastMovementActualElapsedDurationMenuItem.title = "Last movement actual elapsed duration: \(formatDuration(movementDiagnostics.lastMovementActualElapsedDuration))"
        lastMovementStartFrameMenuItem.title = "Last movement start frame: \(formatRect(movementDiagnostics.lastStartFrame))"
        lastMovementTargetFrameMenuItem.title = "Last movement target frame: \(formatRect(movementDiagnostics.lastTargetFrame))"
        lastMovementFinalFrameMenuItem.title = "Last movement final readback frame: \(formatRect(movementDiagnostics.lastFinalReadbackFrame))"
        lastMovementErrorMenuItem.title = "Last movement error: \(movementDiagnostics.lastMovementError ?? "none")"
        lastMovementFallbackUsedMenuItem.title = "Last movement fallback used: \(movementDiagnostics.lastMovementFallbackUsed ? "yes" : "no")"
        appBundleIDMenuItem.title = "App bundle id: \(bundleID)"
        appBundlePathMenuItem.title = "App bundle path: \(bundlePath)"
        gesturesEnabledMenuItem.title = "Gestures enabled: \(settings.enableGestures ? "yes" : "no")"
        gestureBackendMenuItem.title = "Gesture backend: \(menuGestureBackendDescription)"
        gestureMonitorMenuItem.title = "Gesture monitor: \(gestureMonitor)"
        rawMultitouchAvailableMenuItem.title = "Raw multitouch available: \(rawMultitouchStatus.isAvailable ? "yes" : "no")"
        rawMultitouchActiveMenuItem.title = "Raw multitouch active: \(rawMultitouchStatus.isActive ? "yes" : "no")"
        rawDevicesFoundMenuItem.title = "Raw devices found: \(rawMultitouchStatus.devicesFound)"
        rawActiveTouchesMenuItem.title = "Active touches: \(rawMultitouchStatus.activeTouches)"
        lastRawGestureMenuItem.title = "Last raw gesture: \(lastRawGestureDescription)"
        lastRawCentroidDeltaMenuItem.title = "Last raw centroid dx/dy: \(lastRawCentroidDeltaDescription)"
        lastRawGestureActionMenuItem.title = "Last raw gesture action: \(lastRawGestureActionDescription)"
        lastRawGestureIgnoredReasonMenuItem.title = "Last raw ignored reason: \(lastRawGestureIgnoredReasonDescription)"
        lastRawErrorMenuItem.title = "Last raw error: \(rawMultitouchStatus.lastError ?? "none")"
        gestureProbeMenuItem.title = "Diagnostics window: \(gestureProbe)"
        lastPublicEventTypeMenuItem.title = "Last public event type: \(diagnostics.lastEventType?.rawValue ?? "none")"
        lastPublicEventTimestampMenuItem.title = "Last public event timestamp: \(formatTimestamp(diagnostics.lastTimestamp))"
        lastPublicEventDeltaMenuItem.title = "Last public event dx/dy: \(formatDelta(diagnostics))"
        lastScrollDeltaMenuItem.title = "Last scroll deltaX/deltaY: \(formatPair(diagnostics.lastScrollDeltaX, diagnostics.lastScrollDeltaY))"
        lastScrollScrollingDeltaMenuItem.title = "Last scroll scrollingDeltaX/scrollingDeltaY: \(formatPair(diagnostics.lastScrollScrollingDeltaX, diagnostics.lastScrollScrollingDeltaY))"
        accumulatedScrollDeltaMenuItem.title = "Accumulated scroll dx/dy: \(formatPair(diagnostics.accumulatedScrollDeltaX, diagnostics.accumulatedScrollDeltaY))"
        lastScrollPreciseMenuItem.title = "Last scroll precise: \(formatBool(diagnostics.lastScrollHasPreciseScrollingDeltas))"
        lastScrollDirectionInvertedMenuItem.title = "Last scroll direction inverted: \(formatBool(diagnostics.lastScrollIsDirectionInvertedFromDevice))"
        lastPublicEventPhaseMenuItem.title = "Last public event phase: \(diagnostics.lastPhase ?? "none")"
        lastPublicEventMomentumPhaseMenuItem.title = "Last public event momentumPhase: \(diagnostics.lastMomentumPhase ?? "none")"
        eventCountersMenuItem.title = "Event counters: \(formatCounters(diagnostics.counters))"
        lastGestureEventMenuItem.title = "Last gesture event: \(lastGestureEventDescription)"
        lastGestureActionMenuItem.title = "Last gesture action: \(lastGestureActionDescription)"
        lastGestureIgnoredReasonMenuItem.title = "Last gesture ignored reason: \(lastGestureIgnoredReasonDescription)"
        [
            rawMultitouchAvailableMenuItem,
            rawDevicesFoundMenuItem,
            rawActiveTouchesMenuItem,
            lastRawCentroidDeltaMenuItem,
            lastRawErrorMenuItem,
            gestureProbeMenuItem
        ].forEach { $0.isHidden = !showVerboseDiagnostics }
        [
            lastPublicEventTypeMenuItem,
            lastPublicEventTimestampMenuItem,
            lastPublicEventDeltaMenuItem,
            lastScrollDeltaMenuItem,
            lastScrollScrollingDeltaMenuItem,
            accumulatedScrollDeltaMenuItem,
            lastScrollPreciseMenuItem,
            lastScrollDirectionInvertedMenuItem,
            lastPublicEventPhaseMenuItem,
            lastPublicEventMomentumPhaseMenuItem,
            eventCountersMenuItem,
            lastGestureEventMenuItem,
            lastGestureActionMenuItem,
            lastGestureIgnoredReasonMenuItem
        ].forEach { $0.isHidden = !showPublicDiagnostics }
    }

    @discardableResult
    func checkAccessibilityTrust(reason: String) -> Bool {
        let trusted = permissionChecker.hasAccessibilityPermission
        let previousTransitionCount = accessibilityTrustSnapshot.transitionCount
        accessibilityLastCheckedDescription = Self.accessibilityCheckFormatter.string(from: Date())
        let snapshot = accessibilityTrustMonitor.observe(isTrusted: trusted)
        accessibilityTrustSnapshot = snapshot

        if snapshot.transitionCount != previousTransitionCount {
            handleAccessibilityTransition(snapshot.lastTransition)
        }

        let shouldKeepMonitoring = AccessibilityPollingPolicy.shouldPoll(
            isTrusted: snapshot.isTrusted,
            waitingForAccessibility: snapshot.waitingForAccessibility,
            settingsWindowOpen: settingsWindowController?.isWindowOpen == true
        )
        if shouldKeepMonitoring {
            startAccessibilityPolling()
        } else {
            stopAccessibilityPolling()
        }

        settingsWindowController?.updateAccessibilityStatus(isTrusted: trusted)
        settingsMenuItem.title = StatusMenuPresentationModel.settingsTitle(accessibilityTrusted: trusted)
        return trusted
    }

    func handleAccessibilityTransition(_ transition: AccessibilityTrustTransition) {
        switch transition {
        case .none:
            return
        case .trustedToUntrusted:
            lastAXActionResult = "blocked"
            lastAXError = WindowMovementError.accessibilityPermissionMissing.debugName
            setStatusTitleOnly("Accessibility required")
        case .untrustedToTrusted:
            refreshAXMovementLayer()
            if let commandHandler {
                configureGestureBackend(commandHandler: commandHandler)
            }
            lastAXActionResult = "accessibilityRecovered"
            lastAXError = "none"
            setStatusTitleOnly("Ready")
        }
        scheduleMovementDiagnosticsUpdate()
    }

    func refreshAXMovementLayer() {
        let controller = ImmediateAccessibilityWindowController()
        controller.onDiagnosticsChange = { [weak self] in
            self?.refreshDebugInfo()
            self?.scheduleMovementDiagnosticsUpdate()
        }
        windowController = controller
        commandHandler = WindowCommandHandler(
            permissions: permissionChecker,
            windows: controller
        )
    }

    func markWaitingForAccessibility() {
        accessibilityTrustSnapshot = accessibilityTrustMonitor.markWaitingForAccessibility()
        startAccessibilityPolling()
        settingsWindowController?.updateAccessibilityStatus(isTrusted: permissionChecker.hasAccessibilityPermission)
        refreshDebugInfo()
    }

    func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self else { return }
            _ = self.checkAccessibilityTrust(reason: "accessibility poll")
            self.refreshDebugInfo()
        }
        accessibilityPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopAccessibilityPolling(force: Bool = false) {
        if !force, settingsWindowController?.isWindowOpen == true {
            return
        }
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    private static let accessibilityCheckFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    func handlePublicGestureEvent(
        _ input: PublicGestureEventInput,
        commandHandler: WindowCommandHandler<AccessibilityTrustProvider, ImmediateAccessibilityWindowController>
    ) {
        gestureDiagnostics.record(input)

        guard let recognition = gestureRecognizer.recognize(publicEvent: input) else {
            lastGestureActionDescription = "none"
            refreshDebugInfo()
            scheduleMovementDiagnosticsUpdate()
            return
        }

        lastGestureEventDescription = formatDelta(gestureDiagnostics.snapshot)

        switch recognition {
        case .action(let action):
            lastGestureActionDescription = action.debugName
            lastGestureIgnoredReasonDescription = "none"
            _ = commandHandler
            _ = performWindowAction(action, screenTarget: .current)
        case .ignored(let reason):
            lastGestureActionDescription = "ignored"
            lastGestureIgnoredReasonDescription = reason.rawValue
            refreshDebugInfo()
        }

        scheduleMovementDiagnosticsUpdate()
    }

    func handleRawTouchSample(
        _ sample: RawTouchSample,
        commandHandler: WindowCommandHandler<AccessibilityTrustProvider, ImmediateAccessibilityWindowController>
    ) {
        rawCallbacksCount += 1
        if sample.activeTouchCount == 3 {
            if lastRawGestureStartX == nil || lastRawGestureStartY == nil {
                lastRawGestureStartX = sample.centroidX
                lastRawGestureStartY = sample.centroidY
            }
            if let startX = lastRawGestureStartX,
               let startY = lastRawGestureStartY {
                lastRawCentroidDeltaDescription = formatPair(sample.centroidX - startX, sample.centroidY - startY)
            }
        } else {
            lastRawGestureStartX = nil
            lastRawGestureStartY = nil
        }

        switch rawGestureRecognizer.recognize(sample) {
        case .action(let action):
            lastRawGestureActionDescription = action.debugName
            lastRawGestureDescription = action.debugName
            lastAcceptedRawGestureDescription = action.debugName
            lastAcceptedRawDeltaDescription = lastRawCentroidDeltaDescription
            lastAcceptedRawDurationDescription = formatTimestamp(rawGestureRecognizer.diagnostics.lastGestureDuration)
            lastRawGestureIgnoredReasonDescription = "none"
            rawRecognizedGesturesCount += 1
            if action == .leftHalf {
                rawLeftGesturesCount += 1
            } else if action == .rightHalf {
                rawRightGesturesCount += 1
            } else if action == .maximize {
                rawUpGesturesCount += 1
            }
            appendRawEvent(sample: sample, result: action.debugName)
            _ = commandHandler
            _ = performWindowAction(action, screenTarget: currentModifierScreenTarget())
        case .ignored(let reason):
            if reason == .fingerCountChanged || reason == .unsupportedFingerCount {
                lastRawGestureStartX = nil
                lastRawGestureStartY = nil
            }
            rawIgnoredGesturesCount += 1
            if reason == .unsupportedFingerCount {
                rawUnsupportedFingerCountCount += 1
            }
            if reason == .fingerCountChanged {
                rawCanceledGesturesCount += 1
            }
            if sample.activeTouchCount == 3 || reason == .fingerCountChanged {
                appendRawEvent(sample: sample, result: reason.rawValue)
            }
            lastRawGestureIgnoredReasonDescription = reason.rawValue
            refreshDebugInfo()
        }

        scheduleMovementDiagnosticsUpdate()
    }

    func currentModifierScreenTarget() -> WindowScreenTarget {
        NSEvent.modifierFlags.contains(.command) ? .next : .current
    }

    func appendRawEvent(sample: RawTouchSample, result: String) {
        let event = String(
            format: "%.3f fingers=%d dxdy=%@ duration=%@ result=%@",
            sample.timestamp,
            sample.activeTouchCount,
            lastRawCentroidDeltaDescription,
            formatTimestamp(rawGestureRecognizer.diagnostics.lastGestureDuration),
            result
        )
        rawEventRingBuffer.append(event)
        if rawEventRingBuffer.count > 10 {
            rawEventRingBuffer.removeFirst(rawEventRingBuffer.count - 10)
        }
    }

    func rawDiagnosticsCounters() -> RawDiagnosticsCounters {
        RawDiagnosticsCounters(
            callbacks: rawCallbacksCount,
            recognized: rawRecognizedGesturesCount,
            left: rawLeftGesturesCount,
            right: rawRightGesturesCount,
            up: rawUpGesturesCount,
            ignored: rawIgnoredGesturesCount,
            unsupportedFingerCount: rawUnsupportedFingerCountCount,
            canceled: rawCanceledGesturesCount,
            lastAcceptedGesture: lastAcceptedRawGestureDescription,
            lastAcceptedDelta: lastAcceptedRawDeltaDescription,
            lastAcceptedDuration: lastAcceptedRawDurationDescription,
            lastIgnoredReason: lastRawGestureIgnoredReasonDescription
        )
    }

    func formatTimestamp(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else {
            return "none"
        }

        return String(format: "%.3f", timestamp)
    }

    func formatDelta(_ snapshot: GestureDiagnosticSnapshot) -> String {
        formatPair(snapshot.lastDeltaX, snapshot.lastDeltaY)
    }

    func formatPair(_ deltaX: Double?, _ deltaY: Double?) -> String {
        guard let deltaX,
              let deltaY else {
            return "none"
        }

        return String(format: "dx=%.3f, dy=%.3f", deltaX, deltaY)
    }

    func formatBool(_ value: Bool?) -> String {
        guard let value else {
            return "unknown"
        }

        return value ? "yes" : "no"
    }

    func formatRect(_ rect: Rect?) -> String {
        guard let rect else {
            return "none"
        }

        return String(
            format: "x=%.1f y=%.1f w=%.1f h=%.1f",
            rect.x,
            rect.y,
            rect.width,
            rect.height
        )
    }

    func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else {
            return "none"
        }

        return String(format: "%.3fs", duration)
    }

    func formatCounters(_ counters: GestureDiagnosticCounters) -> String {
        [
            "swipe \(counters.swipe)",
            "scrollWheel \(counters.scrollWheel)",
            "beginGesture \(counters.beginGesture)",
            "endGesture \(counters.endGesture)",
            "magnify \(counters.magnify)",
            "rotate \(counters.rotate)",
            "smartMagnify \(counters.smartMagnify)"
        ].joined(separator: ", ")
    }

    @objc func openAccessibilitySettings() {
        permissionChecker.openAccessibilitySettings()
        markWaitingForAccessibility()
    }

    func applySettingsChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.applySettingsChange()
            }
            return
        }

        guard !pendingSettingsApply else {
            return
        }

        pendingSettingsApply = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingSettingsApply = false
            self.applySettingsSnapshot(self.settings.snapshot)
        }
    }

    func applySettingsSnapshot(_ snapshot: ToucherSettingsSnapshot) {
        let oldSnapshot = appliedSettingsSnapshot
        appliedSettingsSnapshot = snapshot

        let recognizerChanged = oldSnapshot.rawMinDistance != snapshot.rawMinDistance ||
            oldSnapshot.rawDominanceRatio != snapshot.rawDominanceRatio ||
            oldSnapshot.rawCooldown != snapshot.rawCooldown ||
            oldSnapshot.invertGestureDirection != snapshot.invertGestureDirection

        if recognizerChanged {
            rebuildRawRecognizer()
        }

        let backendChanged = oldSnapshot.enableGestures != snapshot.enableGestures ||
            oldSnapshot.gestureBackend != snapshot.gestureBackend ||
            oldSnapshot.enableDiagnostics != snapshot.enableDiagnostics

        if backendChanged,
           let commandHandler {
            configureGestureBackend(commandHandler: commandHandler)
        }

        refreshDebugInfo()
    }

    @discardableResult
    func performWindowAction(_ action: WindowAction, screenTarget: WindowScreenTarget) -> WindowCommandResult {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                self.performWindowAction(action, screenTarget: screenTarget)
            }
        }

        guard let commandHandler else {
            lastAXActionAttempted = action.debugName
            lastAXActionResult = "failed"
            lastAXError = WindowMovementError.failedToSetWindowFrame.debugName
            return .failed(.failedToSetWindowFrame)
        }

        lastAXActionAttempted = action.debugName
        lastAXActionResult = "attempted"
        lastAXError = "none"
        _ = checkAccessibilityTrust(reason: "window action")
        let result = commandHandler.perform(
            action,
            options: WindowCommandOptions(
                screenTarget: screenTarget,
                movementMode: movementModeForCurrentSettings()
            )
        )
        switch result {
        case .moved:
            lastAXActionResult = "moved"
            lastAXError = "none"
        case .failed(let error):
            lastAXActionResult = "failed"
            lastAXError = error.debugName
            if error == .accessibilityPermissionMissing {
                markAccessibilityUnavailable()
            }
        }
        show(result)
        scheduleMovementDiagnosticsUpdate()
        return result
    }

    func markAccessibilityUnavailable() {
        let previousTransitionCount = accessibilityTrustSnapshot.transitionCount
        accessibilityLastCheckedDescription = Self.accessibilityCheckFormatter.string(from: Date())
        let snapshot = accessibilityTrustMonitor.observe(isTrusted: false)
        accessibilityTrustSnapshot = snapshot

        if snapshot.transitionCount != previousTransitionCount {
            handleAccessibilityTransition(snapshot.lastTransition)
        } else {
            lastAXActionResult = "blocked"
            lastAXError = WindowMovementError.accessibilityPermissionMissing.debugName
            setStatusTitleOnly("Accessibility required")
        }

        startAccessibilityPolling()
        settingsWindowController?.updateAccessibilityStatus(isTrusted: false)
        settingsMenuItem.title = StatusMenuPresentationModel.settingsTitle(accessibilityTrusted: false)
        refreshDebugInfo()
    }

    func movementModeForCurrentSettings() -> WindowMovementMode {
        settings.animateWindowMovement
            ? .discreteSteps(
                totalStepCount: settings.movementAnimationSteps,
                totalDuration: settings.movementAnimationDuration
            )
            : .immediate
    }

    var menuGestureBackendDescription: String {
        if !settings.enableGestures || settings.gestureBackend == .off {
            return "Off"
        }

        if settings.gestureBackend == .raw {
            return rawMultitouchStatus.isActive ? "Raw multitouch" : "Raw multitouch unavailable"
        }

        return gestureBackend?.isActive == true ? "Public NSEvent diagnostics" : "Unavailable"
    }

    func scheduleMovementDiagnosticsUpdate() {
        gestureProbeWindowController?.scheduleUpdate(
            accessibilityTrusted: permissionChecker.hasAccessibilityPermission,
            accessibilityLastChecked: accessibilityLastCheckedDescription,
            accessibilityTransitionCount: accessibilityTrustSnapshot.transitionCount,
            lastAccessibilityTransition: accessibilityTrustSnapshot.lastTransition.rawValue,
            waitingForAccessibility: accessibilityTrustSnapshot.waitingForAccessibility,
            lastAXActionAttempted: lastAXActionAttempted,
            lastAXActionResult: lastAXActionResult,
            lastAXError: lastAXError,
            screenGeometryDebugInfo: windowController.screenGeometryDebugInfo(
                actionTargetFrame: windowController.diagnostics.lastTargetFrame
            ),
            movementDiagnostics: windowController.diagnostics,
            animationStepsSetting: settings.movementAnimationSteps,
            animationDurationSetting: settings.movementAnimationDuration,
            rawStatus: rawMultitouchStatus,
            rawDiagnostics: rawGestureRecognizer.diagnostics,
            counters: rawDiagnosticsCounters(),
            events: rawEventRingBuffer
        )
    }

    func rebuildRawRecognizer() {
        rawGestureRecognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: settings.rawMinDistance,
            dominanceRatio: settings.rawDominanceRatio,
            maxGestureDuration: 0.8,
            cooldown: settings.rawCooldown,
            invertDirection: settings.invertGestureDirection,
            invertVerticalDirection: invertRawVerticalDirection
        )
    }

    @objc func openSettingsFromMenu() {
        let handler = SettingsMenuActionHandler(
            isAccessibilityTrusted: { [weak self] in
                self?.checkAccessibilityTrust(reason: "settings menu") ?? false
            },
            requestAccessibilityAlert: { [weak self] in
                self?.showAccessibilitySettingsAlert()
            },
            openSettings: { [weak self] in
                self?.openSettings()
            }
        )
        handler.handleSettingsSelected()
    }

    @objc func openSettings() {
        let trusted = checkAccessibilityTrust(reason: "open settings")
        if let controller = settingsWindowController,
           controller.isWindowOpen {
            controller.updateAccessibilityStatus(isTrusted: trusted)
            controller.show()
            return
        }

        let controller = SettingsWindowController(
            settings: settings,
            accessibilityStatusProvider: { [weak self] in
                self?.checkAccessibilityTrust(reason: "settings window") ?? false
            },
            openAccessibilitySettings: { [weak self] in
                self?.openAccessibilitySettings()
            },
            openGestureDiagnostics: { [weak self] in
                self?.openGestureProbeWindow()
            }
        )
        controller.onClose = { [weak self] in
            DispatchQueue.main.async {
                self?.settingsWindowController = nil
                self?.stopAccessibilityPolling()
            }
        }
        settingsWindowController = controller
        controller.updateAccessibilityStatus(isTrusted: trusted)
        controller.show()
    }

    func showAccessibilitySettingsAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Toucher needs Accessibility access to move and resize windows. Open Settings to enable access and view status."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.runModal()
    }

    @objc func openGestureProbeWindow() {
        let controller = gestureProbeWindowController ?? GestureProbeWindowController()
        gestureProbeWindowController = controller
        controller.onClose = { [weak self] in
            DispatchQueue.main.async {
                self?.gestureProbeWindowController = nil
                self?.handleGestureProbeWindowClosed()
            }
        }
        if settings.gestureBackend != .public,
           publicGestureBackend == nil,
           let commandHandler {
            startPublicGestureBackend(commandHandler: commandHandler, primary: false)
        }
        controller.show(
            publicSnapshot: gestureDiagnostics.snapshot,
            accessibilityTrusted: permissionChecker.hasAccessibilityPermission,
            accessibilityLastChecked: accessibilityLastCheckedDescription,
            accessibilityTransitionCount: accessibilityTrustSnapshot.transitionCount,
            lastAccessibilityTransition: accessibilityTrustSnapshot.lastTransition.rawValue,
            waitingForAccessibility: accessibilityTrustSnapshot.waitingForAccessibility,
            lastAXActionAttempted: lastAXActionAttempted,
            lastAXActionResult: lastAXActionResult,
            lastAXError: lastAXError,
            screenGeometryDebugInfo: windowController.screenGeometryDebugInfo(
                actionTargetFrame: windowController.diagnostics.lastTargetFrame
            ),
            movementDiagnostics: windowController.diagnostics,
            animationStepsSetting: settings.movementAnimationSteps,
            animationDurationSetting: settings.movementAnimationDuration,
            rawStatus: rawMultitouchStatus,
            rawDiagnostics: rawGestureRecognizer.diagnostics,
            counters: rawDiagnosticsCounters(),
            events: rawEventRingBuffer
        )
        refreshDebugInfo()
    }

    @objc func openAbout() {
        if let controller = aboutWindowController,
           controller.isWindowOpen {
            controller.show()
            return
        }

        let controller = AboutWindowController(model: AboutToucherModel())
        controller.onClose = { [weak self] in
            DispatchQueue.main.async {
                self?.aboutWindowController = nil
            }
        }
        aboutWindowController = controller
        controller.show()
    }

    func handleGestureProbeWindowClosed() {
        if !settings.enableDiagnostics,
           settings.gestureBackend != .public,
           gestureBackendDescription == "raw multitouch" {
            publicGestureBackend?.stop()
            publicGestureBackend = nil
        }
        refreshDebugInfo()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

private struct RawDiagnosticsCounters {
    var callbacks: Int
    var recognized: Int
    var left: Int
    var right: Int
    var up: Int
    var ignored: Int
    var unsupportedFingerCount: Int
    var canceled: Int
    var lastAcceptedGesture: String
    var lastAcceptedDelta: String
    var lastAcceptedDuration: String
    var lastIgnoredReason: String
}

private final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: ToucherSettings
    private let accessibilityStatusProvider: () -> Bool
    private let openAccessibilitySettingsHandler: () -> Void
    private let openGestureDiagnosticsHandler: () -> Void
    private var window: NSWindow?
    private var sleeves: [ClosureSleeve] = []
    private var accessibilityStatusLabel: NSTextField?
    private var accessibilityWarningLabel: NSTextField?
    private var accessibilityPollTimer: Timer?
    var onClose: (() -> Void)?

    var isWindowOpen: Bool {
        window?.isVisible == true
    }

    init(
        settings: ToucherSettings,
        accessibilityStatusProvider: @escaping () -> Bool,
        openAccessibilitySettings: @escaping () -> Void,
        openGestureDiagnostics: @escaping () -> Void
    ) {
        self.settings = settings
        self.accessibilityStatusProvider = accessibilityStatusProvider
        self.openAccessibilitySettingsHandler = openAccessibilitySettings
        self.openGestureDiagnosticsHandler = openGestureDiagnostics
    }

    func show() {
        if window == nil {
            let size = NSSize(
                width: ToucherSettingsLayoutModel.windowWidth,
                height: ToucherSettingsLayoutModel.windowHeight
            )
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Toucher Settings"
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.minSize = size
            window.maxSize = size
            window.center()
            window.contentView = makeContentView()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        updateAccessibilityStatus(isTrusted: accessibilityStatusProvider())
        startAccessibilityStatusUpdates()
    }

    func windowWillClose(_ notification: Notification) {
        stopAccessibilityStatusUpdates()
        sleeves.removeAll()
        window = nil
        onClose?()
    }

    func updateAccessibilityStatus(isTrusted: Bool) {
        accessibilityStatusLabel?.stringValue = "Accessibility: \(isTrusted ? "Enabled" : "Not enabled")"
        accessibilityStatusLabel?.textColor = isTrusted ? .secondaryLabelColor : .systemOrange
        accessibilityWarningLabel?.isHidden = isTrusted
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    private func makeContentView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = CGFloat(ToucherSettingsLayoutModel.sectionSpacing)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(section("Gestures", views: [
            checkbox("Enable trackpad gestures", value: settings.enableGestures) { [settings] in
                settings.enableGestures = $0
            },
            secondaryText("Use trackpad gestures to move and resize windows.")
        ]))

        stack.addArrangedSubview(section("Movement", views: [
            checkbox("Animate window movement", value: settings.animateWindowMovement) { [settings] in
                settings.animateWindowMovement = $0
            },
            intSlider(
                "Animation steps",
                value: settings.movementAnimationSteps,
                range: 3...32
            ) { [settings] in
                settings.movementAnimationSteps = $0
            },
            doubleSlider(
                "Animation duration",
                value: settings.movementAnimationDuration,
                range: 0.02...0.60,
                format: "%.2fs"
            ) { [settings] in
                settings.movementAnimationDuration = $0
            }
        ]))

        stack.addArrangedSubview(section("System Access", views: [
            accessibilityStatusView(),
            actionButton("Accessibility Settings…") { [weak self] in
                self?.openAccessibilitySettingsHandler()
            }
        ]))

        stack.addArrangedSubview(section("Diagnostics", views: [
            actionButton("Gesture Diagnostics…") { [weak self] in
                self?.openGestureDiagnosticsHandler()
            },
            secondaryText("Open diagnostic information for gesture recognition and window movement.")
        ]))

        let footer = NSTextField(labelWithString: "Toucher \(BuildInfo.version) • Built \(BuildInfo.buildDate)")
        footer.textColor = .tertiaryLabelColor
        footer.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(footer)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(ToucherSettingsLayoutModel.contentMargin)),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(ToucherSettingsLayoutModel.contentMargin)),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(ToucherSettingsLayoutModel.contentMargin)),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -CGFloat(ToucherSettingsLayoutModel.contentMargin))
        ])
        return view
    }

    private func checkbox(_ title: String, value: Bool, onChange: @escaping (Bool) -> Void) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.state = value ? .on : .off
        let sleeve = ClosureSleeve { [weak button] in
            onChange(button?.state == .on)
        }
        sleeves.append(sleeve)
        button.target = sleeve
        button.action = #selector(ClosureSleeve.invoke)
        return button
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true
        let sleeve = ClosureSleeve(action)
        sleeves.append(sleeve)
        button.target = sleeve
        button.action = #selector(ClosureSleeve.invoke)
        return button
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func section(_ title: String, views: [NSView]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = CGFloat(ToucherSettingsLayoutModel.rowSpacing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sectionLabel(title))
        views.forEach { stack.addArrangedSubview($0) }
        return stack
    }

    private func secondaryText(_ value: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.widthAnchor.constraint(equalToConstant: 492).isActive = true
        return label
    }

    private func accessibilityStatusView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let status = NSTextField(labelWithString: "Accessibility: Checking…")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .secondaryLabelColor
        accessibilityStatusLabel = status
        stack.addArrangedSubview(status)

        let warningContainer = NSView()
        warningContainer.translatesAutoresizingMaskIntoConstraints = false
        warningContainer.heightAnchor.constraint(equalToConstant: CGFloat(ToucherSettingsLayoutModel.warningAreaHeight)).isActive = true
        warningContainer.widthAnchor.constraint(equalToConstant: 492).isActive = true

        let warning = NSTextField(wrappingLabelWithString: "Toucher needs Accessibility access to move and resize windows. Enable Toucher in System Settings, then return here; the status updates automatically.")
        warning.translatesAutoresizingMaskIntoConstraints = false
        warning.font = .systemFont(ofSize: 12)
        warning.textColor = .systemOrange
        warning.maximumNumberOfLines = 2
        accessibilityWarningLabel = warning
        warningContainer.addSubview(warning)
        NSLayoutConstraint.activate([
            warning.leadingAnchor.constraint(equalTo: warningContainer.leadingAnchor),
            warning.trailingAnchor.constraint(equalTo: warningContainer.trailingAnchor),
            warning.topAnchor.constraint(equalTo: warningContainer.topAnchor),
            warning.bottomAnchor.constraint(lessThanOrEqualTo: warningContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(warningContainer)

        return stack
    }

    private func popup(_ title: String, items: [String], selected: String, onChange: @escaping (String) -> Void) -> NSView {
        let label = NSTextField(labelWithString: title)
        let popup = NSPopUpButton()
        popup.addItems(withTitles: items)
        popup.selectItem(withTitle: selected)
        let sleeve = ClosureSleeve { [weak popup] in
            onChange(popup?.selectedItem?.title ?? selected)
        }
        sleeves.append(sleeve)
        popup.target = sleeve
        popup.action = #selector(ClosureSleeve.invoke)
        return row(label, popup)
    }

    private func numberField(_ title: String, value: Double, onChange: @escaping (Double) -> Void) -> NSView {
        let label = NSTextField(labelWithString: title)
        let field = NSTextField(string: String(format: "%.3f", value))
        let sleeve = ClosureSleeve { [weak field] in
            onChange(Double(field?.stringValue ?? "") ?? value)
        }
        sleeves.append(sleeve)
        field.target = sleeve
        field.action = #selector(ClosureSleeve.invoke)
        return row(label, field)
    }

    private func intSlider(
        _ title: String,
        value: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> NSView {
        let label = NSTextField(labelWithString: title)
        let slider = NSSlider(
            value: Double(value),
            minValue: Double(range.lowerBound),
            maxValue: Double(range.upperBound),
            target: nil,
            action: nil
        )
        slider.numberOfTickMarks = range.upperBound - range.lowerBound + 1
        slider.allowsTickMarkValuesOnly = true
        let valueLabel = NSTextField(labelWithString: "\(value)")
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let sleeve = ClosureSleeve { [weak slider, weak valueLabel] in
            let nextValue = Int((slider?.doubleValue ?? Double(value)).rounded())
            valueLabel?.stringValue = "\(nextValue)"
            onChange(nextValue)
        }
        sleeves.append(sleeve)
        slider.target = sleeve
        slider.action = #selector(ClosureSleeve.invoke)
        return row(label, sliderValueStack(slider: slider, valueLabel: valueLabel))
    }

    private func doubleSlider(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        format: String,
        onChange: @escaping (Double) -> Void
    ) -> NSView {
        let label = NSTextField(labelWithString: title)
        let slider = NSSlider(
            value: value,
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            target: nil,
            action: nil
        )
        let valueLabel = NSTextField(labelWithString: String(format: format, value))
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 54).isActive = true
        let sleeve = ClosureSleeve { [weak slider, weak valueLabel] in
            let nextValue = slider?.doubleValue ?? value
            valueLabel?.stringValue = String(format: format, nextValue)
            onChange(nextValue)
        }
        sleeves.append(sleeve)
        slider.target = sleeve
        slider.action = #selector(ClosureSleeve.invoke)
        return row(label, sliderValueStack(slider: slider, valueLabel: valueLabel))
    }

    private func row(_ label: NSView, _ control: NSView) -> NSView {
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 170).isActive = true
        control.widthAnchor.constraint(equalToConstant: 310).isActive = true
        return stack
    }

    private func sliderValueStack(slider: NSSlider, valueLabel: NSTextField) -> NSStackView {
        let stack = NSStackView(views: [slider, valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        slider.widthAnchor.constraint(equalToConstant: 242).isActive = true
        return stack
    }

    private func startAccessibilityStatusUpdates() {
        guard accessibilityPollTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateAccessibilityStatus(isTrusted: self.accessibilityStatusProvider())
        }
        accessibilityPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAccessibilityStatusUpdates() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }
}

private final class ClosureSleeve: NSObject {
    private let closure: () -> Void

    init(_ closure: @escaping () -> Void) {
        self.closure = closure
    }

    @objc func invoke() {
        closure()
    }
}

private final class AboutWindowController: NSObject, NSWindowDelegate {
    private let model: AboutToucherModel
    private var window: NSWindow?
    var onClose: (() -> Void)?

    var isWindowOpen: Bool {
        window?.isVisible == true
    }

    init(model: AboutToucherModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About Toucher"
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = makeContentView()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClose?()
    }

    private func makeContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 26, bottom: 18, right: 26)

        let icon = NSImageView(image: AppDelegate.makeStatusIcon(size: NSSize(width: 44, height: 44)))
        icon.setFrameSize(NSSize(width: 44, height: 44))
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: model.appName)
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        stack.addArrangedSubview(title)

        let version = NSTextField(labelWithString: "Version \(model.version)")
        version.textColor = .secondaryLabelColor
        version.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(version)

        let build = NSTextField(labelWithString: "Built \(model.buildDate)")
        build.textColor = .secondaryLabelColor
        build.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(build)

        let description = NSTextField(wrappingLabelWithString: model.description)
        description.alignment = .center
        description.font = .systemFont(ofSize: 13)
        description.maximumNumberOfLines = 2
        description.widthAnchor.constraint(equalToConstant: 300).isActive = true
        stack.addArrangedSubview(description)

        let repositoryButton = NSButton(title: model.repositoryDisplayText, target: self, action: #selector(openRepository))
        repositoryButton.isBordered = false
        repositoryButton.font = .systemFont(ofSize: 13, weight: .medium)
        repositoryButton.contentTintColor = .linkColor
        stack.addArrangedSubview(repositoryButton)

        let copyright = NSTextField(labelWithString: model.copyright)
        copyright.textColor = .secondaryLabelColor
        copyright.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(copyright)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 300))
        stack.frame = view.bounds
        stack.autoresizingMask = [.width, .height]
        view.addSubview(stack)
        return view
    }

    @objc private func openRepository() {
        guard let url = URL(string: model.repositoryOpenURL) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private final class GestureProbeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let textView = NSTextView()
    private var pendingUpdate: (() -> Void)?
    private var throttleTimer: Timer?
    private let updateInterval: TimeInterval = 0.125
    var onClose: (() -> Void)?

    var isWindowOpen: Bool {
        window?.isVisible == true
    }

    func show(
        publicSnapshot: GestureDiagnosticSnapshot,
        accessibilityTrusted: Bool,
        accessibilityLastChecked: String,
        accessibilityTransitionCount: Int,
        lastAccessibilityTransition: String,
        waitingForAccessibility: Bool,
        lastAXActionAttempted: String,
        lastAXActionResult: String,
        lastAXError: String,
        screenGeometryDebugInfo: String,
        movementDiagnostics: WindowMovementDiagnostics,
        animationStepsSetting: Int,
        animationDurationSetting: TimeInterval,
        rawStatus: RawMultitouchBackendStatus,
        rawDiagnostics: RawGestureDiagnosticSnapshot,
        counters: RawDiagnosticsCounters,
        events: [String]
    ) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Toucher Gesture Diagnostics"
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.center()

            textView.isEditable = false
            textView.isSelectable = true
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.autoresizingMask = [.width, .height]
            textView.frame = NSRect(x: 0, y: 0, width: 640, height: 600)
            window.contentView = textView
            self.window = window
        }

        update(
            publicSnapshot: publicSnapshot,
            accessibilityTrusted: accessibilityTrusted,
            accessibilityLastChecked: accessibilityLastChecked,
            accessibilityTransitionCount: accessibilityTransitionCount,
            lastAccessibilityTransition: lastAccessibilityTransition,
            waitingForAccessibility: waitingForAccessibility,
            lastAXActionAttempted: lastAXActionAttempted,
            lastAXActionResult: lastAXActionResult,
            lastAXError: lastAXError,
            screenGeometryDebugInfo: screenGeometryDebugInfo,
            movementDiagnostics: movementDiagnostics,
            animationStepsSetting: animationStepsSetting,
            animationDurationSetting: animationDurationSetting,
            rawStatus: rawStatus,
            rawDiagnostics: rawDiagnostics,
            counters: counters,
            events: events
        )
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func scheduleUpdate(
        accessibilityTrusted: Bool,
        accessibilityLastChecked: String,
        accessibilityTransitionCount: Int,
        lastAccessibilityTransition: String,
        waitingForAccessibility: Bool,
        lastAXActionAttempted: String,
        lastAXActionResult: String,
        lastAXError: String,
        screenGeometryDebugInfo: String,
        movementDiagnostics: WindowMovementDiagnostics,
        animationStepsSetting: Int,
        animationDurationSetting: TimeInterval,
        rawStatus: RawMultitouchBackendStatus,
        rawDiagnostics: RawGestureDiagnosticSnapshot,
        counters: RawDiagnosticsCounters,
        events: [String]
    ) {
        guard isWindowOpen else {
            return
        }

        pendingUpdate = { [weak self] in
            guard let self else { return }
            self.update(
                publicSnapshot: GestureDiagnosticSnapshot(),
                accessibilityTrusted: accessibilityTrusted,
                accessibilityLastChecked: accessibilityLastChecked,
                accessibilityTransitionCount: accessibilityTransitionCount,
                lastAccessibilityTransition: lastAccessibilityTransition,
                waitingForAccessibility: waitingForAccessibility,
                lastAXActionAttempted: lastAXActionAttempted,
                lastAXActionResult: lastAXActionResult,
                lastAXError: lastAXError,
                screenGeometryDebugInfo: screenGeometryDebugInfo,
                movementDiagnostics: movementDiagnostics,
                animationStepsSetting: animationStepsSetting,
                animationDurationSetting: animationDurationSetting,
                rawStatus: rawStatus,
                rawDiagnostics: rawDiagnostics,
                counters: counters,
                events: events
            )
        }

        guard throttleTimer == nil else {
            return
        }

        throttleTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: false) { [weak self] timer in
            self?.pendingUpdate?()
            self?.pendingUpdate = nil
            self?.throttleTimer = nil
            timer.invalidate()
        }
    }

    func update(
        publicSnapshot: GestureDiagnosticSnapshot,
        accessibilityTrusted: Bool,
        accessibilityLastChecked: String,
        accessibilityTransitionCount: Int,
        lastAccessibilityTransition: String,
        waitingForAccessibility: Bool,
        lastAXActionAttempted: String,
        lastAXActionResult: String,
        lastAXError: String,
        screenGeometryDebugInfo: String,
        movementDiagnostics: WindowMovementDiagnostics,
        animationStepsSetting: Int,
        animationDurationSetting: TimeInterval,
        rawStatus: RawMultitouchBackendStatus,
        rawDiagnostics: RawGestureDiagnosticSnapshot,
        counters: RawDiagnosticsCounters,
        events: [String]
    ) {
        textView.string = Self.render(
            publicSnapshot: publicSnapshot,
            accessibilityTrusted: accessibilityTrusted,
            accessibilityLastChecked: accessibilityLastChecked,
            accessibilityTransitionCount: accessibilityTransitionCount,
            lastAccessibilityTransition: lastAccessibilityTransition,
            waitingForAccessibility: waitingForAccessibility,
            lastAXActionAttempted: lastAXActionAttempted,
            lastAXActionResult: lastAXActionResult,
            lastAXError: lastAXError,
            screenGeometryDebugInfo: screenGeometryDebugInfo,
            movementDiagnostics: movementDiagnostics,
            animationStepsSetting: animationStepsSetting,
            animationDurationSetting: animationDurationSetting,
            rawStatus: rawStatus,
            rawDiagnostics: rawDiagnostics,
            counters: counters,
            events: events
        )
    }

    func windowWillClose(_ notification: Notification) {
        throttleTimer?.invalidate()
        throttleTimer = nil
        pendingUpdate = nil
        window = nil
        let closeHandler = onClose
        onClose = nil
        closeHandler?()
    }

    private static func render(
        publicSnapshot snapshot: GestureDiagnosticSnapshot,
        accessibilityTrusted: Bool,
        accessibilityLastChecked: String,
        accessibilityTransitionCount: Int,
        lastAccessibilityTransition: String,
        waitingForAccessibility: Bool,
        lastAXActionAttempted: String,
        lastAXActionResult: String,
        lastAXError: String,
        screenGeometryDebugInfo: String,
        movementDiagnostics: WindowMovementDiagnostics,
        animationStepsSetting: Int,
        animationDurationSetting: TimeInterval,
        rawStatus: RawMultitouchBackendStatus,
        rawDiagnostics: RawGestureDiagnosticSnapshot,
        counters rawCounters: RawDiagnosticsCounters,
        events: [String]
    ) -> String {
        let counters = snapshot.counters
        let timestamp = snapshot.lastTimestamp.map { String(format: "%.3f", $0) } ?? "none"
        let delta = Self.renderPair(snapshot.lastDeltaX, snapshot.lastDeltaY)
        let scrollDelta = Self.renderPair(snapshot.lastScrollDeltaX, snapshot.lastScrollDeltaY)
        let scrollScrollingDelta = Self.renderPair(
            snapshot.lastScrollScrollingDeltaX,
            snapshot.lastScrollScrollingDeltaY
        )
        let accumulatedScrollDelta = Self.renderPair(
            snapshot.accumulatedScrollDeltaX,
            snapshot.accumulatedScrollDeltaY
        )

        return """
        Toucher Gesture Diagnostics

        Accessibility:
        Accessibility trusted: \(renderBool(accessibilityTrusted))
        Accessibility last checked at: \(accessibilityLastChecked)
        Accessibility transition count: \(accessibilityTransitionCount)
        Last accessibility transition: \(lastAccessibilityTransition)
        Waiting for accessibility: \(renderBool(waitingForAccessibility))
        Last AX action attempted: \(lastAXActionAttempted)
        Last AX action result: \(lastAXActionResult)
        Last AX error: \(lastAXError)

        Raw multitouch:
        Raw multitouch available: \(renderBool(rawStatus.isAvailable))
        Raw multitouch active: \(renderBool(rawStatus.isActive))
        Raw devices found: \(rawStatus.devicesFound)
        Active touches: \(rawStatus.activeTouches)
        Last raw error: \(rawStatus.lastError ?? "none")

        Movement:
        Last movement mode: \(movementDiagnostics.lastMovementMode)
        Last movement kind: \(movementDiagnostics.lastMovementKind)
        Animation steps setting: \(animationStepsSetting)
        Animation duration setting: \(String(format: "%.2fs", animationDurationSetting))
        Last movement steps planned: \(movementDiagnostics.lastMovementStepsPlanned)
        Last movement steps applied: \(movementDiagnostics.lastMovementStepsApplied)
        Last movement steps skipped: \(movementDiagnostics.lastMovementStepsSkipped)
        Last movement requested duration: \(renderTime(movementDiagnostics.lastMovementRequestedDuration))
        Last movement actual elapsed duration: \(renderTime(movementDiagnostics.lastMovementActualElapsedDuration))
        Last movement start frame: \(renderRect(movementDiagnostics.lastStartFrame))
        Last movement target frame: \(renderRect(movementDiagnostics.lastTargetFrame))
        Last movement final readback frame: \(renderRect(movementDiagnostics.lastFinalReadbackFrame))
        Last movement error: \(movementDiagnostics.lastMovementError ?? "none")
        Last movement fallback used: \(renderBool(movementDiagnostics.lastMovementFallbackUsed))

        Screen Geometry Debug Info:
        \(screenGeometryDebugInfo)

        Raw counters:
        Total raw callbacks count: \(rawCounters.callbacks)
        Total recognized gestures count: \(rawCounters.recognized)
        Left gestures count: \(rawCounters.left)
        Right gestures count: \(rawCounters.right)
        Up gestures count: \(rawCounters.up)
        Ignored gestures count: \(rawCounters.ignored)
        Unsupported finger count count: \(rawCounters.unsupportedFingerCount)
        Canceled gestures count: \(rawCounters.canceled)

        Raw last accepted:
        Last accepted gesture: \(rawCounters.lastAcceptedGesture)
        Last accepted dx/dy: \(rawCounters.lastAcceptedDelta)
        Last accepted duration: \(rawCounters.lastAcceptedDuration)
        Last ignored reason: \(rawCounters.lastIgnoredReason)
        Active touches: \(rawStatus.activeTouches)

        Gesture timing:
        minHorizontalDistance: \(String(format: "%.3f", rawDiagnostics.minHorizontalDistance))
        minVerticalDistance: \(String(format: "%.3f", rawDiagnostics.minVerticalDistance))
        dominanceRatio: \(String(format: "%.3f", rawDiagnostics.dominanceRatio))
        maxGestureDuration: \(String(format: "%.3f", rawDiagnostics.maxGestureDuration))
        cooldown: \(String(format: "%.3f", rawDiagnostics.cooldown))
        last gesture duration: \(renderTime(rawDiagnostics.lastGestureDuration))
        last gesture start timestamp: \(renderTime(rawDiagnostics.lastGestureStartTimestamp))
        last gesture end/trigger timestamp: \(renderTime(rawDiagnostics.lastGestureEndTimestamp))
        last gesture accepted: \(renderBool(rawDiagnostics.lastGestureAccepted))
        rejection reason: \(rawDiagnostics.lastRejectionReason?.rawValue ?? "none")

        Last 10 raw events:
        \(events.isEmpty ? "none" : events.joined(separator: "\n"))

        Public NSEvent diagnostics:
        Last public event type: \(snapshot.lastEventType?.rawValue ?? "none")
        Last public event timestamp: \(timestamp)
        Last public event dx/dy: \(delta)
        Last public event phase: \(snapshot.lastPhase ?? "none")
        Last public event momentumPhase: \(snapshot.lastMomentumPhase ?? "none")

        Last scroll deltaX/deltaY: \(scrollDelta)
        Last scroll scrollingDeltaX/scrollingDeltaY: \(scrollScrollingDelta)
        Accumulated scroll dx/dy: \(accumulatedScrollDelta)
        Last scroll precise: \(Self.renderBool(snapshot.lastScrollHasPreciseScrollingDeltas))
        Last scroll direction inverted: \(Self.renderBool(snapshot.lastScrollIsDirectionInvertedFromDevice))

        Event counters:
        swipe count: \(counters.swipe)
        scrollWheel count: \(counters.scrollWheel)
        beginGesture count: \(counters.beginGesture)
        endGesture count: \(counters.endGesture)
        magnify count: \(counters.magnify)
        rotate count: \(counters.rotate)
        smartMagnify count: \(counters.smartMagnify)
        """
    }

    private static func renderTime(_ value: TimeInterval?) -> String {
        guard let value else {
            return "none"
        }

        return String(format: "%.3f", value)
    }

    private static func renderPair(_ deltaX: Double?, _ deltaY: Double?) -> String {
        guard let deltaX,
              let deltaY else {
            return "none"
        }

        return String(format: "dx=%.3f, dy=%.3f", deltaX, deltaY)
    }

    private static func renderRect(_ rect: Rect?) -> String {
        guard let rect else {
            return "none"
        }

        return String(
            format: "x=%.1f y=%.1f w=%.1f h=%.1f",
            rect.x,
            rect.y,
            rect.width,
            rect.height
        )
    }

    private static func renderBool(_ value: Bool?) -> String {
        guard let value else {
            return "unknown"
        }

        return value ? "yes" : "no"
    }
}

private extension WindowAction {
    var debugName: String {
        switch self {
        case .leftHalf:
            return "leftHalf"
        case .rightHalf:
            return "rightHalf"
        case .maximize:
            return "maximize"
        case .verticalMaxCenterThird:
            return "verticalMaxCenterThird"
        case .restore:
            return "restore"
        }
    }
}

private extension WindowMovementError {
    var debugName: String {
        switch self {
        case .accessibilityPermissionMissing:
            return "accessibilityPermissionMissing"
        case .noFocusedApplication:
            return "noFocusedApplication"
        case .noFocusedWindow:
            return "noFocusedWindow"
        case .unsupportedWindow:
            return "unsupportedWindow"
        case .failedToReadWindowFrame:
            return "failedToReadWindowFrame"
        case .failedToSetWindowFrame:
            return "failedToSetWindowFrame"
        case .noStoredFrame:
            return "noStoredFrame"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
