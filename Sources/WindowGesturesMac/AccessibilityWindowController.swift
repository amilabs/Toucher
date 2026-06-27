import AppKit
import ApplicationServices
import WindowGesturesCore

public final class AccessibilityWindowController: WindowControlling {
    public typealias Window = AXUIElement

    public init() {}

    public func activeWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard result == .success, let window = value else {
            return firstWindow(in: applicationElement)
        }

        return (window as! AXUIElement)
    }

    public func visibleScreenFrame(for window: AXUIElement) -> Rect? {
        let windowFrame = frame(of: window)
        let screens = NSScreen.screens

        guard !screens.isEmpty else {
            return nil
        }

        if let windowFrame {
            return screens
                .map { screen in
                    (screen: screen, visibleFrame: accessibilityVisibleFrame(for: screen))
                }
                .max { lhs, rhs in
                    intersectionArea(lhs.visibleFrame, windowFrame) < intersectionArea(rhs.visibleFrame, windowFrame)
                }?
                .visibleFrame
        }

        return NSScreen.main.map(accessibilityVisibleFrame(for:))
    }

    public func move(_ window: AXUIElement, to frame: Rect) throws {
        var position = CGPoint(x: frame.x, y: frame.y)
        var size = CGSize(width: frame.width, height: frame.height)

        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw AccessibilityWindowError.valueCreationFailed
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )

        guard positionResult == .success else {
            throw AccessibilityWindowError.axError(positionResult)
        }

        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard sizeResult == .success else {
            throw AccessibilityWindowError.axError(sizeResult)
        }
    }
}

public enum AccessibilityWindowError: Error, Equatable {
    case valueCreationFailed
    case axError(AXError)
}

private extension AccessibilityWindowController {
    func firstWindow(in applicationElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXWindowsAttribute as CFString,
            &value
        )

        guard result == .success,
              let windows = value as? [AXUIElement],
              let window = windows.first else {
            return nil
        }

        return window
    }

    func frame(of window: AXUIElement) -> Rect? {
        guard let position = pointAttribute(kAXPositionAttribute, of: window),
              let size = sizeAttribute(kAXSizeAttribute, of: window) else {
            return nil
        }

        return Rect(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }

    func pointAttribute(_ attribute: String, of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID(),
              AXValueGetType(axValue as! AXValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    func sizeAttribute(_ attribute: String, of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID(),
              AXValueGetType(axValue as! AXValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    func accessibilityVisibleFrame(for screen: NSScreen) -> Rect {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        return Rect(
            x: visibleFrame.minX,
            y: screenFrame.maxY - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    func intersectionArea(_ lhs: Rect, _ rhs: Rect) -> Double {
        let minX = max(lhs.x, rhs.x)
        let minY = max(lhs.y, rhs.y)
        let maxX = min(lhs.x + lhs.width, rhs.x + rhs.width)
        let maxY = min(lhs.y + lhs.height, rhs.y + rhs.height)

        return max(0, maxX - minX) * max(0, maxY - minY)
    }
}
