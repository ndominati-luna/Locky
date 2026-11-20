import AppIntents

/// Siri and Spotlight phrases. App Store Connect refuses Apple product names in them (ITMS-90626):
/// "computer", never "Mac" (in the short titles too).
struct LockyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LockMacIntent(),
            phrases: [
                "Lock my computer with \(.applicationName)",
                "\(.applicationName) lock my computer",
                "Lock with \(.applicationName)"
            ],
            shortTitle: "Lock",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: UnlockMacIntent(),
            phrases: [
                "Unlock my computer with \(.applicationName)",
                "\(.applicationName) unlock my computer",
                "Unlock with \(.applicationName)"
            ],
            shortTitle: "Unlock",
            systemImageName: "lock.open.fill"
        )
    }
}
