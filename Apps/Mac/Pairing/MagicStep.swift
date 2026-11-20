import SwiftUI

/// The first try worked: Locky locked the Mac, then unlocked it when the user came back.
struct MagicStep: View {
    @Environment(MacAppModel.self) private var model
    @State private var isRevealed: Bool = false

    var body: some View {
        ZStack {
            SparklesView()
                .frame(width: 260, height: 160)
            Image(.lockyGlyph)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.brandArt)
                .frame(height: 96)
                .scaleEffect(isRevealed ? 1 : 0.4)
                .opacity(isRevealed ? 1 : 0)
                .accessibilityHidden(true)
        }
        Text("The magic happened!")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.primary)
        Text("Locky locked your Mac when you walked away and unlocked it when you came back. From now on, it watches over your Mac from the menu bar.")
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Button("Done", action: model.finishSetup)
            .buttonStyle(.brandCapsule)
            .frame(width: 200)
            .keyboardShortcut(.defaultAction)
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.45).delay(0.2)) {
                    isRevealed = true
                }
            }
    }
}
