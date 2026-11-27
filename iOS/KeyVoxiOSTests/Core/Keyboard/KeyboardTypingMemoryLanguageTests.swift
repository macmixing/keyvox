import Foundation
import KeyVoxPredictiveKeyboard
import Testing
@testable import KeyVox_iOS

/// What the keyboard learned is kept per typing language: the original file stays the original
/// language's, read as stored, and every other language learns into a file of its own beside it, so
/// a reset of one language leaves the others as they are.
@MainActor
struct KeyboardTypingMemoryLanguageTests {
    /// A memory file as the keyboard wrote it before it had languages: one learned word, written
    /// twice, under reset generation 2.
    private static let storedFile = Data("""
    {"resetGeneration":2,"memory":{"rejections":[],"wordUses":[{"firstForm":"Zorblat","lowercaseUses":0,"capitalUses":2,"previousWords":{},"lastUsed":786000000}],"capitals":[]}}
    """.utf8)

    @Test func anExistingStoredMemoryLoadsUnchangedAsTheOriginalLanguage() throws {
        let (folder, original) = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Self.storedFile.write(to: original)
        let defaults = makeDefaults()
        defaults.set(2, forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration)

        let memory = KeyboardTypingMemory(
            language: KeyboardTypingMemoryLocation.originalFileLanguage,
            fileURL: original,
            defaults: defaults
        )
        memory.adoptResetIfNeeded()

        #expect(memory.memory.saved == TypingMemoryFile(url: original).load(resetGeneration: 2))
        #expect(memory.memory.saved != TypingMemory.Saved())
        #expect(memory.memory.learnedVocabulary.keys == ["zorblat"])
        #expect(try Data(contentsOf: original) == Self.storedFile)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == [original.lastPathComponent])
        #expect(KeyboardTypingMemoryLocation.fileURL(forLanguage: KeyboardTypingMemoryLocation.originalFileLanguage, besideOriginal: original) == original)
    }

    @Test func anotherLanguageLearnsNothingFromTheOriginalFileAndKeepsItsOwnBesideIt() throws {
        let (folder, original) = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Self.storedFile.write(to: original)
        let defaults = makeDefaults()
        defaults.set(2, forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration)

        let other = KeyboardTypingMemory(language: "xx", fileURL: original, defaults: defaults)

        #expect(other.memory.saved == TypingMemory.Saved())
        let otherFile = KeyboardTypingMemoryLocation.fileURL(forLanguage: "xx", besideOriginal: original)
        #expect(otherFile != original)
        #expect(otherFile.deletingLastPathComponent() == folder)
        #expect(KeyboardTypingMemoryLocation.isLanguageFile(named: otherFile.lastPathComponent))
        #expect(KeyboardTypingMemoryLocation.isLanguageFile(named: original.lastPathComponent) == false)
    }

    @Test func resettingOneLanguageLeavesTheOthersAndResettingAllForgetsEveryLanguage() throws {
        let (folder, original) = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = makeDefaults()
        let otherFile = KeyboardTypingMemoryLocation.fileURL(forLanguage: "xx", besideOriginal: original)
        try Self.storedFile.write(to: original)
        try Self.storedFile.write(to: otherFile)
        defaults.set(2, forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration)
        let originalMemory = KeyboardTypingMemory(language: KeyboardTypingMemoryLocation.originalFileLanguage, fileURL: original, defaults: defaults)
        let otherMemory = KeyboardTypingMemory(language: "xx", fileURL: original, defaults: defaults)
        var restarts: [String] = []
        originalMemory.onLearnedVocabularyChange = { restarts.append("original") }
        otherMemory.onLearnedVocabularyChange = { restarts.append("xx") }

        KeyboardTypingMemoryReset.reset(language: "xx", defaults: defaults, originalFileURL: original)
        originalMemory.adoptResetIfNeeded()
        otherMemory.adoptResetIfNeeded()

        #expect(FileManager.default.fileExists(atPath: otherFile.path) == false)
        #expect(try Data(contentsOf: original) == Self.storedFile)
        #expect(restarts == ["xx"])
        #expect(originalMemory.memory.saved != TypingMemory.Saved())

        try Self.storedFile.write(to: otherFile)
        KeyboardTypingMemoryReset.reset(defaults: defaults, fileURL: original)
        originalMemory.adoptResetIfNeeded()

        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        #expect(restarts == ["xx", "original"])
    }

    @Test func aLanguageSwitchedBackToBeforeItsMemorySavesKeepsThatMemorysChange() throws {
        let (folder, original) = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = makeDefaults()
        defaults.set(2, forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration)
        // A reset after the test keeps the save it leaves waiting from writing into the removed folder.
        defer { defaults.set(3, forKey: UserDefaultsKeys.keyboardTypingMemoryResetGeneration) }
        let language = "a\(UUID().uuidString)"
        let otherLanguage = "b\(UUID().uuidString)"
        try Self.storedFile.write(to: KeyboardTypingMemoryLocation.fileURL(forLanguage: language, besideOriginal: original))
        let load = { (language: String) in
            KeyboardTypingMemory(language: language, fileURL: original, defaults: defaults)
        }

        let memory = KeyboardTypingMemory.current(language: language, load: load)
        #expect(memory.memory.learnedVocabulary.keys == ["zorblat"])
        memory.memory.clear()
        _ = KeyboardTypingMemory.current(language: otherLanguage, load: load)
        let returned = KeyboardTypingMemory.current(language: language, load: load)

        #expect(returned === memory)
        #expect(returned.memory.learnedVocabulary.keys.isEmpty)
    }

    private func makeFolder() throws -> (folder: URL, original: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (folder, folder.appendingPathComponent("typing-memory.json"))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "KeyboardTypingMemoryLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
