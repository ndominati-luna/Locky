import Foundation

/// The model of the iPhone the extension runs on.
///
/// The Live Activity cannot measure its Dynamic Island: on an iPhone Duo the island stands upright
/// and clips the sides of the compact presentation, but they are laid out as wide as on any iPhone.
/// Only the model tells.
enum DeviceModel {
    /// Model identifier such as "iPhone19,4" (the simulated model in the simulator).
    static let identifier: String = {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system: utsname = .init()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()

    /// iPhone Duo: its Dynamic Island stands upright, the compact presentation keeps only a symbol
    /// on each side.
    static var hasUprightIsland: Bool {
        uprightIslandModels.contains(identifier)
    }

    private static let uprightIslandModels: Set<String> = ["iPhone19,4"]
}
