import SwiftUI

/// Sends a new session password to the iPhone after a password change.
struct UpdatePasswordView: View {
    @Environment(MacAppModel.self) private var model
    @Environment(\.closeWindow) private var closeWindow
    @State private var password: String = ""
    @State private var state: UpdateState = .editing

    private enum UpdateState {
        case editing
        case verifying
        case wrongPassword
        case notConnected
        case done
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.horizontal")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Update session password")
                .font(.title2.bold())
            Text("If you changed the password of your macOS session, type the new one: Locky checks it and sends it to the keychain of \(model.phoneName).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("New password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            switch state {
            case .wrongPassword:
                Text("This password is not the one of your session.")
                    .foregroundStyle(.red)
            case .notConnected:
                Text("Your iPhone must be connected.")
                    .foregroundStyle(.red)
            case .done:
                Label("Password updated", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .editing, .verifying:
                EmptyView()
            }
            HStack {
                Button("Close") { closeWindow() }
                Button("Update", action: submit)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || state == .verifying)
            }
        }
        .padding(28)
        .frame(width: 420)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        guard model.session.connection.isConnected else {
            state = .notConnected
            return
        }
        state = .verifying
        Task {
            let success: Bool = await model.updatePassword(password)
            state = success ? .done : .wrongPassword
            if success {
                password = ""
            }
        }
    }
}
