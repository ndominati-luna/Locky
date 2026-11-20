import SwiftUI

/// "12 min ago", refreshed by the system every minute (no seconds ticking by).
struct SinceText: View {
    let date: Date

    var body: some View {
        Text(.currentDate, format: .reference(to: date, allowedFields: [.day, .hour, .minute], maxFieldCount: 1))
            .monospacedDigit()
    }
}
