import SwiftUI

/// Closes the AppKit window hosting a SwiftUI view.
struct CloseWindowAction: Sendable {
    let action: @MainActor @Sendable () -> Void

    @MainActor
    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    @Entry var closeWindow: CloseWindowAction = .init(action: {})
}
