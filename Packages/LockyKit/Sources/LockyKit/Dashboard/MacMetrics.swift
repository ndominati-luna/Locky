import Foundation

/// Live state of the Mac, shown on the dashboard of the iPhone (unfolded iPhone Duo). Sent by the
/// Mac every few seconds, only while the dashboard is on screen.
public struct MacMetrics: Codable, Sendable, Equatable {
    /// Share of the processor in use, from 0 to 1.
    public var cpuUsage: Double
    public var coreCount: Int
    /// Memory in use (app memory, wired and compressed, like Activity Monitor), in bytes.
    public var memoryUsed: UInt64
    public var memoryTotal: UInt64
    public var memoryPressure: MemoryPressure
    /// Space available on the startup disk for important use, in bytes.
    public var diskAvailable: UInt64?
    public var diskTotal: UInt64?
    public var diskName: String?
    /// `nil` on Macs without battery.
    public var battery: MacBattery?
    public var thermalState: MacThermalState
    public var bootDate: Date
    /// Volume of the current output, from 0 to 1; `nil` when the output has no volume (HDMI…).
    public var outputVolume: Double?
    public var isMuted: Bool
    public var date: Date

    public init(
        cpuUsage: Double,
        coreCount: Int,
        memoryUsed: UInt64,
        memoryTotal: UInt64,
        memoryPressure: MemoryPressure,
        diskAvailable: UInt64?,
        diskTotal: UInt64?,
        diskName: String?,
        battery: MacBattery?,
        thermalState: MacThermalState,
        bootDate: Date,
        outputVolume: Double?,
        isMuted: Bool,
        date: Date
    ) {
        self.cpuUsage = cpuUsage
        self.coreCount = coreCount
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.memoryPressure = memoryPressure
        self.diskAvailable = diskAvailable
        self.diskTotal = diskTotal
        self.diskName = diskName
        self.battery = battery
        self.thermalState = thermalState
        self.bootDate = bootDate
        self.outputVolume = outputVolume
        self.isMuted = isMuted
        self.date = date
    }

    /// Share of the memory in use, from 0 to 1.
    public var memoryUsage: Double {
        memoryTotal > 0 ? min(1, Double(memoryUsed) / Double(memoryTotal)) : 0
    }

    /// Share of the startup disk in use, from 0 to 1.
    public var diskUsage: Double? {
        guard let diskAvailable, let diskTotal, diskTotal > 0 else { return nil }
        return min(1, max(0, 1 - Double(diskAvailable) / Double(diskTotal)))
    }
}
