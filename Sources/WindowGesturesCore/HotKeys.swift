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
    case upArrow
    case downArrow
}

public struct HotKeyModifiers: OptionSet, Equatable, Hashable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let control = HotKeyModifiers(rawValue: 1 << 0)
    public static let shift = HotKeyModifiers(rawValue: 1 << 1)
    public static let command = HotKeyModifiers(rawValue: 1 << 2)
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

    public static let doubleUpHotKey = HotKey(
        key: .upArrow,
        modifiers: [.control, .shift]
    )

    public static let restoreHotKey = HotKey(
        key: .downArrow,
        modifiers: [.control, .shift]
    )

    public static let commandLeftHalfHotKey = HotKey(
        key: .leftArrow,
        modifiers: [.control, .shift, .command]
    )

    public static let commandRightHalfHotKey = HotKey(
        key: .rightArrow,
        modifiers: [.control, .shift, .command]
    )

    public static let defaultHotKeys = [
        leftHalfHotKey,
        rightHalfHotKey,
        commandLeftHalfHotKey,
        commandRightHalfHotKey,
        doubleUpHotKey,
        restoreHotKey
    ]

    public static func action(for hotKey: HotKey) -> WindowAction? {
        switch hotKey {
        case leftHalfHotKey:
            return .leftHalf
        case rightHalfHotKey:
            return .rightHalf
        case commandLeftHalfHotKey:
            return .leftHalf
        case commandRightHalfHotKey:
            return .rightHalf
        case restoreHotKey:
            return .restore
        default:
            return nil
        }
    }

    public static func screenTarget(for hotKey: HotKey) -> WindowScreenTarget {
        hotKey.modifiers.contains(.command) ? .next : .current
    }
}

public final class HotKeySequenceRecognizer {
    private let doublePressInterval: TimeInterval
    private var lastUpPressTime: TimeInterval?

    public init(doublePressInterval: TimeInterval = 0.4) {
        self.doublePressInterval = doublePressInterval
    }

    public func action(for hotKey: HotKey, at time: TimeInterval) -> WindowAction? {
        guard hotKey == HotKeyMapping.doubleUpHotKey else {
            lastUpPressTime = nil
            return HotKeyMapping.action(for: hotKey)
        }

        guard let lastUpPressTime,
              time - lastUpPressTime <= doublePressInterval else {
            lastUpPressTime = time
            return .maximize
        }

        self.lastUpPressTime = nil
        return .verticalMaxCenterThird
    }
}
