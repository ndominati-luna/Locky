import LockyKit
import SwiftUI

/// Guided first try: the user walks away with the iPhone until the Mac locks, then comes back and
/// Locky unlocks it. The iPhone shows the same instructions.
struct FirstTryStep: View {
    @Environment(MacAppModel.self) private var model

    var body: some View {
        let lockDistance: Double = model.preferences.phonePreferences.lockDistance
        StepHeader(
            symbol: "figure.walk.departure",
            title: "Walk away from your Mac",
            message: "Take your iPhone with you. Beyond \(Measurement(value: lockDistance, unit: UnitLength.meters), format: .lockyDistance), Locky locks your Mac. Then come back: Locky unlocks it.",
            animated: false
        )
        WalkAwayTrack(
            distance: model.session.connection.isConnected ? model.proximity?.distance : nil,
            lockDistance: lockDistance,
            phoneImage: model.phoneImage,
            family: MacDeviceInfo.family
        )
        .frame(maxWidth: 420)
        FirstTryStatus(
            phoneName: model.phoneName,
            distance: model.session.connection.isConnected ? model.proximity?.distance : nil,
            lockDistance: lockDistance
        )
    }
}

/// Where the iPhone is, in words.
private struct FirstTryStatus: View {
    let phoneName: String
    let distance: Double?
    let lockDistance: Double

    var body: some View {
        Group {
            if let distance {
                if distance > lockDistance {
                    Text("Far enough: your Mac locks as soon as you stop using it.")
                } else {
                    Text("\(phoneName) is about \(Measurement(value: distance, unit: UnitLength.meters), format: .lockyDistance) away")
                }
            } else {
                Text("Waiting for \(phoneName)…")
            }
        }
        .font(.callout)
        .foregroundStyle(Color.secondary)
        .contentTransition(.numericText())
        .animation(.smooth, value: distance)
    }
}
