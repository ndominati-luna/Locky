import SwiftUI

/// Icon, title and explanation of a step.
struct StepHeader: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let animated: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .foregroundStyle(Color.brandArt)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: animated)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Color.primary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
