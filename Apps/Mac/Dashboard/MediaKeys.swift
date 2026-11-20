import AppKit

/// The media keys of the keyboard (play/pause, next, previous). macOS routes them to whichever app
/// is playing, Music, Spotify or a browser alike. Posting them needs the Accessibility permission,
/// which Locky already has to type the password.
enum MediaKeys {
    enum Key: Int {
        // NX_KEYTYPE_PLAY, NX_KEYTYPE_NEXT, NX_KEYTYPE_PREVIOUS (IOKit/hidsystem/ev_keymap.h).
        case playPause = 16
        case next = 17
        case previous = 18
    }

    static func press(_ key: Key) {
        for isDown in [true, false] {
            let state: Int = isDown ? 0xA : 0xB
            let event: NSEvent? = .otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: .init(rawValue: UInt(state << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                subtype: 8,
                data1: (key.rawValue << 16) | (state << 8),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
