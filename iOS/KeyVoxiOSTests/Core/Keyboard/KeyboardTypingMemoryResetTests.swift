import Foundation
import Testing
@testable import KeyVox_iOS

/// Resetting what the keyboard learned in the KeyVox app removes the keyboard's file and makes
/// a keyboard still holding the old memory start over once, the next time it is shown.
@MainActor
struct KeyboardTypingMemoryResetTests {
    @Test func resetRemovesTheFileAndARunningKeyboardStartsOverOnce() throws {
        let defaults = makeDefaults()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("typing-memory.json")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let keyboard = KeyboardTypingMemory(fileURL: fileURL, defaults: defaults)
        var restarts = 0
        keyboard.onLearnedVocabularyChange = { restarts += 1 }
        keyboard.adoptResetIfNeeded()
        #expect(restarts == 0)

        KeyboardTypingMemoryReset.reset(defaults: defaults, fileURL: fileURL)

        #expect(defaults.integer(forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration) == 1)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
        keyboard.adoptResetIfNeeded()
        keyboard.adoptResetIfNeeded()
        #expect(restarts == 1)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "KeyboardTypingMemoryResetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
