import AppKit
import WindowGesturesCore
import WindowGesturesMac

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionChecker = AccessibilityPermissionChecker()
    private let hotKeyRegistrar = CarbonHotKeyRegistrar()
    private let windowController = AccessibilityWindowController()
    private var commandHandler: WindowCommandHandler<AccessibilityPermissionChecker, AccessibilityWindowController>?
    private var hotKeyCoordinator: HotKeyCoordinator<CarbonHotKeyRegistrar>?
    private var statusItem: NSStatusItem?
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")

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
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
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
        case .permissionDenied:
            setStatus("Accessibility permission needed")
        case .noActiveWindow:
            setStatus("No active window found")
        case .visibleScreenUnavailable:
            setStatus("Could not find visible screen")
        case .moveFailed:
            setStatus("Could not move active window")
        }
    }

    func setStatus(_ value: String) {
        statusMenuItem.title = "Status: \(value)"
        statusItem?.button?.toolTip = "WindowGestures - \(value)"
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
