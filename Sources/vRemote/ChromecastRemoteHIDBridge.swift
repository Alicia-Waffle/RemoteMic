import Foundation
import IOKit.hid

private func chromecastRemoteMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceDidMatch(result: result, device: device)
}

private func chromecastRemoteRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceDidRemove(device)
}

private func chromecastRemoteInputReport(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, result == kIOReturnSuccess, reportLength > 0 else {
        return
    }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .handleReport(
            reportID: reportID,
            data: Data(bytes: report, count: reportLength)
        )
}

/// Connection monitor for the Google Chromecast Remote HID interface.
///
/// Its voice key does not expose a dependable HID key-down usage on macOS;
/// voice gestures are therefore handled by the remote's ATVV control stream.
final class ChromecastRemoteHIDBridge {
    static let vendorID = 0x18D1
    static let productID = 0x9450

    var onConnectionChanged: ((Bool) -> Void)?

    private var manager: IOHIDManager?
    private var activeDevice: IOHIDDevice?
    private var remappingEnabled = RemoteMappingStore.shared.isEnabled(.chromecast)
    private var lastButtonID: String?
    private var helperClient: ChromecastHIDHelperClient?
    private let gestureRecognizer = RemoteGestureRecognizer()

    init() {
        gestureRecognizer.isGestureEnabled = { buttonID in
            guard RemoteMappingStore.shared.isEnabled(.chromecast),
                  let button = RemoteProfiles.chromecastButtons.first(
                      where: { $0.id == buttonID }
                  )
            else { return false }
            // 双击 / 长按都禁用时没有任何手势要判定，直接走最短路径：
            // 按下 / 松开原样转发，不建任何定时器。
            guard button.remappable && !button.voiceControlled else { return false }
            let store = RemoteMappingStore.shared
            return store.target(for: button, remote: .chromecast, gesture: .double) != .disabled
                || store.target(for: button, remote: .chromecast, gesture: .long) != .disabled
        }
        gestureRecognizer.isDoubleEnabled = { buttonID in
            guard let button = RemoteProfiles.chromecastButtons.first(
                where: { $0.id == buttonID }
            ) else { return false }
            return RemoteMappingStore.shared.target(
                for: button,
                remote: .chromecast,
                gesture: .double
            ) != .disabled
        }
        gestureRecognizer.isLongEnabled = { buttonID in
            guard let button = RemoteProfiles.chromecastButtons.first(
                where: { $0.id == buttonID }
            ) else { return false }
            return RemoteMappingStore.shared.target(
                for: button,
                remote: .chromecast,
                gesture: .long
            ) != .disabled
        }
        gestureRecognizer.onGesture = { [weak self] buttonID, gesture, isDown in
            self?.postGesture(buttonID: buttonID, gesture: gesture, isDown: isDown)
        }
    }

    func start() {
        stop()
        guard remappingEnabled else {
            // Without remapping there is nothing to map, and macOS will not
            // deliver reports to an unprivileged observer. Keep the in-process
            // path for connection state only.
            startLocalHID()
            return
        }
        // macOS returns kIOReturnNotPrivileged for a keyboard-class HID device
        // opened with kIOHIDOptionsTypeSeizeDevice by a non-privileged
        // process, so a root helper has to own the collection.
        ChromecastHIDHelperClient.probe { [weak self] client in
            guard let self else { return }
            guard let client else {
                print(
                    "[CAST-HID] privileged helper unavailable; " +
                    "in-process seize will fail (0xE00002C1)"
                )
                self.startLocalHID()
                return
            }
            self.helperClient = client
            client.onButton = { [weak self] usageHex, isDown in
                self?.apply(buttonID: usageHex, isDown: isDown)
            }
            client.onDeviceState = { [weak self] connected in
                guard let self else { return }
                print("[CAST-HID] helper device \(connected ? "connected" : "disconnected")")
                self.onConnectionChanged?(connected)
            }
            print("[CAST-HID] privileged helper active")
        }
    }

    private func startLocalHID() {
        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        IOHIDManagerSetDeviceMatching(
            manager,
            [
                kIOHIDVendorIDKey: Self.vendorID,
                kIOHIDProductIDKey: Self.productID,
            ] as CFDictionary
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            chromecastRemoteMatched,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            chromecastRemoteRemoved,
            context
        )
        IOHIDManagerRegisterInputReportCallback(
            manager,
            chromecastRemoteInputReport,
            context
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        // Open the manager exclusively, not just one IOHIDDevice returned by
        // the match callback. The remote exposes more than one HID
        // collection; seizing only the first collection still lets its media
        // usage reach macOS (for example Select can launch Apple Music).
        let openOptions = remappingEnabled
            ? IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
            : IOOptionBits(kIOHIDOptionsTypeNone)
        let result = IOHIDManagerOpen(manager, openOptions)
        guard result == kIOReturnSuccess else {
            print(
                "[CAST-HID] manager open failed: " +
                String(format: "0x%08X", UInt32(bitPattern: result))
            )
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            return
        }
        self.manager = manager
        print("[CAST-HID] waiting for Chromecast Remote")
    }

    func stop() {
        activeDevice = nil
        lastButtonID = nil

        gestureRecognizer.cancelPending()

        helperClient?.invalidate()
        helperClient = nil

        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = nil
        }

        onConnectionChanged?(false)
    }

    func setRemappingEnabled(_ enabled: Bool) {
        guard remappingEnabled != enabled else { return }
        remappingEnabled = enabled
        start()
    }

    fileprivate func deviceDidMatch(
        result: IOReturn,
        device: IOHIDDevice
    ) {
        guard result == kIOReturnSuccess, activeDevice == nil else { return }
        // IOHIDManagerOpen already opened every current and future matching
        // HID collection with the requested access mode.
        activeDevice = device
        onConnectionChanged?(true)
        print(
            "[CAST-HID] connected VID=0x18d1 PID=0x9450 " +
            "mode=\(remappingEnabled ? "remap" : "observe")"
        )
    }

    fileprivate func deviceDidRemove(_ device: IOHIDDevice) {
        guard let activeDevice, CFEqual(activeDevice, device) else { return }
        self.activeDevice = nil
        onConnectionChanged?(false)
        print("[CAST-HID] disconnected")
    }

    fileprivate func handleReport(reportID: UInt32, data: Data) {
        guard reportID == 0x01 else { return }
        let payload = data.first == UInt8(truncatingIfNeeded: reportID)
            ? Data(data.dropFirst())
            : data
        guard let usage = payload.first else { return }

        if usage == 0 {
            guard let buttonID = lastButtonID else { return }
            lastButtonID = nil
            apply(buttonID: buttonID, isDown: false)
            return
        }

        let buttonID = String(format: "%02X", usage)
        guard lastButtonID != buttonID else { return }
        if let previous = lastButtonID {
            apply(buttonID: previous, isDown: false)
        }
        lastButtonID = buttonID
        apply(buttonID: buttonID, isDown: true)
    }

    private func apply(buttonID: String, isDown: Bool) {
        guard remappingEnabled else { return }
        guard let button = RemoteProfiles.chromecastButtons.first(
            where: { $0.id == buttonID }
        ) else {
            // 未知 usage 一定要打印出来，方便真机上补齐映射表。
            print(
                "[CAST-MAP] 未知按键 usage=\(buttonID)；" +
                "可补到 RemoteMappingSupport.chromecastButtons"
            )
            return
        }
        // 语音键走 ATVV，不参与手势判定。
        guard !button.voiceControlled else { return }
        gestureRecognizer.handle(buttonID: buttonID, isDown: isDown)
    }

    private func postGesture(
        buttonID: String,
        gesture: RemoteGesture,
        isDown: Bool
    ) {
        guard let button = RemoteProfiles.chromecastButtons.first(
            where: { $0.id == buttonID }
        ) else { return }
        let store = RemoteMappingStore.shared
        store.post(
            button: button,
            remote: .chromecast,
            gesture: gesture,
            isDown: isDown
        )
        print(
            "[CAST-MAP] \(button.title) \(gesture.rawValue) " +
            "\(isDown ? "DOWN" : "UP") -> " +
            store.targetTitle(for: button, remote: .chromecast, gesture: gesture)
        )
    }
}
