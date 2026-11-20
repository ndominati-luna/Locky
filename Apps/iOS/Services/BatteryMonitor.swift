import Foundation
import UIKit

/// Follows the iPhone battery level (the Mac warns when it gets low).
@MainActor
final class BatteryMonitor {
    var onChange: ((Int) -> Void)?
    private var observation: (any NSObjectProtocol)?

    /// Battery level in percent, `nil` when unknown (simulator).
    var level: Int? {
        let level: Float = UIDevice.current.batteryLevel
        return level < 0 ? nil : Int((level * 100).rounded())
    }

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        observation = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let level = self.level else { return }
                self.onChange?(level)
            }
        }
    }
}
