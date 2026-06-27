import Foundation

public struct HotKey: Equatable, Hashable, Sendable {
    public var key: HotKeyKey
    public var modifiers: HotKeyModifiers

    public init(key: HotKeyKey, modifiers: HotKeyModifiers) {
        self.key = key
        self.modifiers = modifiers
    }
}

public enum HotKeyKey: Equatable, Hashable, Sendable {
    case leftArrow
    case rightArrow
}

public struct HotKeyModifiers: OptionSet, Equatable, Hashable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let control = HotKeyModifiers(rawValue: 1 << 0)
    public static let shift = HotKeyModifiers(rawValue: 1 << 1)
}

public enum HotKeyMapping {
    public static let leftHalfHotKey = HotKey(
        key: .leftArrow,
        modifiers: [.control, .shift]
    )

    public static let rightHalfHotKey = HotKey(
        key: .rightArrow,
        modifiers: [.control, .shift]
    )

    public static let defaultHotKeys = [
        leftHalfHotKey,
        rightHalfHotKey
    ]

    public static func action(for hotKey: HotKey) -> WindowAction? {
        switch hotKey {
        case leftHalfHotKey:
            return .leftHalf
        case rightHalfHotKey:
            return .rightHalf
        default:
            return nil
        }
    }
}
