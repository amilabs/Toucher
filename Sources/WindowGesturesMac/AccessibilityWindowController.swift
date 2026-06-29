import AppKit
import ApplicationServices
import WindowGesturesCore

public final class AccessibilityWindowController: WindowControlling {
    public typealias Window = AXUIElement

    public init() {}

    public func focusedWindow() throws -> AXUIElement {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw WindowMovementError.noFocusedApplication
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        if result == .apiDisabled {
            throw WindowMovementError.accessibilityPermissionMissing
        }

        guard result == .success, let window = value else {
            throw WindowMovementError.noFocusedWindow
        }

        guard CFGetTypeID(window) == AXUIElementGetTypeID() else {
            throw WindowMovementError.noFocusedWindow
        }

        return (window as! AXUIElement)
    }

    public func visibleScreenFrame(for window: AXUIElement) throws -> Rect {
        let windowFrame = try frame(of: window)
        let screenFrames = try screens()

        guard let visibleFrame = ScreenSelector.targetVisibleFrame(
            for: windowFrame,
            screens: screenFrames,
            target: .current
        ) else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        return visibleFrame
    }

    public func screens() throws -> [ScreenFrame] {
        try appKitScreens()
    }

    public func frame(for window: AXUIElement) throws -> Rect {
        try frame(of: window)
    }

    public func move(_ window: AXUIElement, to frame: Rect) throws {
        let axFrame = try accessibilityFrame(fromAppKitFrame: frame)
        try moveAccessibilityFrame(window, to: axFrame)
    }

    public func restoreIdentifier(for window: AXUIElement) -> String? {
        String(CFHash(window))
    }

    public func screenGeometryDebugInfo(actionTargetFrame: Rect? = nil) -> String {
        let screens = (try? appKitScreens()) ?? []
        let desktopUnion = ScreenGeometry.desktopUnion(for: screens)
        let converter = desktopUnion.map(AccessibilityCoordinateConverter.init(desktopUnion:))
        let focused = try? focusedWindow()
        let axFrame = focused.flatMap { try? rawAccessibilityFrame(of: $0) }
        let appKitFrame = axFrame.flatMap { converter?.appKitRect(fromAccessibilityRect: $0) }
        let selectedScreen = appKitFrame.flatMap { ScreenSelector.currentScreen(for: $0, screens: screens) }
        let axTarget = actionTargetFrame.flatMap { converter?.accessibilityRect(fromAppKitRect: $0) }
        let processInfo = ProcessInfo.processInfo
        let os = processInfo.operatingSystemVersion

        func render(_ rect: Rect?) -> String {
            guard let rect else {
                return "none"
            }

            return String(format: "x=%.1f y=%.1f w=%.1f h=%.1f", rect.x, rect.y, rect.width, rect.height)
        }

        let screenLines = screens.enumerated().map { index, screen in
            "screen[\(index)] frame=\(render(screen.frame)) visibleFrame=\(render(screen.visibleFrame))"
        }.joined(separator: "\n")

        return """
        macOS version: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)
        screens:
        \(screenLines.isEmpty ? "none" : screenLines)
        desktopUnion: \(render(desktopUnion))
        active window AX frame: \(render(axFrame))
        active window AppKit frame: \(render(appKitFrame))
        selected screen frame: \(render(selectedScreen?.frame))
        selected screen visibleFrame: \(render(selectedScreen?.visibleFrame))
        computed AppKit target frame: \(render(actionTargetFrame))
        computed AX target frame: \(render(axTarget))
        """
    }
}

private extension AccessibilityWindowController {
    func appKitScreens() throws -> [ScreenFrame] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        return screens.map { screen in
            ScreenFrame(
                frame: appKitFrame(screen.frame),
                visibleFrame: appKitFrame(screen.visibleFrame)
            )
        }
    }

    func moveAccessibilityFrame(_ window: AXUIElement, to frame: Rect) throws {
        var position = CGPoint(x: frame.x, y: frame.y)
        var size = CGSize(width: frame.width, height: frame.height)

        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowMovementError.failedToSetWindowFrame
        }

        var positionSettable = DarwinBoolean(false)
        let positionSettableResult = AXUIElementIsAttributeSettable(
            window,
            kAXPositionAttribute as CFString,
            &positionSettable
        )
        var sizeSettable = DarwinBoolean(false)
        let sizeSettableResult = AXUIElementIsAttributeSettable(
            window,
            kAXSizeAttribute as CFString,
            &sizeSettable
        )

        if positionSettableResult == .apiDisabled || sizeSettableResult == .apiDisabled {
            throw WindowMovementError.accessibilityPermissionMissing
        }

        guard positionSettableResult == .success,
              sizeSettableResult == .success,
              positionSettable.boolValue,
              sizeSettable.boolValue else {
            throw WindowMovementError.unsupportedWindow
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )

        if positionResult == .apiDisabled {
            throw WindowMovementError.accessibilityPermissionMissing
        }

        guard positionResult == .success else {
            throw WindowMovementError.failedToSetWindowFrame
        }

        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        if sizeResult == .apiDisabled {
            throw WindowMovementError.accessibilityPermissionMissing
        }

        guard sizeResult == .success else {
            throw WindowMovementError.failedToSetWindowFrame
        }
    }

    func frame(of window: AXUIElement) throws -> Rect {
        let axFrame = try rawAccessibilityFrame(of: window)
        return try appKitFrame(fromAccessibilityFrame: axFrame)
    }

    func rawAccessibilityFrame(of window: AXUIElement) throws -> Rect {
        let position = try pointAttribute(kAXPositionAttribute, of: window)
        let size = try sizeAttribute(kAXSizeAttribute, of: window)

        return Rect(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }

    func accessibilityFrame(fromAppKitFrame frame: Rect) throws -> Rect {
        let screens = try appKitScreens()
        guard let desktopUnion = ScreenGeometry.desktopUnion(for: screens) else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        return AccessibilityCoordinateConverter(desktopUnion: desktopUnion)
            .accessibilityRect(fromAppKitRect: frame)
    }

    func appKitFrame(fromAccessibilityFrame frame: Rect) throws -> Rect {
        let screens = try appKitScreens()
        guard let desktopUnion = ScreenGeometry.desktopUnion(for: screens) else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        return AccessibilityCoordinateConverter(desktopUnion: desktopUnion)
            .appKitRect(fromAccessibilityRect: frame)
    }

    func pointAttribute(_ attribute: String, of element: AXUIElement) throws -> CGPoint {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        if result == .apiDisabled {
            throw WindowMovementError.accessibilityPermissionMissing
        }

        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID(),
              AXValueGetType(axValue as! AXValue) == .cgPoint else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    func sizeAttribute(_ attribute: String, of element: AXUIElement) throws -> CGSize {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        if result == .apiDisabled {
            throw WindowMovementError.accessibilityPermissionMissing
        }

        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID(),
              AXValueGetType(axValue as! AXValue) == .cgSize else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    func appKitFrame(_ rect: NSRect) -> Rect {
        Rect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
    }
}
