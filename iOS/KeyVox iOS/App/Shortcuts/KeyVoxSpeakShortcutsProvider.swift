import AppIntents

struct KeyVoxSpeakShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: KeyVoxSpeakShortcutIntent(),
            phrases: [
                "Speak copied text in \(.applicationName)",
                "Start KeyVox Speak in \(.applicationName)",
                "Use KeyVox Speak in \(.applicationName)"
            ],
            shortTitle: "KeyVox Speak",
            systemImageName: "speaker.wave.2.fill"
        )
    }
}
