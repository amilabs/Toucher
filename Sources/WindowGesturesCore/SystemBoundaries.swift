import Foundation

public protocol HotKeyRegistering: AnyObject {
    func register(_ hotKeys: [HotKey], handler: @escaping @Sendable (HotKey) -> Void) throws
    func unregisterAll()
}

public protocol PermissionChecking {
    var hasAccessibilityPermission: Bool { get }
    func openAccessibilitySettings()
}

public protocol WindowControlling {
    associatedtype Window

    func focusedWindow() throws -> Window
    func visibleScreenFrame(for window: Window) throws -> Rect
    func move(_ window: Window, to frame: Rect) throws
}
