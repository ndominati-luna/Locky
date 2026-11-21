import SafariServices
import SwiftUI

/// A site opened in Safari inside the app, once per tap.
struct OpenedSite: Identifiable, Equatable {
    let id: UUID = .init()
    let url: URL
}

extension View {
    /// Presents `site` in Safari inside the app (reader, sharing, opening in Safari) from this view,
    /// even inside a sheet: `openURL(_:prefersInApp:)` presents from the window, which fails while
    /// a sheet is up, and Safari inside a SwiftUI sheet closes the whole stack.
    func safari(_ site: Binding<OpenedSite?>) -> some View {
        background {
            SafariPresenter(site: site)
                .accessibilityHidden(true)
        }
    }
}

/// An empty controller that presents Safari above the controller of its view.
private struct SafariPresenter: UIViewControllerRepresentable {
    @Binding var site: OpenedSite?

    func makeUIViewController(context: Context) -> UIViewController {
        .init()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.onDone = { site = nil }
        guard let site, site.id != context.coordinator.presentedID else { return }
        context.coordinator.presentedID = site.id
        let safari: SFSafariViewController = .init(url: site.url)
        safari.delegate = context.coordinator
        safari.dismissButtonStyle = .close
        controller.present(safari, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        .init()
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor SFSafariViewControllerDelegate {
        var presentedID: UUID?
        var onDone: () -> Void = {}

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            presentedID = nil
            onDone()
        }
    }
}
