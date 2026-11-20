import SwiftUI

/// Background of the onboarding and pairing screens (iPhone and Mac): white to pale Locky blue in Light Mode, deep
/// night blue in Dark Mode.
struct BrandBackground: View {
    var body: some View {
        LinearGradient(colors: [.brandBackgroundTop, .brandBackgroundBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
