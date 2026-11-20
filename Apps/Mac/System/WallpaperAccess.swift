import AppKit
import Foundation

/// Access to the wallpaper when its file sits in a folder macOS protects (Documents, Desktop,
/// Downloads, iCloud Drive, another disk). macOS points the wallpaper to the very file the user
/// picked and keeps no readable copy: reading it makes macOS ask for that folder. Locky does not
/// read it before explaining why, in the permissions step of the setup (or from its menu).
@MainActor
enum WallpaperAccess {
    enum Status: Equatable {
        /// A system wallpaper, or a file in a folder macOS does not protect (Pictures…).
        case notNeeded
        /// Protected, and Locky has not asked yet: it does not touch the file.
        case notAsked
        case granted
        case denied
    }

    private static let askedKey: String = "locky.wallpaperAccessAsked"

    private static var hasAsked: Bool {
        UserDefaults.standard.bool(forKey: askedKey)
    }

    /// For the wallpaper of the main screen.
    static var status: Status {
        guard let url = MacImageRenderer.wallpaperURL, isProtected(url) else { return .notNeeded }
        guard hasAsked else { return .notAsked }
        return FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false)) ? .granted : .denied
    }

    /// `false` while the file is in a protected folder Locky has not asked for yet.
    static func mayRead(_ url: URL) -> Bool {
        !isProtected(url) || hasAsked
    }

    /// Reads the wallpaper once, off the main thread: macOS shows its prompt the first time. After
    /// a refusal macOS never asks again, so this opens the Files and Folders settings instead.
    static func request() async -> Status {
        if status == .denied {
            openSettings()
            return .denied
        }
        UserDefaults.standard.set(true, forKey: askedKey)
        guard let url = MacImageRenderer.wallpaperURL else { return .notNeeded }
        await readOnce(url)
        return status
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Checked on the path alone: touching the file (even its attributes) would already make
    /// macOS ask.
    private static func isProtected(_ url: URL) -> Bool {
        let path: String = url.standardizedFileURL.path(percentEncoded: false)
        let home: String = URL.homeDirectory.path(percentEncoded: false).trimmingSuffix("/")
        let folders: [String] = ["Documents", "Desktop", "Downloads", "Library/Mobile Documents"]
        return folders.contains { path.hasPrefix("\(home)/\($0)/") } || path.hasPrefix("/Volumes/")
    }

    @concurrent
    private nonisolated static func readOnce(_ url: URL) async {
        if url.hasDirectoryPath {
            _ = try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))
        } else if let handle = try? FileHandle(forReadingFrom: url) {
            _ = try? handle.read(upToCount: 1)
            try? handle.close()
        }
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
