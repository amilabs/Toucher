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
        static let rawMinDistance = "rawMinDistance"
        static let rawDominanceRatio = "rawDominanceRatio"
        static let rawCooldown = "rawCooldown"
    }

    private let defaults: UserDefaults
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enableGestures: true,
            Key.gestureBackend: ToucherBackendPreference.raw.rawValue,
            Key.enableDiagnostics: false,
            Key.invertGestureDirection: false,
            Key.animationEnabled: false,
            Key.animationDuration: 0.25,
            Key.rawMinDistance: 0.08,
            Key.rawDominanceRatio: 2.0,
            Key.rawCooldown: 0.35
        ])
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

    var animationEnabled: Bool {
        get { defaults.bool(forKey: Key.animationEnabled) }
        set { set(newValue, forKey: Key.animationEnabled) }
    }

    var animationDuration: TimeInterval {
        get { min(0.5, max(0, defaults.double(forKey: Key.animationDuration))) }
        set { set(min(0.5, max(0, newValue)), forKey: Key.animationDuration) }
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
            animationEnabled: animationEnabled,
            animationDuration: animationDuration,
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
    private let permissionChecker = AccessibilityPermissionChecker()
    private let hotKeyRegistrar = CarbonHotKeyRegistrar()
    private lazy var windowController = AnimatedAccessibilityWindowController()
    private let gestureRecognizer = HorizontalSwipeRecognizer(invertDirection: false)
    private var rawGestureRecognizer = RawThreeFingerSwipeRecognizer()
    private let gestureDiagnostics = GestureDiagnosticState()
    private var commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AnimatedAccessibilityWindowController>?
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
    private var rawCallbacksCount = 0
    private var rawRecognizedGesturesCount = 0
    private var rawLeftGesturesCount = 0
    private var rawRightGesturesCount = 0
    private var rawIgnoredGesturesCount = 0
    private var rawUnsupportedFingerCountCount = 0
    private var rawCanceledGesturesCount = 0
    private var rawEventRingBuffer: [String] = []
    private var lastRawGestureStartX: Double?
    private var lastRawGestureStartY: Double?
    private var settingsWindowController: SettingsWindowController?
    private var pendingSettingsApply = false
    private var appliedSettingsSnapshot = ToucherSettingsSnapshot()
    private var statusItem: NSStatusItem?
    private let versionMenuItem = NSMenuItem(title: "Toucher version: 0.5.2", action: nil, keyEquivalent: "")
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
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
    private var lastGestureEventDescription = "none"
    private var lastGestureActionDescription = "none"
    private var lastGestureIgnoredReasonDescription = GestureIgnoredReason.noEventReceived.rawValue

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBarItem()
        settings.onChange = { [weak self] in
            self?.applySettingsChange()
        }
        appliedSettingsSnapshot = settings.snapshot
        rebuildRawRecognizer()

        let commandHandler = WindowCommandHandler(
            permissions: permissionChecker,
            windows: windowController
        )
        self.commandHandler = commandHandler
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

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyCoordinator?.stop()
        stopGestureBackends()
        windowController.cancelAnimations()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshDebugInfo()
    }
}

private extension AppDelegate {
    static func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let stroke = NSColor.labelColor
        stroke.setStroke()

        let trackpad = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 3, width: 13, height: 11), xRadius: 3, yRadius: 3)
        trackpad.lineWidth = 1.4
        trackpad.stroke()

        for x in [6.0, 9.0, 12.0] {
            let dot = NSBezierPath(ovalIn: NSRect(x: x - 0.8, y: 10, width: 1.6, height: 1.6))
            stroke.setFill()
            dot.fill()
        }

        let line = NSBezierPath()
        line.move(to: NSPoint(x: 5.2, y: 6.2))
        line.line(to: NSPoint(x: 12.8, y: 6.2))
        line.lineWidth = 1.2
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
        versionMenuItem.isEnabled = false
        statusMenuItem.isEnabled = false
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
        menu.addItem(versionMenuItem)
        menu.addItem(statusMenuItem)
        menu.addItem(accessibilityTrustedMenuItem)
        menu.addItem(appBundleIDMenuItem)
        menu.addItem(appBundlePathMenuItem)
        menu.addItem(gesturesEnabledMenuItem)
        menu.addItem(gestureBackendMenuItem)
        menu.addItem(gestureMonitorMenuItem)
        menu.addItem(rawMultitouchAvailableMenuItem)
        menu.addItem(rawMultitouchActiveMenuItem)
        menu.addItem(rawDevicesFoundMenuItem)
        menu.addItem(rawActiveTouchesMenuItem)
        menu.addItem(lastRawGestureMenuItem)
        menu.addItem(lastRawCentroidDeltaMenuItem)
        menu.addItem(lastRawGestureActionMenuItem)
        menu.addItem(lastRawGestureIgnoredReasonMenuItem)
        menu.addItem(lastRawErrorMenuItem)
        menu.addItem(gestureProbeMenuItem)
        menu.addItem(lastPublicEventTypeMenuItem)
        menu.addItem(lastPublicEventTimestampMenuItem)
        menu.addItem(lastPublicEventDeltaMenuItem)
        menu.addItem(lastScrollDeltaMenuItem)
        menu.addItem(lastScrollScrollingDeltaMenuItem)
        menu.addItem(accumulatedScrollDeltaMenuItem)
        menu.addItem(lastScrollPreciseMenuItem)
        menu.addItem(lastScrollDirectionInvertedMenuItem)
        menu.addItem(lastPublicEventPhaseMenuItem)
        menu.addItem(lastPublicEventMomentumPhaseMenuItem)
        menu.addItem(eventCountersMenuItem)
        menu.addItem(lastGestureEventMenuItem)
        menu.addItem(lastGestureActionMenuItem)
        menu.addItem(lastGestureIgnoredReasonMenuItem)
        menu.addItem(NSMenuItem.separator())
        let gestureProbeItem = NSMenuItem(
            title: "Open Settings",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        gestureProbeItem.target = self
        menu.addItem(gestureProbeItem)

        let gestureDiagnosticsItem = NSMenuItem(
            title: "Open Gesture Diagnostics",
            action: #selector(openGestureProbeWindow),
            keyEquivalent: ""
        )
        gestureDiagnosticsItem.target = self
        menu.addItem(gestureDiagnosticsItem)

        menu.addItem(NSMenuItem.separator())
        let accessibilitySettingsItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilitySettingsItem.target = self
        menu.addItem(accessibilitySettingsItem)

        menu.addItem(NSMenuItem.separator())
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
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AnimatedAccessibilityWindowController>
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
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AnimatedAccessibilityWindowController>,
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
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AnimatedAccessibilityWindowController>
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
                        self.gestureProbeWindowController?.scheduleUpdate(
                            rawStatus: status,
                            rawDiagnostics: self.rawGestureRecognizer.diagnostics,
                            counters: self.rawDiagnosticsCounters(),
                            events: self.rawEventRingBuffer
                        )
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
        if permissionChecker.hasAccessibilityPermission {
            setStatus("Ready")
        } else {
            setStatus("Accessibility permission needed")
        }
    }

    func show(_ result: WindowCommandResult) {
        switch result {
        case .moved:
            setStatus("Moved active window")
        case .failed(.accessibilityPermissionMissing):
            setStatus("Accessibility permission needed")
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
        statusMenuItem.title = "Status: \(value)"
        statusItem?.button?.toolTip = "Toucher - \(value)"
    }

    func refreshDebugInfo() {
        let trusted = permissionChecker.hasAccessibilityPermission ? "yes" : "no"
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let bundlePath = Bundle.main.bundleURL.path
        let gestureMonitor = gestureBackend?.isActive == true ? "active" : "inactive"
        let gestureProbe = gestureProbeWindowController?.isWindowOpen == true ? "active" : "inactive"
        let diagnostics = gestureDiagnostics.snapshot

        accessibilityTrustedMenuItem.title = "Accessibility trusted: \(trusted)"
        appBundleIDMenuItem.title = "App bundle id: \(bundleID)"
        appBundlePathMenuItem.title = "App bundle path: \(bundlePath)"
        gesturesEnabledMenuItem.title = "Gestures enabled: \(settings.enableGestures ? "yes" : "no")"
        gestureBackendMenuItem.title = "Gesture backend: \(gestureBackendDescription)"
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
    }

    func handlePublicGestureEvent(
        _ input: PublicGestureEventInput,
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AnimatedAccessibilityWindowController>
    ) {
        gestureDiagnostics.record(input)

        guard let recognition = gestureRecognizer.recognize(publicEvent: input) else {
            lastGestureActionDescription = "none"
            refreshDebugInfo()
            gestureProbeWindowController?.update(
                publicSnapshot: gestureDiagnostics.snapshot,
                rawStatus: rawMultitouchStatus,
                rawDiagnostics: rawGestureRecognizer.diagnostics,
                counters: rawDiagnosticsCounters(),
                events: rawEventRingBuffer
            )
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

        gestureProbeWindowController?.update(
            publicSnapshot: gestureDiagnostics.snapshot,
            rawStatus: rawMultitouchStatus,
            rawDiagnostics: rawGestureRecognizer.diagnostics,
            counters: rawDiagnosticsCounters(),
            events: rawEventRingBuffer
        )
    }

    func handleRawTouchSample(
        _ sample: RawTouchSample,
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AnimatedAccessibilityWindowController>
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
            lastRawGestureIgnoredReasonDescription = "none"
            rawRecognizedGesturesCount += 1
            if action == .leftHalf {
                rawLeftGesturesCount += 1
            } else if action == .rightHalf {
                rawRightGesturesCount += 1
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
            appendRawEvent(sample: sample, result: reason.rawValue)
            lastRawGestureIgnoredReasonDescription = reason.rawValue
            refreshDebugInfo()
        }

        gestureProbeWindowController?.scheduleUpdate(
            rawStatus: rawMultitouchStatus,
            rawDiagnostics: rawGestureRecognizer.diagnostics,
            counters: rawDiagnosticsCounters(),
            events: rawEventRingBuffer
        )
    }

    func currentModifierScreenTarget() -> WindowScreenTarget {
        NSEvent.modifierFlags.contains(.command) ? .next : .current
    }

    func appendRawEvent(sample: RawTouchSample, result: String) {
        let event = String(
            format: "%.3f fingers=%d dxdy=%@ result=%@",
            sample.timestamp,
            sample.activeTouchCount,
            lastRawCentroidDeltaDescription,
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
            ignored: rawIgnoredGesturesCount,
            unsupportedFingerCount: rawUnsupportedFingerCountCount,
            canceled: rawCanceledGesturesCount
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
            return .failed(.failedToSetWindowFrame)
        }

        let result = commandHandler.perform(
            action,
            options: WindowCommandOptions(
                screenTarget: screenTarget,
                animated: settings.animationEnabled,
                animationDuration: settings.animationDuration
            )
        )
        show(result)
        return result
    }

    func rebuildRawRecognizer() {
        rawGestureRecognizer = RawThreeFingerSwipeRecognizer(
            minHorizontalDistance: settings.rawMinDistance,
            dominanceRatio: settings.rawDominanceRatio,
            maxGestureDuration: 0.8,
            cooldown: settings.rawCooldown,
            invertDirection: settings.invertGestureDirection
        )
    }

    @objc func openSettings() {
        let controller = settingsWindowController ?? SettingsWindowController(settings: settings)
        settingsWindowController = controller
        controller.show()
    }

    @objc func openGestureProbeWindow() {
        let controller = gestureProbeWindowController ?? GestureProbeWindowController()
        gestureProbeWindowController = controller
        controller.onClose = { [weak self] in
            self?.handleGestureProbeWindowClosed()
        }
        if settings.gestureBackend != .public,
           publicGestureBackend == nil,
           let commandHandler {
            startPublicGestureBackend(commandHandler: commandHandler, primary: false)
        }
        controller.show(
            publicSnapshot: gestureDiagnostics.snapshot,
            rawStatus: rawMultitouchStatus,
            rawDiagnostics: rawGestureRecognizer.diagnostics,
            counters: rawDiagnosticsCounters(),
            events: rawEventRingBuffer
        )
        refreshDebugInfo()
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
    var ignored: Int
    var unsupportedFingerCount: Int
    var canceled: Int
}

private final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: ToucherSettings
    private var window: NSWindow?
    private var sleeves: [ClosureSleeve] = []

    init(settings: ToucherSettings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Toucher Settings"
            window.delegate = self
            window.center()
            window.contentView = makeContentView()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        stack.addArrangedSubview(checkbox("Enable gestures", value: settings.enableGestures) { [settings] in
            settings.enableGestures = $0
        })
        stack.addArrangedSubview(popup("Gesture backend", items: ToucherBackendPreference.allCases.map(\.rawValue), selected: settings.gestureBackend.rawValue) { [settings] value in
            settings.gestureBackend = ToucherBackendPreference(rawValue: value) ?? .raw
        })
        stack.addArrangedSubview(checkbox("Enable diagnostics/probe", value: settings.enableDiagnostics) { [settings] in
            settings.enableDiagnostics = $0
        })
        stack.addArrangedSubview(checkbox("Invert gesture direction", value: settings.invertGestureDirection) { [settings] in
            settings.invertGestureDirection = $0
        })
        stack.addArrangedSubview(checkbox("Animation enabled (experimental)", value: settings.animationEnabled) { [settings] in
            settings.animationEnabled = $0
        })
        stack.addArrangedSubview(numberField("Animation duration", value: settings.animationDuration) { [settings] in
            settings.animationDuration = $0
        })
        stack.addArrangedSubview(numberField("Raw gesture minimum distance", value: settings.rawMinDistance) { [settings] in
            settings.rawMinDistance = $0
        })
        stack.addArrangedSubview(numberField("Raw gesture dominance ratio", value: settings.rawDominanceRatio) { [settings] in
            settings.rawDominanceRatio = $0
        })
        stack.addArrangedSubview(numberField("Raw gesture cooldown", value: settings.rawCooldown) { [settings] in
            settings.rawCooldown = $0
        })

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 360))
        stack.frame = view.bounds
        stack.autoresizingMask = [.width, .height]
        view.addSubview(stack)
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

    private func row(_ label: NSView, _ control: NSView) -> NSView {
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        label.widthAnchor.constraint(equalToConstant: 190).isActive = true
        control.widthAnchor.constraint(equalToConstant: 130).isActive = true
        return stack
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
            rawStatus: rawStatus,
            rawDiagnostics: rawDiagnostics,
            counters: counters,
            events: events
        )
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func scheduleUpdate(
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
        rawStatus: RawMultitouchBackendStatus,
        rawDiagnostics: RawGestureDiagnosticSnapshot,
        counters: RawDiagnosticsCounters,
        events: [String]
    ) {
        textView.string = Self.render(
            publicSnapshot: publicSnapshot,
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
        onClose?()
    }

    private static func render(
        publicSnapshot snapshot: GestureDiagnosticSnapshot,
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

        Raw multitouch:
        Raw multitouch available: \(renderBool(rawStatus.isAvailable))
        Raw multitouch active: \(renderBool(rawStatus.isActive))
        Raw devices found: \(rawStatus.devicesFound)
        Active touches: \(rawStatus.activeTouches)
        Last raw error: \(rawStatus.lastError ?? "none")

        Raw counters:
        Total raw callbacks count: \(rawCounters.callbacks)
        Total recognized gestures count: \(rawCounters.recognized)
        Left gestures count: \(rawCounters.left)
        Right gestures count: \(rawCounters.right)
        Ignored gestures count: \(rawCounters.ignored)
        Unsupported finger count count: \(rawCounters.unsupportedFingerCount)
        Canceled gestures count: \(rawCounters.canceled)

        Gesture timing:
        minHorizontalDistance: \(String(format: "%.3f", rawDiagnostics.minHorizontalDistance))
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
