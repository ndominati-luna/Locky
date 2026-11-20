import Foundation

/// Tells, as soon as macOS records it, that the wallpaper may have changed.
///
/// There is no public notification for it, but the wallpaper agent writes every change to
/// `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` (what the former Locky
/// watched). The file may be replaced rather than rewritten, so its folder is watched too, and the
/// file is opened again whenever it is replaced.
@MainActor
final class WallpaperWatcher {
    /// Called right after a write of the store, then every quarter of a second for a few seconds:
    /// the caller compares the wallpaper itself (cheap) and acts once it changed.
    var onChange: (() -> Void)?

    private static let storeURL: URL = .homeDirectory
        .appending(path: "Library/Application Support/com.apple.wallpaper/Store", directoryHint: .isDirectory)
    private static let indexURL: URL = storeURL.appending(path: "Index.plist", directoryHint: .notDirectory)
    /// AppKit reports the new wallpaper a moment after the agent writes its store, up to a few
    /// seconds when it is chosen in System Settings (measured on macOS 27.2): look at once, then
    /// often, rather than after a fixed delay, so the iPhone gets it as soon as possible.
    private static let checkInterval: Duration = .milliseconds(250)
    private static let checkWindow: Duration = .seconds(5)

    private var folderSource: (any DispatchSourceFileSystemObject)?
    private var indexSource: (any DispatchSourceFileSystemObject)?
    private var settleTask: Task<Void, Never>?

    /// Starts watching. `false` when the store of the wallpaper agent is not where expected (another
    /// macOS version): the caller then has to check by itself from time to time.
    @discardableResult
    func start() -> Bool {
        guard folderSource == nil else { return true }
        guard let folder = makeSource(for: Self.storeURL, events: .write, isFolder: true) else { return false }
        folderSource = folder
        watchIndex()
        return true
    }

    func stop() {
        folderSource?.cancel()
        folderSource = nil
        indexSource?.cancel()
        indexSource = nil
        settleTask?.cancel()
        settleTask = nil
    }

    private func watchIndex() {
        indexSource?.cancel()
        indexSource = makeSource(for: Self.indexURL, events: [.write, .extend, .delete, .rename], isFolder: false)
    }

    /// A file system event source delivered on the main queue (the only queue it uses).
    private func makeSource(for url: URL, events: DispatchSource.FileSystemEvent, isFolder: Bool) -> (any DispatchSourceFileSystemObject)? {
        let descriptor: Int32 = open(url.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source: any DispatchSourceFileSystemObject = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: events,
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            let received: DispatchSource.FileSystemEvent = source?.data ?? []
            MainActor.assumeIsolated {
                self?.changed(isFolder: isFolder, events: received)
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        return source
    }

    private func changed(isFolder: Bool, events: DispatchSource.FileSystemEvent) {
        // A new file in the folder, or the index replaced: watch the current index file.
        if isFolder || !events.isDisjoint(with: [.delete, .rename]) {
            watchIndex()
        }
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            let end: ContinuousClock.Instant = .now + Self.checkWindow
            while !Task.isCancelled, ContinuousClock.now < end {
                self?.onChange?()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }
}
