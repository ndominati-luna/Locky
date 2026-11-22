import SwiftUI

/// Under the button that shares the link of the Mac app: the Mac offers it too, through Handoff.
struct MacAppHandoffHint: View {
    var body: some View {
        Text("Your Mac also offers it in its Dock, thanks to Handoff.")
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)
    }
}
