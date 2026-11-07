import Foundation

/// Telemetry is intentionally disabled in this fork: nothing leaves the machine.
enum AppAnalytics {
    static func configure() {}

    static func signal(_ name: String, parameters: [String: String] = [:]) {}
}
