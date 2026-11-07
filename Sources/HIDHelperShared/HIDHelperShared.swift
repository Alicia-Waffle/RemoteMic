import Foundation

public enum HIDHelperConstants {
    /// Mach service name advertised by the launchd job.
    public static let machServiceName = "local.simaqingfeng.vRemote.hidhelper"
    /// launchd label, also used as the installed helper file name.
    public static let label = "local.simaqingfeng.vRemote.hidhelper"
    /// Only this code-signing identifier may talk to the helper.
    public static let clientIdentifier = "local.simaqingfeng.vRemote"
}

@objc public protocol HIDHelperServiceProtocol {
    /// Starts seizing the remote and streaming button events.
    /// `reply(true)` means the helper took exclusive ownership of the device.
    func subscribe(reply: @escaping (Bool) -> Void)
    /// Releases the device so macOS can own it again.
    func unsubscribe(reply: @escaping () -> Void)
}

@objc public protocol HIDHelperClientProtocol {
    func buttonEvent(usageHex: String, isDown: Bool)
    func deviceState(connected: Bool)
}
