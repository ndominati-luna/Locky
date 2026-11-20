import LockyKit
import WidgetKit

/// State displayed by the widgets.
struct MacStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: LockySnapshot
    /// The Mac with its wallpaper on screen, made by the app (``SharedStore/Rendition/widgetDevice``).
    let deviceImage: Data?
    let deviceScreen: NormalizedRect?
    let wallpaper: Data?
    let userPicture: Data?

    static let preview: MacStatusEntry = .init(
        date: .now,
        snapshot: .preview,
        deviceImage: nil,
        deviceScreen: nil,
        wallpaper: nil,
        userPicture: nil
    )
}
