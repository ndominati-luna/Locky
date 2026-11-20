import LockyKit
import SwiftUI

/// Processor, memory, storage and battery (or temperature on Macs without battery).
struct MacMetricsGrid: View {
    let metrics: MacMetrics

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
            MetricCard(
                title: "Processor",
                gauge: metrics.cpuUsage,
                tint: loadColor(metrics.cpuUsage),
                systemImage: "cpu",
                value: metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0))),
                detail: String(localized: "\(metrics.coreCount) cores")
            )
            MetricCard(
                title: "Memory",
                gauge: metrics.memoryUsage,
                tint: pressureColor,
                systemImage: "memorychip",
                value: ByteFormat.memory(metrics.memoryUsed),
                detail: memoryDetail
            )
            if let usage = metrics.diskUsage, let available = metrics.diskAvailable, let total = metrics.diskTotal {
                MetricCard(
                    title: "Storage",
                    gauge: usage,
                    tint: usage > 0.9 ? .red : .cyan,
                    systemImage: "internaldrive",
                    value: ByteFormat.storage(available),
                    detail: String(localized: "available of \(ByteFormat.storage(total))")
                )
            }
            if let battery = metrics.battery {
                MetricCard(
                    title: "Battery",
                    gauge: Double(battery.level) / 100,
                    tint: battery.isCharging || battery.level > 20 ? .green : .red,
                    systemImage: battery.isCharging ? "bolt.fill" : battery.isOnPower ? "powerplug.fill" : "battery.75percent",
                    value: (Double(battery.level) / 100).formatted(.percent.precision(.fractionLength(0))),
                    detail: batteryDetail(battery)
                )
            } else {
                MetricCard(
                    title: "Temperature",
                    gauge: thermalGauge,
                    tint: thermalColor,
                    systemImage: "thermometer.medium",
                    value: thermalName,
                    detail: String(localized: "Thermal state of your Mac")
                )
            }
        }
    }

    private func loadColor(_ load: Double) -> Color {
        load > 0.85 ? .red : load > 0.6 ? .orange : .green
    }

    private var pressureColor: Color {
        switch metrics.memoryPressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    private var memoryDetail: String {
        let total: String = ByteFormat.memory(metrics.memoryTotal)
        switch metrics.memoryPressure {
        case .normal: return String(localized: "of \(total)")
        case .warning: return String(localized: "of \(total), under pressure")
        case .critical: return String(localized: "of \(total), saturated")
        }
    }

    private func batteryDetail(_ battery: MacBattery) -> String {
        if battery.isCharging {
            return String(localized: "Charging")
        }
        if battery.isOnPower {
            return String(localized: "On power adapter")
        }
        guard let minutes = battery.minutesRemaining else { return String(localized: "On battery") }
        let remaining: String = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return String(localized: "\(remaining) left")
    }

    private var thermalGauge: Double {
        switch metrics.thermalState {
        case .nominal: 0.25
        case .fair: 0.5
        case .serious: 0.75
        case .critical: 1
        }
    }

    private var thermalColor: Color {
        switch metrics.thermalState {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }

    private var thermalName: String {
        switch metrics.thermalState {
        case .nominal: String(localized: "Normal")
        case .fair: String(localized: "Warm")
        case .serious: String(localized: "Hot")
        case .critical: String(localized: "Critical")
        }
    }
}
