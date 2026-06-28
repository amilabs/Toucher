import Carbon
import Foundation
import WindowGesturesCore

public final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private var hotKeysByID: [UInt32: HotKey] = [:]
    private var nextID: UInt32 = 1
    private var handler: (@Sendable (HotKey) -> Void)?

    public init() {}

    deinit {
        unregisterAll()
    }

    public func register(_ hotKeys: [HotKey], handler: @escaping @Sendable (HotKey) -> Void) throws {
        unregisterAll()
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard handlerStatus == noErr else {
            throw CarbonHotKeyError.installHandlerFailed(handlerStatus)
        }

        for hotKey in hotKeys {
            let id = nextID
            nextID += 1

            let hotKeyID = EventHotKeyID(
                signature: CarbonHotKeyRegistrar.signature,
                id: id
            )

            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                hotKey.carbonKeyCode,
                hotKey.carbonModifierFlags,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            guard status == noErr, let hotKeyRef else {
                unregisterAll()
                throw CarbonHotKeyError.registrationFailed(hotKey, status)
            }

            hotKeyRefs.append(hotKeyRef)
            hotKeysByID[id] = hotKey
        }
    }

    public func unregisterAll() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs.removeAll()
        hotKeysByID.removeAll()

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        handler = nil
    }

    fileprivate func handlePressedHotKey(id: UInt32) {
        guard let hotKey = hotKeysByID[id], let handler else {
            return
        }

        DispatchQueue.main.async {
            handler(hotKey)
        }
    }
}

public enum CarbonHotKeyError: Error, Equatable {
    case unsupportedHotKey(HotKey)
    case installHandlerFailed(OSStatus)
    case registrationFailed(HotKey, OSStatus)
}

private extension CarbonHotKeyRegistrar {
    static let signature: OSType = 0x57474b59
}

private extension HotKey {
    var carbonKeyCode: UInt32 {
        switch key {
        case .leftArrow:
            return UInt32(kVK_LeftArrow)
        case .rightArrow:
            return UInt32(kVK_RightArrow)
        case .upArrow:
            return UInt32(kVK_UpArrow)
        case .downArrow:
            return UInt32(kVK_DownArrow)
        }
    }

    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0

        if modifiers.contains(.control) {
            flags |= UInt32(controlKey)
        }

        if modifiers.contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        if modifiers.contains(.command) {
            flags |= UInt32(cmdKey)
        }

        return flags
    }
}

private func carbonHotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr,
          hotKeyID.signature == CarbonHotKeyRegistrar.signature else {
        return noErr
    }

    let registrar = Unmanaged<CarbonHotKeyRegistrar>
        .fromOpaque(userData)
        .takeUnretainedValue()
    registrar.handlePressedHotKey(id: hotKeyID.id)

    return noErr
}
