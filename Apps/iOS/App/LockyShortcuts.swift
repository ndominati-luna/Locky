import AppIntents

/// Siri and Spotlight phrases.
struct LockyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LockMacIntent(),
            phrases: [
                "Lock my Mac with \(.applicationName)",
                "\(.applicationName) lock my Mac"
            ],
            shortTitle: "Lock Mac",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: UnlockMacIntent(),
            phrases: [
                "Unlock my Mac with \(.applicationName)",
                "\(.applicationName) unlock my Mac"
            ],
            shortTitle: "Unlock Mac",
            systemImageName: "lock.open.fill"
        )
    }
}
