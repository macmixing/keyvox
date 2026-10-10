import Foundation

/// Makes the KeyVox keyboard forget what it learned from the user's typing: the corrections
/// they turned down, the words it learned, and the capitals it learned for dictionary words. The
/// reset is counted before the keyboard's file is
/// removed, so a keyboard still holding the old memory never saves it again and drops it the
/// next time it is used.
enum KeyboardTypingMemoryReset {
    static func reset(
        defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID),
        fileURL: URL? = KeyboardTypingMemoryLocation.fileURL(),
        fileManager: FileManager = .default
    ) {
        let key = UserDefaultsKeys.keyboardTypingMemoryResetGeneration
        defaults?.set((defaults?.integer(forKey: key) ?? 0) + 1, forKey: key)
        if let fileURL {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
