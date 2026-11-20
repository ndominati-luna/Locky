import Foundation
import LockyKit

/// Streams the state of the Mac to the dashboard of the iPhone (unfolded iPhone Duo), only while
/// it is on screen: metrics every 2 seconds over Bluetooth (a few bytes), what is playing through
/// iCloud when it changes (track and artwork), the iPhone being told over Bluetooth to fetch it.
@MainActor
final class DashboardStreamer {
    /// Sends a message to the iPhone; `false` when the session is closed.
    var send: ((LockyMessage) -> Bool)?
    /// Publishes what is playing in iCloud with its revision; `false` when it failed.
    var publishNowPlaying: ((_ playing: NowPlaying?, _ revision: String) async -> Bool)?

    private var sampler: MacMetricsSampler = .init()
    private let player: NowPlayingReader = .init()
    private var loop: Task<Void, Never>?
    /// Last state published in iCloud (`.some(nil)`: nothing playing).
    private var publishedNowPlaying: NowPlaying??
    /// Publication in progress, and the state to publish once it is done.
    private var isPublishing: Bool = false
    private var pendingNowPlaying: NowPlaying??

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Runs a command from the dashboard, then reports its effect right away.
    func perform(_ command: MediaCommand) {
        player.perform(command)
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await refresh()
        }
    }

    #if DEBUG
    /// Demo: prints the messages instead of sending them (`-LockyDemoDashboardLog YES`).
    func startLogging() {
        let encoder: JSONEncoder = .init()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        // Unbuffered: the demo is usually stopped with a signal.
        let print: (String) -> Void = { FileHandle.standardOutput.write(Data(($0 + "\n").utf8)) }
        send = { message in
            print((try? encoder.encode(message)).flatMap { String(data: $0, encoding: .utf8) } ?? "?")
            return true
        }
        publishNowPlaying = { playing, revision in
            let track: String = (try? encoder.encode(playing)).flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            print("iCloud now playing \(revision) (artwork \(playing?.artwork?.count ?? 0) bytes): \(track)")
            return true
        }
        start()
    }
    #endif

    private func start() {
        stop()
        // The iPhone just opened its dashboard: publish again what is playing.
        publishedNowPlaying = nil
        // Primes the processor load, computed between two samples.
        _ = sampler.sample()
        loop = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refresh() async {
        guard let send, send(.macMetrics(sampler.sample())) else { return }
        let playing: NowPlaying? = await player.current()
        if let publishedNowPlaying {
            switch (publishedNowPlaying, playing) {
            case (nil, nil): return
            case let (published?, current?) where published.isSameState(as: current): return
            default: break
            }
        }
        publish(playing)
    }

    /// Publishes what is playing in iCloud, then tells the iPhone to fetch it. One publication at a
    /// time, the latest state winning.
    private func publish(_ playing: NowPlaying?) {
        guard !isPublishing else {
            pendingNowPlaying = .some(playing)
            return
        }
        guard let publishNowPlaying else { return }
        isPublishing = true
        publishedNowPlaying = .some(playing)
        let revision: String = UUID().uuidString
        Task {
            let published: Bool = await publishNowPlaying(playing, revision)
            isPublishing = false
            if published {
                _ = send?(.nowPlayingChanged(revision: revision))
            } else {
                // Try again at the next refresh.
                publishedNowPlaying = nil
            }
            if let pending = pendingNowPlaying {
                pendingNowPlaying = nil
                publish(pending)
            }
        }
    }
}
