import Foundation
import HIDHelperShared

/// App-side connection to the privileged HID helper.
///
/// The helper runs as root because macOS refuses `kIOHIDOptionsTypeSeizeDevice`
/// for keyboard-class HID devices to unprivileged processes. The app never
/// opens the remote's HID collection itself while the helper is in charge.
final class ChromecastHIDHelperClient: NSObject, HIDHelperClientProtocol {
    var onButton: ((String, Bool) -> Void)?
    var onDeviceState: ((Bool) -> Void)?

    private var connection: NSXPCConnection?
    private var unresolvedCompletion: ((ChromecastHIDHelperClient?) -> Void)?
    private var resolved = false

    /// Connects and asks the helper to seize the device.
    /// Returns `nil` when the helper is not installed or cannot seize.
    static func probe(
        timeout: TimeInterval = 1.2,
        onButton: ((String, Bool) -> Void)? = nil,
        onDeviceState: ((Bool) -> Void)? = nil,
        completion: @escaping (ChromecastHIDHelperClient?) -> Void
    ) {
        let client = ChromecastHIDHelperClient()
        client.onButton = onButton
        client.onDeviceState = onDeviceState
        client.beginProbe(timeout: timeout, completion: completion)
    }

    private func beginProbe(
        timeout: TimeInterval,
        completion: @escaping (ChromecastHIDHelperClient?) -> Void
    ) {
        unresolvedCompletion = completion

        let connection = NSXPCConnection(
            machServiceName: HIDHelperConstants.machServiceName,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: HIDHelperServiceProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: HIDHelperClientProtocol.self)
        connection.exportedObject = self
        connection.invalidationHandler = { [weak self] in
            self?.resolve(nil)
        }
        connection.interruptionHandler = { [weak self] in
            self?.resolve(nil)
        }
        self.connection = connection
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self] _ in
            self?.resolve(nil)
        }) as? HIDHelperServiceProtocol else {
            resolve(nil)
            return
        }
        proxy.subscribe { [weak self] seized in
            self?.resolve(seized ? self : nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.resolve(nil)
        }
    }

    private func resolve(_ client: ChromecastHIDHelperClient?) {
        guard !resolved else { return }
        resolved = true
        let completion = unresolvedCompletion
        unresolvedCompletion = nil
        if client == nil {
            connection?.invalidate()
            connection = nil
        }
        DispatchQueue.main.async {
            completion?(client)
        }
    }

    func invalidate() {
        resolved = true
        unresolvedCompletion = nil
        if let connection {
            if let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in })
                as? HIDHelperServiceProtocol {
                proxy.unsubscribe {}
            }
            connection.invalidate()
        }
        connection = nil
    }

    // MARK: - HIDHelperClientProtocol

    func buttonEvent(usageHex: String, isDown: Bool) {
        print("[CAST-HID] helper button \(usageHex) \(isDown ? "DOWN" : "UP")")
        guard let onButton else { return }
        DispatchQueue.main.async {
            onButton(usageHex, isDown)
        }
    }

    func deviceState(connected: Bool) {
        print("[CAST-HID] helper device state connected=\(connected)")
        guard let onDeviceState else { return }
        DispatchQueue.main.async {
            onDeviceState(connected)
        }
    }
}
