import SwiftUI

/// Switch drawn by Locky for its status menu.
///
/// Controls hosted in a menu are rendered with the inactive window appearance, so the system switch
/// stays grey even when on. This one always shows the vivid accent color when on.
struct MenuSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                    .frame(width: 32, height: 19)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                            .padding(2)
                    }
                    .animation(.snappy(duration: 0.2), value: configuration.isOn)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
