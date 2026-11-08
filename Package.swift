// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "vRemote",
    platforms: [.macOS(.v12)],
    targets: [
        // Shared XPC contract between the app and the privileged HID helper.
        .target(
            name: "HIDHelperShared",
            path: "Sources/HIDHelperShared"
        ),
        .executableTarget(
            name: "vRemote",
            dependencies: ["HIDHelperShared"],
            path: "Sources/vRemote",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        // Runs as root via launchd; seizes the keyboard-class HID collection
        // that macOS refuses to hand to an unprivileged process.
        .executableTarget(
            name: "RemoteMicHIDHelper",
            dependencies: ["HIDHelperShared"],
            path: "Sources/RemoteMicHIDHelper"
        ),
    ]
)
