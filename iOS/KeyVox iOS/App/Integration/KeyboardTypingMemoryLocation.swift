import Foundation

/// Where the KeyVox keyboard keeps what it learned from the user's typing, in the app group the
/// KeyVox app shares with it, so the app can reset it.
enum KeyboardTypingMemoryLocation {
    static func fileURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID)?
            .appendingPathComponent("Keyboard", isDirectory: true)
            .appendingPathComponent("typing-memory.json")
    }
}
