import LockyKit
import SwiftUI

/// Choice of the sound played when the Mac locks.
struct SoundThemePicker: View {
    @Binding var selection: SoundTheme
    @State private var player: SoundPlayer = .init()

    var body: some View {
        List(SoundTheme.allCases) { theme in
            Button {
                selection = theme
                player.play(theme)
            } label: {
                HStack {
                    Text(theme.localizedName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if theme == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Selected")
                    }
                }
            }
        }
        .navigationTitle("Lock sound")
    }
}
