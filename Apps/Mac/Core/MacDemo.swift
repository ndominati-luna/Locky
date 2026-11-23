#if DEBUG
import Foundation

/// Demo modes of the Mac app, for reviews without an iPhone.
///
/// - `-LockyDemo YES`: a paired and connected iPhone, to review the menu and the widget.
/// - `-LockyDemoPairingTour YES`: the pairing window walks through every step in a loop.
/// - `-LockyDemoLockAnimation YES`: plays the lock and unlock animations without locking.
/// - `-LockyDemoAnimationWindow YES`: opens the animation window.
/// - `-LockyDemoAbout YES`, `-LockyDemoStory YES`: opens About, or the video hidden behind its logo
///   (`-LockyDemoMuted YES` plays it without sound).
///
/// The animation demos start neither Bluetooth nor the widgets, and leave a running Locky alone.
/// Launch arguments such as `-locky.lockAnimationStyle flight` try a choice without saving it.
/// - `-LockyDemoSetup permissions|firstTry|magic`: the pairing window shows that setup step.
enum MacDemo {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemo") || isPairingTour || isLockAnimation || setupStep != nil
    }

    static var setupStep: MacSetupStep? {
        switch UserDefaults.standard.string(forKey: "LockyDemoSetup") {
        case "permissions": .permissions
        case "firstTry": .firstTry
        case "magic": .magic
        default: nil
        }
    }

    /// `-LockyDemoDashboardLog YES`: prints what the dashboard of the iPhone would receive.
    static var isDashboardLog: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoDashboardLog")
    }

    /// `-LockyDemoLockScreenPrompt YES`: shows the wings and the Unlock button on the desktop, then
    /// hides them as on a login.
    static var isLockScreenPrompt: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoLockScreenPrompt")
    }

    /// `-LockyDemoLockScreenProbe YES`: locks the Mac, then writes what the Accessibility API sees of
    /// the lock screen to `/tmp/locky-lockscreen.txt` (to place the wings on a new macOS).
    static var isLockScreenProbe: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoLockScreenProbe")
    }

    /// `-LockyDemoLockScreenOverlay YES`: locks the Mac, shows the wings and the Unlock button on the
    /// real lock screen and saves a screenshot to `/tmp/locky-lockscreen-overlay.png`.
    static var isLockScreenOverlay: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoLockScreenOverlay")
    }

    /// `-LockyDemoRecordLockScreen YES`: films the main display while Locky locks the Mac, shows the
    /// wings on the real lock screen and, once their Unlock button is clicked, covers it as while
    /// typing the password (unlock with Touch ID or the Apple Watch then). The film ends 3 seconds
    /// after the unlock, lands in the Movies folder and is shown in the Finder. No Bluetooth.
    static var isLockScreenFilm: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoRecordLockScreen")
    }

    /// `-LockyDemoLockAnimation YES`: plays the lock and unlock animations, without locking.
    static var isLockAnimation: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoLockAnimation")
    }

    /// `-LockyDemoAnimationWindow YES`: opens the animation window, to review it.
    static var isAnimationWindow: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoAnimationWindow")
    }

    /// `-LockyDemoReleaseNotes YES`: opens the release notes window.
    static var isReleaseNotesWindow: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoReleaseNotes")
    }

    /// `-LockyDemoAbout YES`: opens About (its logo hides the video of the first Locky).
    static var isAboutWindow: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoAbout")
    }

    /// `-LockyDemoStory YES`: opens the video of the first Locky, as if found in About.
    static var isStoryWindow: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoStory")
    }

    /// Demos of windows and animations only: no Bluetooth, no widgets, the running Locky stays.
    static var isAnimationOnly: Bool {
        isLockAnimation || isAnimationWindow || isReleaseNotesWindow || isAboutWindow || isStoryWindow
    }

    static var isPairingTour: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoPairingTour")
    }

    static var pairingTourSteps: [MacPairingStep] {
        [
            .idle,
            .searching,
            .deviceFound(name: "iPhone", modelIdentifier: "iPhone18,1"),
            .confirmCode(code: "482913", deviceName: "iPhone", isConfirmedOnMac: false, isConfirmedOnPhone: false),
            .confirmCode(code: "482913", deviceName: "iPhone", isConfirmedOnMac: false, isConfirmedOnPhone: true),
            .password(deviceName: "iPhone"),
            .calibrating,
            .completed,
            .failed(String(localized: "The connection with the iPhone was lost. Keep both devices close and try again."))
        ]
    }
}
#endif
