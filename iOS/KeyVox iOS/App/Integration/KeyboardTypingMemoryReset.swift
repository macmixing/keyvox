import Foundation

/// Makes the KeyVox keyboard forget what it learned from the user's typing: the corrections
/// they turned down, the words it learned, and the capitals it learned for dictionary words, in
/// every language or in one. The reset is counted before the keyboard's file is removed, so a
/// keyboard still holding the old memory never saves it again and drops it the next time it is
/// used.
enum KeyboardTypingMemoryReset {
    /// Forgets what `scope` covers.
    static func reset(_ scope: KeyboardTypingMemoryResetScope) {
        switch scope {
        case .keyboard, .allLanguages:
            reset()
        case let .language(language):
            reset(language: language)
        }
    }

    /// Forgets what the keyboard learned in every language: the original file at `fileURL` and every
    /// language's file beside it.
    static func reset(
        defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID),
        fileURL: URL? = KeyboardTypingMemoryLocation.fileURL(),
        fileManager: FileManager = .default
    ) {
        let key = UserDefaultsKeys.keyboardTypingMemoryResetGeneration
        defaults?.set((defaults?.integer(forKey: key) ?? 0) + 1, forKey: key)
        guard let fileURL else { return }
        try? fileManager.removeItem(at: fileURL)
        let folder = fileURL.deletingLastPathComponent()
        for name in (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
        where KeyboardTypingMemoryLocation.isLanguageFile(named: name) {
            try? fileManager.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    /// Forgets what the keyboard learned in `language` only, leaving every other language's memory
    /// as it is.
    static func reset(
        language: String,
        defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID),
        originalFileURL: URL? = KeyboardTypingMemoryLocation.fileURL(),
        fileManager: FileManager = .default
    ) {
        let key = UserDefaultsKeys.keyboardTypingMemoryLanguageResetGenerations
        var generations = defaults?.dictionary(forKey: key) as? [String: Int] ?? [:]
        generations[language, default: 0] += 1
        defaults?.set(generations, forKey: key)
        if let originalFileURL {
            try? fileManager.removeItem(
                at: KeyboardTypingMemoryLocation.fileURL(forLanguage: language, besideOriginal: originalFileURL)
            )
        }
    }
}
