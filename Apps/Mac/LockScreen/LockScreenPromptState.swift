import Observation

/// Shared by the wings and the button of the lock screen, so they leave together, animated.
@MainActor
@Observable
final class LockScreenPromptState {
    /// The session is being unlocked: the wings fold away, the button fades out.
    var isDismissed: Bool = false
}
