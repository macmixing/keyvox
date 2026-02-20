import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class DictionaryStoreTests: XCTestCase {
    func testAddUpdateDeleteAndReloadPersistence() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

            try store.add(phrase: " Cueboard ")
            XCTAssertTrue(store.entries.count == 1)
            XCTAssertTrue(store.entries[0].phrase == "Cueboard")

            guard let id = store.entries.first?.id else {
                XCTFail("Expected at least one entry after add")
                return
            }
            try store.update(id: id, phrase: "MiGo Platform")
            XCTAssertTrue(store.entries[0].phrase == "MiGo Platform")

            store.delete(id: id)
            XCTAssertTrue(store.entries.isEmpty)

            try store.add(phrase: "Dom Esposito")
            let reloaded = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            XCTAssertTrue(reloaded.entries.map(\.phrase) == ["Dom Esposito"])
        }
    }

    func testDuplicateAndEmptyValidation() throws {
        try withTemporaryDirectory { root in
            let store = DictionaryStore(
                fileManager: .default,
                baseDirectoryURL: root.appendingPathComponent("KeyVox", isDirectory: true)
            )

            do {
                try store.add(phrase: "  ")
                XCTFail("Expected empty phrase validation error")
            } catch let error as DictionaryStoreError {
                XCTAssertTrue(error == .emptyPhrase)
            }

            try store.add(phrase: "Cueboard")

            do {
                try store.add(phrase: "cueboard")
                XCTFail("Expected duplicate phrase validation error")
            } catch let error as DictionaryStoreError {
                XCTAssertTrue(error == .duplicatePhrase)
            }
        }
    }

    func testWhisperHintPromptRespectsCaps() throws {
        try withTemporaryDirectory { root in
            let store = DictionaryStore(
                fileManager: .default,
                baseDirectoryURL: root.appendingPathComponent("KeyVox", isDirectory: true)
            )

            try store.add(phrase: "Cueboard")
            try store.add(phrase: "MiGo Platform")
            try store.add(phrase: "Dom Esposito")

            let prompt = store.whisperHintPrompt(maxEntries: 2, maxChars: 80)
            XCTAssertTrue(prompt.hasPrefix("Domain vocabulary: "))
            XCTAssertTrue(prompt.contains("MiGo Platform"))
            XCTAssertTrue(prompt.contains("Dom Esposito"))
            XCTAssertTrue(!prompt.contains("Cueboard"))
        }
    }

    func testFailedSaveDoesNotWipeExistingDictionaryFile() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let writer = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            try writer.add(phrase: "Dom Esposito")

            let failingManager = FailingDirectoryFileManager()
            let failingStore = DictionaryStore(fileManager: failingManager, baseDirectoryURL: base)
            failingManager.shouldFailCreateDirectory = true

            do {
                try failingStore.add(phrase: "Cueboard")
                XCTFail("Expected save failure")
            } catch let error as DictionaryStoreError {
                XCTAssertTrue(error == .saveFailed)
            }

            let dictionaryFile = base
                .appendingPathComponent("Dictionary", isDirectory: true)
                .appendingPathComponent("dictionary.json")
            let persisted = try String(contentsOf: dictionaryFile, encoding: .utf8)
            XCTAssertTrue(persisted.contains("Dom Esposito"))
            XCTAssertTrue(!persisted.contains("Cueboard"))
            XCTAssertTrue(failingStore.saveErrorMessage?.isEmpty == false)
        }
    }

    func testCorruptPrimaryRecoversFromBackup() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let dictionaryDir = base.appendingPathComponent("Dictionary", isDirectory: true)
            try FileManager.default.createDirectory(at: dictionaryDir, withIntermediateDirectories: true)

            let primary = dictionaryDir.appendingPathComponent("dictionary.json")
            let backup = dictionaryDir.appendingPathComponent("dictionary.backup.json")
            try "broken".data(using: .utf8)!.write(to: primary)
            try makePayload(phrases: ["Dom Esposito"]).write(to: backup)

            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            XCTAssertTrue(store.entries.map(\.phrase) == ["Dom Esposito"])
            XCTAssertTrue(store.loadWarningMessage?.contains("recovered from backup") == true)
        }
    }

    func testCorruptBothFilesTriggersQuarantineAndReset() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let dictionaryDir = base.appendingPathComponent("Dictionary", isDirectory: true)
            try FileManager.default.createDirectory(at: dictionaryDir, withIntermediateDirectories: true)

            let primary = dictionaryDir.appendingPathComponent("dictionary.json")
            let backup = dictionaryDir.appendingPathComponent("dictionary.backup.json")
            try "broken-primary".data(using: .utf8)!.write(to: primary)
            try "broken-backup".data(using: .utf8)!.write(to: backup)

            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            XCTAssertTrue(store.entries.isEmpty)
            XCTAssertTrue(store.loadWarningMessage == "Dictionary data was corrupted and reset.")

            let contents = try FileManager.default.contentsOfDirectory(atPath: dictionaryDir.path)
            let quarantined = contents.filter { $0.contains(".corrupt.") }
            XCTAssertTrue(quarantined.count >= 2)
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
