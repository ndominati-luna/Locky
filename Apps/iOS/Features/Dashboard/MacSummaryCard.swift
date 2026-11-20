import LockyKit
import SwiftUI

/// The Mac: model, macOS version, time since it started, heat when it matters.
struct MacSummaryCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DashboardCard(title: "Your Mac", icon: Image(systemName: (model.macStatus?.family ?? .unknown).systemImage)) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.macStatus?.productName ?? model.macName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    if let version = model.macStatus?.systemVersion {
                        Text("macOS \(version)")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
                Spacer(minLength: 12)
                if let metrics = model.macMetrics {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text((metrics.bootDate..<max(metrics.bootDate, metrics.date)).formatted(.components(style: .condensedAbbreviated, fields: [.day, .hour, .minute])))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                        Text("since startup")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            if let metrics = model.macMetrics, metrics.battery != nil, metrics.thermalState != .nominal {
                Label("Your Mac is running hot", systemImage: "thermometer.high")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }
}
