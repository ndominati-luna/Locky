import SwiftUI

/// Imitation of the macOS lock screen drawn in the screen of the Mac image, like the original
/// Locky: the screen darkens, the round user picture, the user name and an empty password field
/// appear in its middle. While Locky unlocks the Mac, dots are typed in the field one by one.
/// A veil (rather than a new picture) keeps the notch and the screen corners intact.
struct MacLockScreenView: View {
    let userPicture: Data?
    let userName: String?
    /// Locky is typing the password on the Mac.
    var isUnlocking: Bool = false
    @State private var size: CGSize = .zero
    @State private var typedCount: Int = 0

    var body: some View {
        Color.black.opacity(0.55)
            .overlay {
                VStack(spacing: size.height * 0.035) {
                    avatar
                        .frame(width: size.height * 0.24, height: size.height * 0.24)
                        .clipShape(.circle)
                        .shadow(color: .black.opacity(0.3), radius: size.height * 0.02)
                    if let userName, size.height > 70 {
                        Text(userName)
                            .font(.system(size: max(6, size.height * 0.06), weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    PasswordField(height: size.height * 0.09, typedCount: typedCount)
                        .frame(width: size.width * 0.3, height: size.height * 0.09)
                }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .task(id: isUnlocking) {
                guard isUnlocking else {
                    typedCount = 0
                    return
                }
                // Typed like on a keyboard, slightly irregular.
                for count in 1...PasswordField.maximumDots {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 35...70)))
                    guard !Task.isCancelled else { return }
                    typedCount = count
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = userPicture.flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.9), .white.opacity(0.25))
        }
    }
}

/// The password field of the lock screen, empty until Locky types in it.
private struct PasswordField: View {
    static let maximumDots: Int = 9

    let height: CGFloat
    let typedCount: Int

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.22))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: max(0.5, height * 0.04)))
            .overlay(alignment: .leading) {
                HStack(spacing: height * 0.18) {
                    ForEach(0..<typedCount, id: \.self) { _ in
                        Circle()
                            .fill(.white)
                            .frame(width: height * 0.22, height: height * 0.22)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.leading, height * 0.5)
                .animation(.easeOut(duration: 0.08), value: typedCount)
            }
    }
}
