import Darwin
import Foundation
import IOKit.ps
import LockyKit

/// Reads the processor, memory, disk, battery and thermal state of the Mac with public APIs that
/// need no permission.
struct MacMetricsSampler {
    /// Ticks of the previous sample (user, system, idle, nice), to compute the processor load.
    private var previousTicks: [UInt32]?

    mutating func sample() -> MacMetrics {
        let ticks: [UInt32]? = Self.cpuTicks()
        var cpuUsage: Double = 0
        if let previousTicks, let ticks {
            // The counters are 32 bits and wrap: subtract with overflow.
            let deltas: [UInt64] = zip(ticks, previousTicks).map { UInt64($0 &- $1) }
            let total: UInt64 = deltas.reduce(0, +)
            if total > 0 {
                cpuUsage = Double(total - deltas[2]) / Double(total)
            }
        }
        previousTicks = ticks
        let memory: (used: UInt64, pressure: MemoryPressure) = Self.memory()
        let disk: URLResourceValues? = try? URL(filePath: "/").resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
            .volumeLocalizedNameKey
        ])
        let volume: SystemVolume.State = SystemVolume.state
        return .init(
            cpuUsage: min(max(cpuUsage, 0), 1),
            coreCount: ProcessInfo.processInfo.activeProcessorCount,
            memoryUsed: memory.used,
            memoryTotal: ProcessInfo.processInfo.physicalMemory,
            memoryPressure: memory.pressure,
            diskAvailable: disk?.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) },
            diskTotal: disk?.volumeTotalCapacity.map { UInt64(max(0, $0)) },
            diskName: disk?.volumeLocalizedName,
            battery: Self.battery(),
            thermalState: Self.thermalState,
            bootDate: Self.bootDate,
            outputVolume: volume.volume,
            isMuted: volume.isMuted,
            date: .now
        )
    }

    // MARK: - Processor

    private static func cpuTicks() -> [UInt32]? {
        var info: host_cpu_load_info = .init()
        var count: mach_msg_type_number_t = .init(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
    }

    // MARK: - Memory

    /// Memory used as Activity Monitor counts it: app memory, wired and compressed.
    private static func memory() -> (used: UInt64, pressure: MemoryPressure) {
        var statistics: vm_statistics64 = .init()
        var count: mach_msg_type_number_t = .init(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result: kern_return_t = withUnsafeMutablePointer(to: &statistics) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            let pages: UInt64 = UInt64(statistics.internal_page_count) - min(UInt64(statistics.internal_page_count), UInt64(statistics.purgeable_count))
                + UInt64(statistics.wire_count) + UInt64(statistics.compressor_page_count)
            var pageSize: vm_size_t = 0
            host_page_size(mach_host_self(), &pageSize)
            used = pages * UInt64(pageSize)
        }
        var level: Int32 = 0
        var size: Int = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        let pressure: MemoryPressure = switch level {
        case 4: .critical
        case 2: .warning
        default: .normal
        }
        return (used, pressure)
    }

    // MARK: - Battery

    private static func battery() -> MacBattery? {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                let capacity = description[kIOPSCurrentCapacityKey] as? Int
            else { continue }
            let maximum: Int = max(1, description[kIOPSMaxCapacityKey] as? Int ?? 100)
            let minutes: Int? = (description[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
            let isOnPower: Bool = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return .init(
                level: min(100, capacity * 100 / maximum),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isOnPower: isOnPower,
                minutesRemaining: isOnPower ? nil : minutes
            )
        }
        return nil
    }

    // MARK: - System

    private static var thermalState: MacThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }
    }

    /// Boot time (`kern.boottime`): the uptime of `ProcessInfo` stops while the Mac sleeps.
    private static var bootDate: Date {
        var bootTime: timeval = .init()
        var size: Int = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 else {
            return .now.addingTimeInterval(-ProcessInfo.processInfo.systemUptime)
        }
        return .init(timeIntervalSince1970: TimeInterval(bootTime.tv_sec) + TimeInterval(bootTime.tv_usec) / 1_000_000)
    }
}
