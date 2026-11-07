import Foundation
import HIDHelperShared
import IOKit.hid
import Security

private func helperLog(_ message: String) {
    NSLog("[vRemoteHIDHelper] %@", message)
    FileHandle.standardError.write(Data(("[vRemoteHIDHelper] " + message + "\n").utf8))
}

private func deviceMatchedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<HelperService>.fromOpaque(context).takeUnretainedValue()
        .deviceDidMatch(device)
}

private func deviceRemovedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<HelperService>.fromOpaque(context).takeUnretainedValue()
        .deviceDidRemove(device)
}

private func inputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, result == kIOReturnSuccess, reportLength > 0 else { return }
    Unmanaged<HelperService>.fromOpaque(context).takeUnretainedValue()
        .handleReport(reportID: reportID, data: Data(bytes: report, count: reportLength))
}

/// Owns the Chromecast Remote HID collection on behalf of the app.
///
/// macOS refuses `kIOHIDOptionsTypeSeizeDevice` for keyboard-class HID
/// devices unless the caller is privileged, so this process runs as root.
final class HelperService: NSObject, HIDHelperServiceProtocol {
    private static let vendorID: Int = 0x18D1
    private static let productID: Int = 0x9450

    private let manager: IOHIDManager
    private var subscribers: [ObjectIdentifier: NSXPCConnection] = [:]
    private var isSeized = false
    private var deviceConnected = false
    private var lastButtonID: String?

    override init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        super.init()

        IOHIDManagerSetDeviceMatching(
            manager,
            [
                kIOHIDVendorIDKey: Self.vendorID,
                kIOHIDProductIDKey: Self.productID,
            ] as CFDictionary
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, context)
        IOHIDManagerRegisterInputReportCallback(manager, inputReportCallback, context)
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
           !devices.isEmpty {
            deviceConnected = true
        }
    }

    // MARK: - HIDHelperServiceProtocol

    func subscribe(reply: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let ok = self.seize()
            reply(ok)
            self.broadcastDeviceState()
        }
    }

    func unsubscribe(reply: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.releaseDevice()
            reply()
        }
    }

    // MARK: - Subscribers

    func addSubscriber(_ connection: NSXPCConnection) {
        let key = ObjectIdentifier(connection)
        subscribers[key] = connection
        connection.invalidationHandler = { [weak self, weak connection] in
            guard let self, let connection else { return }
            DispatchQueue.main.async {
                self.subscribers.removeValue(forKey: ObjectIdentifier(connection))
                if self.subscribers.isEmpty {
                    self.releaseDevice()
                }
                self.broadcastDeviceState()
            }
        }
        connection.interruptionHandler = { [weak self, weak connection] in
            guard let self, let connection else { return }
            DispatchQueue.main.async {
                self.subscribers.removeValue(forKey: ObjectIdentifier(connection))
            }
        }
    }

    private func broadcast(_ body: (HIDHelperClientProtocol) -> Void) {
        for connection in subscribers.values {
            guard let proxy = connection.remoteObjectProxy as? HIDHelperClientProtocol else {
                continue
            }
            body(proxy)
        }
    }

    private func broadcastDeviceState() {
        let connected = deviceConnected
        broadcast { $0.deviceState(connected: connected) }
    }

    // MARK: - Seize / release

    private func seize() -> Bool {
        guard !isSeized else { return true }
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result == kIOReturnSuccess else {
            helperLog(
                "seize failed: " + String(format: "0x%08X", UInt32(bitPattern: result)) +
                " (euid=\(geteuid()); the helper must run as root)"
            )
            return false
        }
        isSeized = true
        helperLog("seized Chromecast Remote HID collection (VID=0x18D1 PID=0x9450)")
        return true
    }

    private func releaseDevice() {
        guard isSeized else { return }
        lastButtonID = nil
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isSeized = false
        helperLog("released Chromecast Remote HID collection")
    }

    // MARK: - HID events

    func deviceDidMatch(_ device: IOHIDDevice) {
        deviceConnected = true
        helperLog("device matched")
        broadcastDeviceState()
    }

    func deviceDidRemove(_ device: IOHIDDevice) {
        deviceConnected = false
        lastButtonID = nil
        helperLog("device removed")
        broadcastDeviceState()
        broadcast { $0.buttonEvent(usageHex: "00", isDown: false) }
    }

    func handleReport(reportID: UInt32, data: Data) {
        guard reportID == 0x01 else { return }
        let payload = data.first == UInt8(truncatingIfNeeded: reportID)
            ? Data(data.dropFirst())
            : data
        guard let usage = payload.first else { return }

        if usage == 0 {
            guard let buttonID = lastButtonID else { return }
            lastButtonID = nil
            broadcast { $0.buttonEvent(usageHex: buttonID, isDown: false) }
            return
        }

        let buttonID = String(format: "%02X", usage)
        guard lastButtonID != buttonID else { return }
        if let previous = lastButtonID {
            broadcast { $0.buttonEvent(usageHex: previous, isDown: false) }
        }
        lastButtonID = buttonID
        broadcast { $0.buttonEvent(usageHex: buttonID, isDown: true) }
    }
}

/// Only accept connections from our app.
///
/// The helper is ad-hoc signed together with the app, so there is no team
/// identifier to pin. We therefore resolve the peer process by PID and check
/// its code-signing identifier. A local attacker able to ad-hoc sign an app
/// with the same identifier could impersonate the app; that is an accepted
/// limit of an unsigned local build.
private func clientIsTrusted(_ connection: NSXPCConnection) -> Bool {
    let pid = connection.processIdentifier
    guard pid > 0 else {
        helperLog("rejecting connection: unknown peer pid")
        return false
    }
    let attributes = [kSecGuestAttributePid as String: pid] as CFDictionary

    var code: SecCode?
    guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
          let code
    else {
        helperLog("rejecting connection: cannot resolve peer code (pid \(pid))")
        return false
    }

    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
          let staticCode
    else {
        helperLog("rejecting connection: cannot resolve static code (pid \(pid))")
        return false
    }

    var info: CFDictionary?
    guard SecCodeCopySigningInformation(
        staticCode,
        SecCSFlags(rawValue: kSecCSSigningInformation),
        &info
    ) == errSecSuccess,
          let dictionary = info as? [String: Any],
          let identifier = dictionary[kSecCodeInfoIdentifier as String] as? String
    else {
        helperLog("rejecting connection: cannot read signing information")
        return false
    }

    guard identifier == HIDHelperConstants.clientIdentifier else {
        helperLog("rejecting connection from identifier \(identifier)")
        return false
    }
    return true
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: HelperService

    init(service: HelperService) {
        self.service = service
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard clientIsTrusted(newConnection) else { return false }
        newConnection.exportedInterface = NSXPCInterface(with: HIDHelperServiceProtocol.self)
        newConnection.exportedObject = service
        newConnection.remoteObjectInterface = NSXPCInterface(with: HIDHelperClientProtocol.self)
        newConnection.resume()
        service.addSubscriber(newConnection)
        helperLog("client connected")
        return true
    }
}

helperLog("starting; euid=\(geteuid())")
let service = HelperService()
let delegate = ListenerDelegate(service: service)
let listener = NSXPCListener(machServiceName: HIDHelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
