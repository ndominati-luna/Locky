import AppKit
import LockyKit
import WidgetKit

/// Publishes the state to the desktop widget and the controls, and runs the commands they queue.
@MainActor
final class MacWidgetBridge {
    var onCommand: ((MacCommand) -> Void)?

    private var observer: DarwinNotificationObserver?
    private var lastState: MacWidgetState?
    private var lastReload: ContinuousClock.Instant?
    private var lastPhoneModel: String?

    func start() {
        MacCommandRouter.handler = { [weak self] command in self?.onCommand?(command) }
        observer = DarwinNotificationObserver(name: MacSharedStore.commandNotificationName) { [weak self] in
            Task { @MainActor in self?.drainCommands() }
        }
        drainCommands()
    }

    /// Runs the commands queued while the app was not listening.
    func drainCommands() {
        for command in MacSharedStore.drainCommands() {
            onCommand?(command)
        }
    }

    /// Saves the state and reloads the widget and the controls when something visible changed.
    /// Distance only changes are throttled: WidgetKit has a reload budget.
    func publish(_ state: MacWidgetState, phoneModelIdentifier: String?) {
        if phoneModelIdentifier != lastPhoneModel {
            lastPhoneModel = phoneModelIdentifier
            MacSharedStore.phoneImage = phoneModelIdentifier.flatMap(Self.phonePNG(modelIdentifier:))
            lastState = nil
        }
        var comparable: MacWidgetState = state
        comparable.updatedAt = lastState?.updatedAt ?? state.updatedAt
        guard comparable != lastState else { return }
        if var previous = lastState {
            previous.distance = state.distance
            previous.updatedAt = state.updatedAt
            let onlyDistanceChanged: Bool = previous == state
            if onlyDistanceChanged, let lastReload, ContinuousClock.now - lastReload < .seconds(20) { return }
        }
        lastState = state
        MacSharedStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        lastReload = .now
    }

    private static func phonePNG(modelIdentifier: String) -> Data? {
        guard let image = MacImageRenderer.phoneImage(modelIdentifier: modelIdentifier) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
