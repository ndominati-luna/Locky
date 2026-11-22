import SwiftUI

/// First launch presentation, in the spirit of the original Locky onboarding.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page: OnboardingPage = Self.initialPage

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(OnboardingPage.allCases) { page in
                        OnboardingPageView(page: page, isCurrent: page == self.page)
                            .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Under the text when unfolded, not across the fold.
                SecondPageOnly {
                    VStack(spacing: 0) {
                        PageDots(count: OnboardingPage.allCases.count, current: page.rawValue)
                            .padding(.bottom, 20)

                        Button(action: next) {
                            Text(page.isLast ? "Let's go!" : "Continue")
                        }
                        .buttonStyle(.brandCapsule)
                        .padding(.horizontal, 32)
                        .padding(.bottom)
                        .frame(maxWidth: 520)
                    }
                }
            }
        }
    }

    private static var initialPage: OnboardingPage {
        #if DEBUG
        OnboardingPage(rawValue: UserDefaults.standard.integer(forKey: "LockyDemoOnboardingPage")) ?? .welcome
        #else
        .welcome
        #endif
    }

    private func next() {
        if let next = page.next {
            withAnimation { page = next }
        } else {
            Task { await model.completeOnboarding() }
        }
    }
}

/// Pages of the onboarding.
enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome
    case walkAway
    case intruders
    case signal
    case macApp
    case permissions

    var id: Int { rawValue }

    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }

    var isLast: Bool {
        next == nil
    }
}

/// Content of one page: animated illustration, title, text.
private struct OnboardingPageView: View {
    @Environment(\.screenFold) private var fold
    let page: OnboardingPage
    let isCurrent: Bool

    var body: some View {
        StepLayout(columnPadding: .init(top: 48, leading: 32, bottom: 0, trailing: 32)) {
            Group {
                if isCurrent {
                    illustration
                } else {
                    Color.clear
                }
            }
            .frame(height: fold == nil ? 220 : 280)
            .frame(maxWidth: 320)
        } details: {
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.primary)

            if page == .macApp {
                VStack(spacing: 12) {
                    ShareLink(item: MacAppLink.download) {
                        Label("Get the link for Mac", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.brandOutlineCapsule)
                    MacAppHandoffHint()
                }
            }
        }
        .handsOffMacAppLink(isActive: page == .macApp && isCurrent)
    }

    @ViewBuilder
    private var illustration: some View {
        switch page {
        case .welcome: LockyAssemblyIllustration()
        case .walkAway: WalkAwayIllustration()
        case .intruders: IntruderIllustration()
        case .signal: SignalIllustration()
        case .macApp: MacDownloadIllustration()
        case .permissions: MagicIllustration()
        }
    }

    private var title: LocalizedStringKey {
        switch page {
        case .welcome: "Welcome"
        case .walkAway: "Walk away, it locks"
        case .intruders: "Intruders detection"
        case .signal: "Keep that in mind"
        case .macApp: "Locky on your Mac"
        case .permissions: "The magic will happen soon"
        }
    }

    private var message: LocalizedStringKey {
        switch page {
        case .welcome:
            "Locky locks your Mac when you walk away with your iPhone and unlocks it when you come back."
        case .walkAway:
            "Come back, it unlocks. Locky watches whether your iPhone moves, so your Mac never locks while you sit at your desk."
        case .intruders:
            "When you're away with your iPhone, Locky can send you a photo of the intruder when activity is detected on your Mac."
        case .signal:
            "Your body and clothes reduce the signal strength, and therefore impact the calculated distance between your Mac and iPhone. You can adjust the lock distance at any time."
        case .macApp:
            "Now, download Locky for your Mac."
        case .permissions:
            "To work properly, Locky needs permissions to use Bluetooth and notifications. Your Mac password stays in the keychain of your iPhone and only travels end-to-end encrypted to your Mac."
        }
    }
}
