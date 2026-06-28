import AppKit
import WindowGesturesCore
import WindowGesturesMac

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let permissionChecker = AccessibilityPermissionChecker()
    private let hotKeyRegistrar = CarbonHotKeyRegistrar()
    private let windowController = AccessibilityWindowController()
    private let gestureRecognizer = HorizontalSwipeRecognizer(invertDirection: false)
    private let rawGestureRecognizer = RawThreeFingerSwipeRecognizer(invertDirection: false)
    private let gestureDiagnostics = GestureDiagnosticState()
    private var commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>?
    private var hotKeyCoordinator: HotKeyCoordinator<CarbonHotKeyRegistrar>?
    private var gestureBackend: GestureMonitoring?
    private var publicGestureBackend: PublicNSEventSwipeBackend?
    private var rawGestureBackend: RawMultitouchBackend?
    private var gestureProbeWindowController: GestureProbeWindowController?
    private var gestureBackendDescription = "off"
    private var rawMultitouchStatus = RawMultitouchBackendStatus()
    private var lastRawCentroidDeltaDescription = "none"
    private var lastRawGestureActionDescription = "none"
    private var lastRawGestureIgnoredReasonDescription = "none"
    private var lastRawGestureStartX: Double?
    private var lastRawGestureStartY: Double?
    private var statusItem: NSStatusItem?
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let accessibilityTrustedMenuItem = NSMenuItem(title: "Accessibility trusted: unknown", action: nil, keyEquivalent: "")
    private let appBundleIDMenuItem = NSMenuItem(title: "App bundle id: unknown", action: nil, keyEquivalent: "")
    private let appBundlePathMenuItem = NSMenuItem(title: "App bundle path: unknown", action: nil, keyEquivalent: "")
    private let gesturesEnabledMenuItem = NSMenuItem(title: "Gestures enabled: unknown", action: nil, keyEquivalent: "")
    private let gestureBackendMenuItem = NSMenuItem(title: "Gesture backend: public NSEvent swipe", action: nil, keyEquivalent: "")
    private let gestureMonitorMenuItem = NSMenuItem(title: "Gesture monitor: inactive", action: nil, keyEquivalent: "")
    private let rawMultitouchAvailableMenuItem = NSMenuItem(title: "Raw multitouch available: unknown", action: nil, keyEquivalent: "")
    private let rawMultitouchActiveMenuItem = NSMenuItem(title: "Raw multitouch active: unknown", action: nil, keyEquivalent: "")
    private let rawDevicesFoundMenuItem = NSMenuItem(title: "Raw devices found: 0", action: nil, keyEquivalent: "")
    private let rawActiveTouchesMenuItem = NSMenuItem(title: "Active touches: 0", action: nil, keyEquivalent: "")
    private let lastRawCentroidDeltaMenuItem = NSMenuItem(title: "Last raw centroid dx/dy: none", action: nil, keyEquivalent: "")
    private let lastRawGestureActionMenuItem = NSMenuItem(title: "Last raw gesture action: none", action: nil, keyEquivalent: "")
    private let lastRawGestureIgnoredReasonMenuItem = NSMenuItem(title: "Last raw ignored reason: none", action: nil, keyEquivalent: "")
    private let lastRawErrorMenuItem = NSMenuItem(title: "Last raw error: none", action: nil, keyEquivalent: "")
    private let gestureProbeMenuItem = NSMenuItem(title: "Gesture probe: inactive", action: nil, keyEquivalent: "")
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

        let commandHandler = WindowCommandHandler(
            permissions: permissionChecker,
            windows: windowController
        )
        self.commandHandler = commandHandler
        configureGestureBackend(commandHandler: commandHandler)

        hotKeyCoordinator = HotKeyCoordinator(registrar: hotKeyRegistrar) { [weak self, commandHandler] action in
            let result = commandHandler.perform(action)
            DispatchQueue.main.async {
                self?.show(result)
            }
            return result
        }

        do {
            try hotKeyCoordinator?.start()
            showInitialStatus()
        } catch {
            setStatus("Hotkeys unavailable")
            NSLog("WindowGestures failed to register hotkeys: \(String(describing: error))")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyCoordinator?.stop()
        rawGestureBackend?.stop()
        publicGestureBackend?.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshDebugInfo()
    }
}

private extension AppDelegate {
    func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.split.2x1",
                accessibilityDescription: "WindowGestures"
            )
            button.title = " WindowGestures"
        }

        let menu = NSMenu()
        menu.delegate = self
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
            title: "Open Gesture Probe Window",
            action: #selector(openGestureProbeWindow),
            keyEquivalent: ""
        )
        gestureProbeItem.target = self
        menu.addItem(gestureProbeItem)

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
            title: "Quit WindowGestures",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    func configureGestureBackend(
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>
    ) {
        switch selectedGestureBackendPreference() {
        case "off":
            gestureBackendDescription = "off"
            refreshDebugInfo()
        case "public":
            startPublicGestureBackend(commandHandler: commandHandler)
        case "raw":
            _ = startRawGestureBackend(commandHandler: commandHandler)
        default:
            if !startRawGestureBackend(commandHandler: commandHandler) {
                startPublicGestureBackend(commandHandler: commandHandler)
            }
        }
    }

    func selectedGestureBackendPreference() -> String {
        ProcessInfo.processInfo.environment["WINDOWGESTURES_GESTURE_BACKEND"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "auto"
    }

    func startPublicGestureBackend(
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>
    ) {
        let backend = PublicNSEventSwipeBackend { [weak self, commandHandler] input in
            DispatchQueue.main.async {
                self?.handlePublicGestureEvent(input, commandHandler: commandHandler)
            }
        }
        publicGestureBackend = backend
        gestureBackend = backend
        gestureBackendDescription = "public NSEvent"
        backend.start()
        refreshDebugInfo()
    }

    func startRawGestureBackend(
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>
    ) -> Bool {
        let backend = RawMultitouchBackend(
            handleSample: { [weak self, commandHandler] sample in
                self?.handleRawTouchSample(sample, commandHandler: commandHandler)
            },
            handleStatus: { [weak self] status in
                self?.rawMultitouchStatus = status
                self?.refreshDebugInfo()
            }
        )
        rawGestureBackend = backend
        gestureBackend = backend
        gestureBackendDescription = "raw multitouch"
        backend.start()
        rawMultitouchStatus = backend.status
        refreshDebugInfo()
        return backend.isActive
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
        statusItem?.button?.toolTip = "WindowGestures - \(value)"
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
        gesturesEnabledMenuItem.title = "Gestures enabled: yes"
        gestureBackendMenuItem.title = "Gesture backend: \(gestureBackendDescription)"
        gestureMonitorMenuItem.title = "Gesture monitor: \(gestureMonitor)"
        rawMultitouchAvailableMenuItem.title = "Raw multitouch available: \(rawMultitouchStatus.isAvailable ? "yes" : "no")"
        rawMultitouchActiveMenuItem.title = "Raw multitouch active: \(rawMultitouchStatus.isActive ? "yes" : "no")"
        rawDevicesFoundMenuItem.title = "Raw devices found: \(rawMultitouchStatus.devicesFound)"
        rawActiveTouchesMenuItem.title = "Active touches: \(rawMultitouchStatus.activeTouches)"
        lastRawCentroidDeltaMenuItem.title = "Last raw centroid dx/dy: \(lastRawCentroidDeltaDescription)"
        lastRawGestureActionMenuItem.title = "Last raw gesture action: \(lastRawGestureActionDescription)"
        lastRawGestureIgnoredReasonMenuItem.title = "Last raw ignored reason: \(lastRawGestureIgnoredReasonDescription)"
        lastRawErrorMenuItem.title = "Last raw error: \(rawMultitouchStatus.lastError ?? "none")"
        gestureProbeMenuItem.title = "Gesture probe: \(gestureProbe)"
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
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>
    ) {
        gestureDiagnostics.record(input)

        guard let recognition = gestureRecognizer.recognize(publicEvent: input) else {
            lastGestureActionDescription = "none"
            refreshDebugInfo()
            gestureProbeWindowController?.update(snapshot: gestureDiagnostics.snapshot)
            return
        }

        lastGestureEventDescription = formatDelta(gestureDiagnostics.snapshot)

        switch recognition {
        case .action(let action):
            lastGestureActionDescription = action.debugName
            lastGestureIgnoredReasonDescription = "none"
            show(commandHandler.perform(action))
        case .ignored(let reason):
            lastGestureActionDescription = "ignored"
            lastGestureIgnoredReasonDescription = reason.rawValue
            refreshDebugInfo()
        }

        gestureProbeWindowController?.update(snapshot: gestureDiagnostics.snapshot)
    }

    func handleRawTouchSample(
        _ sample: RawTouchSample,
        commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>
    ) {
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
            lastRawGestureIgnoredReasonDescription = "none"
            show(commandHandler.perform(action))
        case .ignored(let reason):
            if reason == .fingerCountChanged || reason == .unsupportedFingerCount {
                lastRawGestureStartX = nil
                lastRawGestureStartY = nil
            }
            lastRawGestureIgnoredReasonDescription = reason.rawValue
            refreshDebugInfo()
        }
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

    @objc func openGestureProbeWindow() {
        let controller = gestureProbeWindowController ?? GestureProbeWindowController()
        gestureProbeWindowController = controller
        controller.show(snapshot: gestureDiagnostics.snapshot)
        refreshDebugInfo()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

private final class GestureProbeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let textView = NSTextView()

    var isWindowOpen: Bool {
        window?.isVisible == true
    }

    func show(snapshot: GestureDiagnosticSnapshot) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "WindowGestures Gesture Probe"
            window.delegate = self
            window.center()

            textView.isEditable = false
            textView.isSelectable = true
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.autoresizingMask = [.width, .height]
            textView.frame = NSRect(x: 0, y: 0, width: 560, height: 420)
            window.contentView = textView
            self.window = window
        }

        update(snapshot: snapshot)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func update(snapshot: GestureDiagnosticSnapshot) {
        textView.string = Self.render(snapshot)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private static func render(_ snapshot: GestureDiagnosticSnapshot) -> String {
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
        Gesture probe: active
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
