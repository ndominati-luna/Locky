import LockyKit
import SwiftUI

/// Intruder detection is on but the Mac cannot photograph intruders: why, and a button that has
/// the Mac ask for its camera (or open System Settings on Camera after a refusal).
struct MacCameraWarning: View {
    @Environment(AppModel.self) private var model
    @State private var hasAsked: Bool = false

    var body: some View {
        if let access = model.missingMacCameraAccess {
            Label {
                // The button lines up with the text, under it.
                VStack(alignment: .leading, spacing: 10) {
                    Text(message(for: access))
                        .font(.subheadline)
                    if access != .unavailable {
                        CameraRequestButton(access: access, hasAsked: $hasAsked)
                    }
                }
                .padding(.vertical, 4)
            } icon: {
                Image(systemName: access == .unavailable ? "info.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(access == .unavailable ? Color.secondary : Color.orange)
            }
            .animation(.smooth, value: hasAsked)
        }
    }

    private func message(for access: CameraAccess) -> LocalizedStringKey {
        switch access {
        case .denied: "Locky is not allowed to use the camera of your Mac: intruders won't be photographed."
        case .notDetermined: "Your Mac has not let Locky use its camera yet: intruders won't be photographed."
        case .unavailable, .authorized: "Your Mac has no camera: break-in attempts will be reported without a photo."
        }
    }
}

/// "Allow on my Mac", then what to do on the Mac.
private struct CameraRequestButton: View {
    @Environment(AppModel.self) private var model
    let access: CameraAccess
    @Binding var hasAsked: Bool

    var body: some View {
        if hasAsked {
            Text(model.lockState == .locked ? "Unlock your Mac to continue there." : "Continue on your Mac.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            Button(access == .denied ? "Allow on my Mac" : "Ask on my Mac") {
                hasAsked = true
                model.allowMacCamera()
            }
            .buttonStyle(.glass)
            .disabled(!model.isConnected)
            if !model.isConnected {
                Text("Your Mac must be connected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
