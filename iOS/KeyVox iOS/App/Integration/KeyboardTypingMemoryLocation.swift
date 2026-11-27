import Foundation

/// Where the KeyVox keyboard keeps what it learned from the user's typing, in the app group the
/// KeyVox app shares with it, so the app can reset it. Each typing language has its own file. The
/// language every keyboard typed in before it had languages keeps the file it always had, so what
/// it learned then stays where it is, as it is; every other language's file sits beside it.
enum KeyboardTypingMemoryLocation {
    /// The language whose memory is the original file: the only language the keyboard typed in
    /// before it had languages.
    static let originalFileLanguage = "en"

    private static let fileName = "typing-memory.json"
    private static let languageFilePrefix = "typing-memory-"
    private static let fileExtension = "json"

    /// The original file, which holds `originalFileLanguage`'s memory.
    static func fileURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID)?
            .appendingPathComponent("Keyboard", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    /// The file holding `language`'s memory: the original file for `originalFileLanguage`, and a
    /// file named after the language beside it for every other one.
    static func fileURL(forLanguage language: String, fileManager: FileManager = .default) -> URL? {
        fileURL(fileManager: fileManager).map { fileURL(forLanguage: language, besideOriginal: $0) }
    }

    /// `language`'s file in the folder of the original file at `originalFileURL`.
    static func fileURL(forLanguage language: String, besideOriginal originalFileURL: URL) -> URL {
        guard language != originalFileLanguage else { return originalFileURL }
        return originalFileURL.deletingLastPathComponent()
            .appendingPathComponent(languageFilePrefix + language)
            .appendingPathExtension(fileExtension)
    }

    /// Whether a file named `name` in the folder holds a language's memory other than the original
    /// file's.
    static func isLanguageFile(named name: String) -> Bool {
        name.hasPrefix(languageFilePrefix) && name.hasSuffix("." + fileExtension)
    }
}
