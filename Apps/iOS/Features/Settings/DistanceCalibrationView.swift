import LockyKit
import SwiftUI

/// Measures the signal again with the iPhone about 1 m from the Mac, then 2 m, so that distances
/// read right (the pairing does it once; the Mac, its place or the case of the iPhone may change).
struct DistanceCalibrationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                CalibrationSymbol(calibration: model.distanceCalibration)
                VStack(spacing: 8) {
                    if let stepText {
                        Text(stepText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Text(title)
                        .font(.title2.bold())
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                CalibrationButton(onClose: { dismiss() })
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { model.resetDistanceCalibration() }
        .sensoryFeedback(trigger: model.distanceCalibration) { _, calibration in
            switch calibration {
            case .done: .success
            case .failed: .error
            case .ready(.far): .impact
            default: nil
            }
        }
    }

    /// "Step 1 of 2".
    private var stepText: String? {
        switch model.distanceCalibration {
        case .ready(.near), .measuring(.near): String(localized: "Step 1 of 2")
        case .ready(.far), .measuring(.far): String(localized: "Step 2 of 2")
        case .done, .failed: nil
        }
    }

    private var title: String {
        switch model.distanceCalibration {
        case .ready(.near): String(localized: "Calibrate the distance")
        case .ready(.far): String(localized: "Step back to 2\u{00A0}m")
        case .measuring: String(localized: "Measuring…")
        case .done: String(localized: "Distance calibrated")
        case .failed: String(localized: "Calibration failed")
        }
    }

    private var message: String {
        switch model.distanceCalibration {
        case .ready(.near):
            if model.isConnected {
                String(localized: "Put your iPhone flat about 1 m from your Mac (a big step), then confirm. Don't touch it during the measure.")
            } else {
                String(localized: "Your iPhone must be connected to your Mac to calibrate the distance.")
            }
        case .ready(.far):
            String(localized: "Now put your iPhone flat about 2 m from your Mac (two big steps), then confirm.")
        case .measuring:
            String(localized: "Don't move your iPhone, it only takes a few seconds.")
        case .done:
            String(localized: "Locky now measures the distance from your iPhone to your Mac with this new reference.")
        case .failed:
            String(localized: "Check that your iPhone is connected to your Mac and try again.")
        }
    }
}

/// The Mac and the iPhone, waves while measuring, then the outcome.
private struct CalibrationSymbol: View {
    let calibration: DistanceCalibration

    var body: some View {
        Group {
            switch calibration {
            case .ready:
                Image(systemName: "laptopcomputer.and.iphone")
                    .foregroundStyle(.tint)
            case .measuring:
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.symbolEffect(.drawOn))
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 64))
        .frame(height: 80)
        .contentTransition(.symbolEffect(.replace))
        .animation(.smooth, value: calibration)
        .accessibilityHidden(true)
    }
}

/// Confirms the position, shows the measure, then closes the screen.
private struct CalibrationButton: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    var body: some View {
        switch model.distanceCalibration {
        case .ready, .failed:
            Button(action: model.calibrateDistance) {
                Text(model.distanceCalibration == .failed ? "Try again" : "Confirm")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!model.isConnected)
        case .measuring:
            ProgressView()
                .controlSize(.large)
                .frame(height: 52)
        case .done:
            Button(action: onClose) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }
}
