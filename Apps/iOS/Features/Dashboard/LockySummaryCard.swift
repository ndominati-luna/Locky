import LockyKit
import SwiftUI

/// Locky itself: automatic locking, unlocks, break-in reports.
struct LockySummaryCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DashboardCard(title: "Locky", icon: Image(.lockyGlyph)) {
            VStack(spacing: 12) {
                SummaryRow(
                    systemImage: "figure.walk.departure",
                    title: "Automatic locking",
                    value: model.macStatus?.isAutoLockEnabled == false ? String(localized: "Paused") : String(localized: "On")
                )
                if let count = model.macStatus?.unlockCount, count > 0 {
                    SummaryRow(
                        systemImage: "lock.open",
                        title: "Unlocks by Locky",
                        value: count.formatted()
                    )
                }
                NavigationLink(value: AppRoute.intrusions) {
                    SummaryRow(
                        systemImage: "person.crop.badge.magnifyingglass",
                        title: "Break-in reports",
                        value: intrusionsValue,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var intrusionsValue: String {
        guard let latest = model.intrusions.reports.map(\.date).max() else { return String(localized: "None") }
        return latest.formatted(.relative(presentation: .named))
    }
}

/// A line of the Locky card.
private struct SummaryRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let value: String
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(Color.primary)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.subheadline)
        .contentShape(.rect)
    }
}
