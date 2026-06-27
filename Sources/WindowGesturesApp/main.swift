import AppKit
import WindowGesturesCore
import WindowGesturesMac

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let permissionChecker = AccessibilityPermissionChecker()
    private let hotKeyRegistrar = CarbonHotKeyRegistrar()
    private let windowController = AccessibilityWindowController()
    private var commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>?
    private var hotKeyCoordinator: HotKeyCoordinator<CarbonHotKeyRegistrar>?
    private var statusItem: NSStatusItem?
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let accessibilityTrustedMenuItem = NSMenuItem(title: "Accessibility trusted: unknown", action: nil, keyEquivalent: "")
    private let appBundleIDMenuItem = NSMenuItem(title: "App bundle id: unknown", action: nil, keyEquivalent: "")
    private let appBundlePathMenuItem = NSMenuItem(title: "App bundle path: unknown", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBarItem()

        let commandHandler = WindowCommandHandler(
            permissions: permissionChecker,
            windows: windowController
        )
        self.commandHandler = commandHandler

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
        menu.addItem(statusMenuItem)
        menu.addItem(accessibilityTrustedMenuItem)
        menu.addItem(appBundleIDMenuItem)
        menu.addItem(appBundlePathMenuItem)
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

        accessibilityTrustedMenuItem.title = "Accessibility trusted: \(trusted)"
        appBundleIDMenuItem.title = "App bundle id: \(bundleID)"
        appBundlePathMenuItem.title = "App bundle path: \(bundlePath)"
    }

    @objc func openAccessibilitySettings() {
        permissionChecker.openAccessibilitySettings()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
