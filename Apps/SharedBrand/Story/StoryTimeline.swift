import SwiftUI

/// The life of Locky from 2014 to its rebirth, as a line of dots.
struct StoryTimeline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("From 2014 to today")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(StoryMilestone.all) { milestone in
                    MilestoneRow(milestone: milestone, isLast: milestone.id == StoryMilestone.all.last?.id)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

/// A dot on the line, its date and what happened.
private struct MilestoneRow: View {
    let milestone: StoryMilestone
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 2)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Group {
                    if let date = milestone.date {
                        Text(date, format: .dateTime.month(.wide).year())
                    } else {
                        Text(verbatim: String(milestone.year))
                    }
                }
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
                Text(milestone.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 16)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
