import SwiftUI

/// Primary button of the onboarding and pairing screens: Locky blue capsule in Light Mode, white
/// capsule in Dark Mode.
struct BrandCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.brandButtonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brandButton, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrandCapsuleButtonStyle {
    static var brandCapsule: BrandCapsuleButtonStyle { .init() }
}

/// Secondary button of the onboarding and pairing screens: outline capsule, one line.
struct BrandOutlineCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.brandArt)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(Capsule().strokeBorder(Color.brandArt.opacity(0.8), lineWidth: 1.5))
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrandOutlineCapsuleButtonStyle {
    static var brandOutlineCapsule: BrandOutlineCapsuleButtonStyle { .init() }
}
