import SwiftUI
import UIKit

extension Notification.Name {
    /// The iPhone was shaken, the app in the foreground.
    static let lockyDeviceDidShake: Notification.Name = .init("LockyDeviceDidShake")
}

extension UIWindow {
    /// Shakes reach the window when nothing else handled them: told to the app, for the Mac lab.
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .lockyDeviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension View {
    /// Opens the Mac lab when the iPhone is shaken (``MacLabPresenter``).
    func opensMacLabOnShake(model: AppModel) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .lockyDeviceDidShake)) { _ in
            MacLabPresenter.shared.deviceShook(model: model)
        }
    }
}
