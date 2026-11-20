import SwiftUI
import WidgetKit

@main
struct LockyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MacStatusWidget()
        MacLockToggleControl()
        LockMacControl()
        LockyLiveActivity()
    }
}
