import LockyKit
import SwiftUI

/// "Your Mac" page while the Mac cannot be reached: one centered explanation instead of empty
/// cards, and the break-in reports, which come through iCloud.
struct MacUnreachableView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: connection == .searching)
        } description: {
            Text(message)
        } actions: {
            NavigationLink(value: AppRoute.intrusions) {
                Label(intrusionsTitle, systemImage: "person.crop.badge.magnifyingglass")
            }
            .buttonStyle(.glass)
        }
    }

    private var connection: ConnectionState {
        model.session.connection
    }

    private var symbol: String {
        switch connection {
        case .connecting: "lock.shield"
        case .bluetoothOff, .unauthorized, .unsupported: "exclamationmark.triangle"
        case .searching, .connected: "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var title: LocalizedStringKey {
        switch connection {
        case .connecting: "Securing the connection…"
        case .bluetoothOff: "Bluetooth is off"
        case .unauthorized: "Bluetooth not allowed"
        case .unsupported: "Bluetooth unavailable"
        case .searching, .connected: "Your Mac is out of reach"
        }
    }

    private var message: LocalizedStringKey {
        switch connection {
        case .connecting: "Your iPhone and your Mac are checking each other."
        case .bluetoothOff: "Turn on Bluetooth so Locky can reach your Mac."
        case .unauthorized, .unsupported: "Locky needs Bluetooth access to reach your Mac."
        case .searching, .connected: "Make sure Locky is running on your Mac and Bluetooth is on."
        }
    }

    private var intrusionsTitle: String {
        let count: Int = model.intrusions.unseenCount
        let title: String = .init(localized: "Break-in reports")
        return count > 0 ? "\(title) (\(count))" : title
    }
}
