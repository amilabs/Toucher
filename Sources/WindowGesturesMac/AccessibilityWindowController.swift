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
        let screens = NSScreen.screens

        guard !screens.isEmpty else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        guard let visibleFrame = screens
            .map({ screen in
                (screen: screen, visibleFrame: accessibilityVisibleFrame(for: screen))
            })
            .max(by: { lhs, rhs in
                intersectionArea(lhs.visibleFrame, windowFrame) < intersectionArea(rhs.visibleFrame, windowFrame)
            })?
            .visibleFrame else {
            throw WindowMovementError.failedToReadWindowFrame
        }

        return visibleFrame
    }

    public func frame(for window: AXUIElement) throws -> Rect {
        try frame(of: window)
    }

    public func move(_ window: AXUIElement, to frame: Rect) throws {
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

        guard positionResult == .success else {
            throw WindowMovementError.failedToSetWindowFrame
        }

        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard sizeResult == .success else {
            throw WindowMovementError.failedToSetWindowFrame
        }
    }

    public func restoreIdentifier(for window: AXUIElement) -> String? {
        String(CFHash(window))
    }
}

private extension AccessibilityWindowController {
    func frame(of window: AXUIElement) throws -> Rect {
        guard let position = pointAttribute(kAXPositionAttribute, of: window),
              let size = sizeAttribute(kAXSizeAttribute, of: window) else {
            throw WindowMovementError.failedToReadWindowFrame
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
