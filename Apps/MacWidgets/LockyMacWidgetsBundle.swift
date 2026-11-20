import SwiftUI
import WidgetKit

@main
struct LockyMacWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PhoneStatusWidget()
        LockyActivatedControl()
        LockMacNowControl()
    }
}
