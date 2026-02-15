import Foundation
import Testing
@testable import KeyVox

@MainActor
struct DictionaryStoreTests {
    @Test
    func addUpdateDeleteAndReloadPersistence() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

            try store.add(phrase: " Cueboard ")
            #expect(store.entries.count == 1)
            #expect(store.entries[0].phrase == "Cueboard")

            let id = try #require(store.entries.first?.id)
            try store.update(id: id, phrase: "MiGo Platform")
            #expect(store.entries[0].phrase == "MiGo Platform")

            store.delete(id: id)
            #expect(store.entries.isEmpty)

            try store.add(phrase: "Dom Esposito")
            let reloaded = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            #expect(reloaded.entries.map(\.phrase) == ["Dom Esposito"])
        }
    }

    @Test
    func duplicateAndEmptyValidation() throws {
        try withTemporaryDirectory { root in
            let store = DictionaryStore(
                fileManager: .default,
                baseDirectoryURL: root.appendingPathComponent("KeyVox", isDirectory: true)
            )

            do {
                try store.add(phrase: "  ")
                Issue.record("Expected empty phrase validation error")
            } catch let error as DictionaryStoreError {
                #expect(error == .emptyPhrase)
            }

            try store.add(phrase: "Cueboard")

            do {
                try store.add(phrase: "cueboard")
                Issue.record("Expected duplicate phrase validation error")
            } catch let error as DictionaryStoreError {
                #expect(error == .duplicatePhrase)
            }
        }
    }

    @Test
    func whisperHintPromptRespectsCaps() throws {
        try withTemporaryDirectory { root in
            let store = DictionaryStore(
                fileManager: .default,
                baseDirectoryURL: root.appendingPathComponent("KeyVox", isDirectory: true)
            )

            try store.add(phrase: "Cueboard")
            try store.add(phrase: "MiGo Platform")
            try store.add(phrase: "Dom Esposito")

            let prompt = store.whisperHintPrompt(maxEntries: 2, maxChars: 80)
            #expect(prompt.hasPrefix("Domain vocabulary: "))
            #expect(prompt.contains("Cueboard"))
            #expect(prompt.contains("MiGo Platform"))
            #expect(!prompt.contains("Dom Esposito"))
        }
    }

    @Test
    func failedSaveDoesNotWipeExistingDictionaryFile() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let writer = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            try writer.add(phrase: "Dom Esposito")

            let failingManager = FailingDirectoryFileManager()
            let failingStore = DictionaryStore(fileManager: failingManager, baseDirectoryURL: base)
            failingManager.shouldFailCreateDirectory = true

            do {
                try failingStore.add(phrase: "Cueboard")
                Issue.record("Expected save failure")
            } catch let error as DictionaryStoreError {
                #expect(error == .saveFailed)
            }

            let dictionaryFile = base
                .appendingPathComponent("Dictionary", isDirectory: true)
                .appendingPathComponent("dictionary.json")
            let persisted = try String(contentsOf: dictionaryFile, encoding: .utf8)
            #expect(persisted.contains("Dom Esposito"))
            #expect(!persisted.contains("Cueboard"))
            #expect(failingStore.saveErrorMessage?.isEmpty == false)
        }
    }

    @Test
    func corruptPrimaryRecoversFromBackup() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let dictionaryDir = base.appendingPathComponent("Dictionary", isDirectory: true)
            try FileManager.default.createDirectory(at: dictionaryDir, withIntermediateDirectories: true)

            let primary = dictionaryDir.appendingPathComponent("dictionary.json")
            let backup = dictionaryDir.appendingPathComponent("dictionary.backup.json")
            try "broken".data(using: .utf8)!.write(to: primary)
            try makePayload(phrases: ["Dom Esposito"]).write(to: backup)

            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            #expect(store.entries.map(\.phrase) == ["Dom Esposito"])
            #expect(store.loadWarningMessage?.contains("recovered from backup") == true)
        }
    }

    @Test
    func corruptBothFilesTriggersQuarantineAndReset() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let dictionaryDir = base.appendingPathComponent("Dictionary", isDirectory: true)
            try FileManager.default.createDirectory(at: dictionaryDir, withIntermediateDirectories: true)

            let primary = dictionaryDir.appendingPathComponent("dictionary.json")
            let backup = dictionaryDir.appendingPathComponent("dictionary.backup.json")
            try "broken-primary".data(using: .utf8)!.write(to: primary)
            try "broken-backup".data(using: .utf8)!.write(to: backup)

            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            #expect(store.entries.isEmpty)
            #expect(store.loadWarningMessage == "Dictionary data was corrupted and reset.")

            let contents = try FileManager.default.contentsOfDirectory(atPath: dictionaryDir.path)
            let quarantined = contents.filter { $0.contains(".corrupt.") }
            #expect(quarantined.count >= 2)
        }
    }

    private func makePayload(phrases: [String]) throws -> Data {
        let entries: [[String: String]] = phrases.map {
            ["id": UUID().uuidString, "phrase": $0]
        }
        let payload: [String: Any] = [
            "version": 1,
            "entries": entries,
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
    }
}
