import AppIntents

struct KeyVoxSpeakShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleKeyVoxDictationIntent(),
            phrases: [
                "Toggle dictation in \(.applicationName)"
            ],
            shortTitle: "Toggle Dictation",
            systemImageName: "waveform"
        )

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
