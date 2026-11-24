import ActivityKit
import Foundation
import LockyKit
import OSLog

/// Runs the Locky Live Activity.
///
/// iOS only lets an app start a Live Activity from the foreground, and ends it after 8 hours: it is
/// started (or started again) each time Locky is opened, then updated from the background, where
/// the Bluetooth link keeps the app awake. Distance updates are rounded and spaced out, and left
/// out while the distance only wavers (the signal always does): every update redraws the lock
/// screen.
@MainActor
final class LiveActivityManager {
    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "LiveActivity")
    private var activity: Activity<LockyActivityAttributes>?
    private var sentState: LockyActivityAttributes.ContentState?
    private var pendingState: LockyActivityAttributes.ContentState?
    private var lastUpdate: ContinuousClock.Instant?
    private var pendingUpdate: Task<Void, Never>?

    /// Shortest delay between two updates that only move the distance, and the least change shown.
    private static let distanceUpdateInterval: Duration = .seconds(5)
    private static let distanceStep: Double = 0.3

    /// Live Activities are allowed for Locky (Settings > Locky).
    var isAllowed: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// An activity is on screen (this one or one started before a relaunch of the app).
    var isRunning: Bool {
        adoptRunningActivity()
        return activity != nil
    }

    /// Takes over the activity started by a previous launch: Bluetooth may relaunch Locky in the
    /// background, where a new activity cannot be started but the running one can be updated.
    @discardableResult
    private func adoptRunningActivity() -> Bool {
        if let activity, activity.activityState == .active { return true }
        activity = Activity<LockyActivityAttributes>.activities.first { $0.activityState == .active }
        if activity == nil {
            sentState = nil
        }
        return activity != nil
    }

    /// Starts the activity, or takes over the one already running (relaunch). Call it from the
    /// foreground.
    func start(attributes: LockyActivityAttributes, state: LockyActivityAttributes.ContentState) {
        let running: [Activity<LockyActivityAttributes>] = Activity<LockyActivityAttributes>.activities
        if let current = running.first(where: { $0.activityState == .active }), current.attributes.macName == attributes.macName,
           current.attributes.family == attributes.family {
            activity = current
            update(state)
            return
        }
        // Another Mac (or renamed), or ended by the system: start again.
        running.forEach { finish($0) }
        activity = nil
        guard isAllowed else { return }
        let rounded: LockyActivityAttributes.ContentState = Self.rounded(state)
        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: rounded, staleDate: nil), pushType: nil)
            sentState = rounded
            lastUpdate = .now
        } catch {
            logger.notice("Live Activity request failed: \(error.localizedDescription)")
        }
    }

    /// Updates the activity: right away for a new state, at most every 5 seconds for the distance.
    func update(_ state: LockyActivityAttributes.ContentState) {
        guard adoptRunningActivity() else { return }
        let rounded: LockyActivityAttributes.ContentState = Self.rounded(state)
        guard rounded != sentState else {
            pendingState = nil
            return
        }
        var withoutDistance: LockyActivityAttributes.ContentState = rounded
        withoutDistance.distance = sentState?.distance
        let onlyDistance: Bool = withoutDistance == sentState
        // The distance wavers by a few tens of centimetres: shown again once it really moved.
        if onlyDistance, let sent = sentState?.distance, let distance = rounded.distance, abs(distance - sent) < Self.distanceStep {
            pendingState = nil
            return
        }
        if onlyDistance, let lastUpdate, ContinuousClock.now - lastUpdate < Self.distanceUpdateInterval {
            pendingState = rounded
            guard pendingUpdate == nil else { return }
            pendingUpdate = Task { [weak self] in
                try? await Task.sleep(for: Self.distanceUpdateInterval)
                guard let self else { return }
                self.pendingUpdate = nil
                if let pending = self.pendingState {
                    self.pendingState = nil
                    self.send(pending)
                }
            }
            return
        }
        pendingState = nil
        send(rounded)
    }

    /// Ends the activity (setting turned off, unpairing).
    func end() {
        pendingUpdate?.cancel()
        pendingUpdate = nil
        Activity<LockyActivityAttributes>.activities.forEach { finish($0) }
        activity = nil
        sentState = nil
    }

    /// Ends every activity before Locky is closed by the user: iOS gives a few seconds at most, so
    /// it waits here (up to 2 seconds) for ActivityKit to have ended them.
    func endBeforeTermination() {
        pendingUpdate?.cancel()
        pendingUpdate = nil
        activity = nil
        sentState = nil
        let running: [Activity<LockyActivityAttributes>] = Activity<LockyActivityAttributes>.activities
        guard !running.isEmpty else { return }
        nonisolated(unsafe) let targets: [Activity<LockyActivityAttributes>] = running
        let done: DispatchSemaphore = .init(value: 0)
        Task.detached {
            for target in targets {
                await target.end(nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        if done.wait(timeout: .now() + 2) == .timedOut {
            logger.notice("Live Activity not ended before termination")
        }
    }

    private func send(_ state: LockyActivityAttributes.ContentState) {
        guard let activity else { return }
        sentState = state
        lastUpdate = .now
        // `Activity` synchronizes itself but is not marked `Sendable`.
        nonisolated(unsafe) let target: Activity<LockyActivityAttributes> = activity
        Task {
            await target.update(.init(state: state, staleDate: nil))
        }
    }

    private func finish(_ activity: Activity<LockyActivityAttributes>) {
        nonisolated(unsafe) let target: Activity<LockyActivityAttributes> = activity
        Task {
            await target.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Distances to the decimeter: closer readings would update the activity for nothing.
    private static func rounded(_ state: LockyActivityAttributes.ContentState) -> LockyActivityAttributes.ContentState {
        var state: LockyActivityAttributes.ContentState = state
        state.distance = state.distance.map { ($0 * 10).rounded() / 10 }
        return state
    }
}
