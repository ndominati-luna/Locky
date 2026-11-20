import Foundation

/// Thermal state of the Mac (`ProcessInfo.ThermalState`).
public enum MacThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}
