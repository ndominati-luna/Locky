import LockyKit
import WidgetKit

/// Reads the state the iPhone app shares through the App Group. The app reloads the timelines on
/// every change, so a single entry is enough.
struct MacStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacStatusEntry {
        galleryEntry()
    }

    /// The widget gallery shows the paired Mac as it will look once added (sample data before
    /// pairing).
    func getSnapshot(in context: Context, completion: @escaping (MacStatusEntry) -> Void) {
        completion(context.isPreview ? galleryEntry() : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacStatusEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func galleryEntry() -> MacStatusEntry {
        let entry: MacStatusEntry = currentEntry()
        return entry.snapshot.isPaired ? entry : .preview
    }

    private func currentEntry() -> MacStatusEntry {
        .init(
            date: .now,
            snapshot: SharedStore.snapshot(),
            // Made by the app: the extension does not embed the catalog of the Macs.
            deviceImage: SharedStore.rendition(.widgetDevice),
            deviceScreen: SharedStore.deviceScreen,
            wallpaper: SharedStore.rendition(.widgetWallpaper),
            userPicture: SharedStore.rendition(.userPicture)
        )
    }
}
