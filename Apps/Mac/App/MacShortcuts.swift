import AppIntents

/// Siri, Spotlight and Shortcuts phrases on the Mac.
struct MacShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LockMacNowIntent(),
            phrases: [
                "Lock my Mac with \(.applicationName)",
                "\(.applicationName) lock my Mac"
            ],
            shortTitle: "Lock Mac",
            systemImageName: "lock.fill"
        )
    }
}
