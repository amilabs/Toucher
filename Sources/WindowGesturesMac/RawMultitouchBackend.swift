import Foundation
import Darwin
import WindowGesturesCore

public struct RawMultitouchBackendStatus: Equatable, Sendable {
    public var isAvailable: Bool
    public var isActive: Bool
    public var devicesFound: Int
    public var activeTouches: Int
    public var lastError: String?

    public init(
        isAvailable: Bool = false,
        isActive: Bool = false,
        devicesFound: Int = 0,
        activeTouches: Int = 0,
        lastError: String? = nil
    ) {
        self.isAvailable = isAvailable
        self.isActive = isActive
        self.devicesFound = devicesFound
        self.activeTouches = activeTouches
        self.lastError = lastError
    }
}

public final class RawMultitouchBackend: GestureMonitoring {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    private static var activeBackend: RawMultitouchBackend?

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var symbols: MultitouchSymbols?
    private var deviceList: CFArray?
    private var devices: [MTDeviceRef] = []
    private let handleSample: (RawTouchSample) -> Void
    private let handleStatus: (RawMultitouchBackendStatus) -> Void

    public private(set) var isActive = false
    public private(set) var status = RawMultitouchBackendStatus()

    public init(
        handleSample: @escaping (RawTouchSample) -> Void,
        handleStatus: @escaping (RawMultitouchBackendStatus) -> Void
    ) {
        self.handleSample = handleSample
        self.handleStatus = handleStatus
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isActive else {
            return
        }

        guard MemoryLayout<MTTouch>.stride >= 80 else {
            updateStatus(
                RawMultitouchBackendStatus(
                    lastError: "unexpected private touch struct layout"
                )
            )
            return
        }

        guard loadFrameworkAndSymbols() else {
            return
        }
        guard let symbols else {
            updateStatus(RawMultitouchBackendStatus(lastError: "raw multitouch symbols unavailable"))
            return
        }
        guard let unmanagedDeviceList = symbols.deviceCreateList() else {
            updateStatus(
                RawMultitouchBackendStatus(
                    isAvailable: true,
                    lastError: "MTDeviceCreateList returned nil"
                )
            )
            return
        }

        let list = unmanagedDeviceList.takeRetainedValue()
        deviceList = list
        let deviceCount = CFArrayGetCount(list)
        guard deviceCount > 0 else {
            updateStatus(
                RawMultitouchBackendStatus(
                    isAvailable: true,
                    devicesFound: 0,
                    lastError: "no raw multitouch devices found"
                )
            )
            return
        }

        devices = (0..<deviceCount).compactMap { index in
            guard let value = CFArrayGetValueAtIndex(list, index) else {
                return nil
            }

            return MTDeviceRef(mutating: value)
        }

        guard !devices.isEmpty else {
            updateStatus(
                RawMultitouchBackendStatus(
                    isAvailable: true,
                    devicesFound: deviceCount,
                    lastError: "raw multitouch device list contained invalid entries"
                )
            )
            return
        }

        Self.activeBackend = self
        for device in devices {
            symbols.registerContactFrameCallback(device, Self.contactFrameCallback)
            _ = symbols.deviceStart(device, 0)
        }

        isActive = true
        updateStatus(
            RawMultitouchBackendStatus(
                isAvailable: true,
                isActive: true,
                devicesFound: devices.count
            )
        )
    }

    public func stop() {
        if let symbols {
            for device in devices {
                symbols.registerContactFrameCallback(device, Optional<MTContactCallback>.none)
                _ = symbols.deviceStop(device)
            }
        }

        devices.removeAll()
        deviceList = nil
        isActive = false
        if Self.activeBackend === self {
            Self.activeBackend = nil
        }

        if frameworkHandle != nil {
            dlclose(frameworkHandle)
            frameworkHandle = nil
        }
        symbols = nil
        updateStatus(
            RawMultitouchBackendStatus(
                isAvailable: status.isAvailable,
                devicesFound: status.devicesFound,
                lastError: status.lastError
            )
        )
    }

    private func loadFrameworkAndSymbols() -> Bool {
        if symbols != nil {
            return true
        }

        guard let handle = dlopen(Self.frameworkPath, RTLD_LAZY | RTLD_LOCAL) else {
            updateStatus(
                RawMultitouchBackendStatus(
                    lastError: String(cString: dlerror())
                )
            )
            return false
        }

        frameworkHandle = handle
        guard let loadedSymbols = MultitouchSymbols(handle: handle) else {
            updateStatus(
                RawMultitouchBackendStatus(
                    lastError: "required MultitouchSupport symbols unavailable"
                )
            )
            dlclose(handle)
            frameworkHandle = nil
            return false
        }

        symbols = loadedSymbols
        updateStatus(RawMultitouchBackendStatus(isAvailable: true))
        return true
    }

    private func handleFrame(
        touches: UnsafeMutableRawPointer?,
        fingerCount: Int32,
        timestamp: Double
    ) {
        guard fingerCount >= 0,
              fingerCount <= 32 else {
            publishStatus(activeTouches: 0, lastError: "malformed raw touch count: \(fingerCount)")
            return
        }

        let count = Int(fingerCount)
        guard count > 0,
              let touches else {
            publishStatus(activeTouches: 0)
            publishSample(RawTouchSample(activeTouchCount: 0, centroidX: 0, centroidY: 0, timestamp: timestamp))
            return
        }

        let boundTouches = touches.bindMemory(to: MTTouch.self, capacity: count)
        var sumX = 0.0
        var sumY = 0.0
        for index in 0..<count {
            let touch = boundTouches[index]
            let x = Double(touch.normalized.position.x)
            let y = Double(touch.normalized.position.y)
            guard x.isFinite,
                  y.isFinite,
                  x >= -0.5,
                  x <= 1.5,
                  y >= -0.5,
                  y <= 1.5 else {
                publishStatus(activeTouches: count, lastError: "malformed raw touch coordinates")
                return
            }
            sumX += x
            sumY += y
        }

        let sample = RawTouchSample(
            activeTouchCount: count,
            centroidX: sumX / Double(count),
            centroidY: sumY / Double(count),
            timestamp: timestamp
        )
        publishStatus(activeTouches: count)
        publishSample(sample)
    }

    private func publishSample(_ sample: RawTouchSample) {
        DispatchQueue.main.async { [handleSample] in
            handleSample(sample)
        }
    }

    private func publishStatus(activeTouches: Int, lastError: String? = nil) {
        let newStatus = RawMultitouchBackendStatus(
            isAvailable: status.isAvailable,
            isActive: isActive,
            devicesFound: status.devicesFound,
            activeTouches: activeTouches,
            lastError: lastError ?? status.lastError
        )
        DispatchQueue.main.async { [weak self] in
            self?.updateStatus(newStatus)
        }
    }

    private func updateStatus(_ newStatus: RawMultitouchBackendStatus) {
        status = newStatus
        handleStatus(newStatus)
    }

    private static let contactFrameCallback: MTContactCallback = { _, touches, fingerCount, timestamp, _ in
        RawMultitouchBackend.activeBackend?.handleFrame(
            touches: touches,
            fingerCount: fingerCount,
            timestamp: timestamp
        )
        return 0
    }
}

private typealias MTDeviceRef = UnsafeMutableRawPointer
private typealias MTDeviceCreateList = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterContactFrameCallback = @convention(c) (MTDeviceRef, MTContactCallback?) -> Void
private typealias MTDeviceStart = @convention(c) (MTDeviceRef, Int32) -> Int32
private typealias MTDeviceStop = @convention(c) (MTDeviceRef) -> Int32
private typealias MTContactCallback = @convention(c) (Int32, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

private struct MultitouchSymbols {
    var deviceCreateList: MTDeviceCreateList
    var registerContactFrameCallback: MTRegisterContactFrameCallback
    var deviceStart: MTDeviceStart
    var deviceStop: MTDeviceStop

    init?(handle: UnsafeMutableRawPointer) {
        guard let deviceCreateList = Self.load("MTDeviceCreateList", from: handle, as: MTDeviceCreateList.self),
              let registerContactFrameCallback = Self.load(
                "MTRegisterContactFrameCallback",
                from: handle,
                as: MTRegisterContactFrameCallback.self
              ),
              let deviceStart = Self.load("MTDeviceStart", from: handle, as: MTDeviceStart.self),
              let deviceStop = Self.load("MTDeviceStop", from: handle, as: MTDeviceStop.self) else {
            return nil
        }

        self.deviceCreateList = deviceCreateList
        self.registerContactFrameCallback = registerContactFrameCallback
        self.deviceStart = deviceStart
        self.deviceStop = deviceStop
    }

    private static func load<T>(_ name: String, from handle: UnsafeMutableRawPointer, as type: T.Type) -> T? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }

        return unsafeBitCast(symbol, to: type)
    }
}

private struct MTPoint {
    var x: Float
    var y: Float
}

private struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

private struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var foo3: Int32
    var foo4: Int32
    var normalized: MTVector
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var mm: MTVector
    var zero2a: Int32
    var zero2b: Int32
    var unknown2: Float
}
