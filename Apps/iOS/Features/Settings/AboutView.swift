import SwiftUI

/// About Locky.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(.lockyGlyph)
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Locky")
                .font(.largeTitle.bold())
            Text("Version \(LocalDevice.appVersion)")
                .foregroundStyle(.secondary)
            Text("Locky locks your Mac when you walk away with your iPhone and unlocks it when you come back.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Link("lunabee.studio", destination: URL(string: "https://lunabee.studio")!)
            Spacer()
            Text("© Lunabee Studio")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
