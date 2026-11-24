import SwiftUI

/// Chooses between onboarding, pairing and the main interface.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if !model.preferences.onboardingCompleted {
                OnboardingView()
            } else if !model.session.isPaired {
                PairingView()
            } else if let setup = model.setup {
                FirstTryView(phase: setup)
            } else {
                MainView()
            }
        }
        .animation(.smooth, value: model.session.isPaired)
        .animation(.smooth, value: model.setup == nil)
        // A few shakes open the Mac lab, wherever the app is.
        .opensMacLabOnShake(model: model)
        #if DEBUG
        .task {
            // `-LockyDemoShakes 3`: shakes the simulator, which cannot be shaken from a script.
            for _ in 0..<DemoMode.shakes {
                try? await Task.sleep(for: .milliseconds(700))
                NotificationCenter.default.post(name: .lockyDeviceDidShake, object: nil)
            }
        }
        #endif
        .alert(
            "Locky",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}
