import Foundation
import XCTest
@testable import KeyVoxCore

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
            XCTAssertEqual(failingStore.entries.map(\.phrase), ["Dom Esposito"])

            guard let existingID = failingStore.entries.first?.id else {
                XCTFail("Expected persisted entry to remain loaded after failed save")
                return
            }

            do {
                try failingStore.update(id: existingID, phrase: "Cueboard")
                XCTFail("Expected update save failure")
            } catch let error as DictionaryStoreError {
                XCTAssertTrue(error == .saveFailed)
            }
            XCTAssertEqual(failingStore.entries.map(\.phrase), ["Dom Esposito"])

            failingStore.delete(id: existingID)
            XCTAssertEqual(failingStore.entries.map(\.phrase), ["Dom Esposito"])

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

    func testBackupWriteFailureDoesNotFailPrimaryPersistence() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let dictionaryDir = base.appendingPathComponent("Dictionary", isDirectory: true)
            let backupPath = dictionaryDir.appendingPathComponent("dictionary.backup.json", isDirectory: true)

            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            try FileManager.default.createDirectory(at: dictionaryDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: backupPath, withIntermediateDirectories: true)
            try store.add(phrase: "Cueboard")

            XCTAssertEqual(store.entries.map(\.phrase), ["Cueboard"])
            XCTAssertNil(store.saveErrorMessage)
            XCTAssertTrue(store.degradedDurability)

            let primary = dictionaryDir.appendingPathComponent("dictionary.json")
            let persisted = try String(contentsOf: primary, encoding: .utf8)
            XCTAssertTrue(persisted.contains("Cueboard"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath.path))

            let reloadedAfterBackupFailure = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            XCTAssertEqual(reloadedAfterBackupFailure.entries.map(\.phrase), ["Cueboard"])
            XCTAssertTrue(reloadedAfterBackupFailure.degradedDurability)

            try FileManager.default.removeItem(at: backupPath)
            try store.add(phrase: "MiGo Platform")

            XCTAssertEqual(store.entries.map(\.phrase), ["Cueboard", "MiGo Platform"])
            XCTAssertFalse(store.degradedDurability)

            let reloadedAfterRepair = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            XCTAssertEqual(reloadedAfterRepair.entries.map(\.phrase), ["Cueboard", "MiGo Platform"])
            XCTAssertFalse(reloadedAfterRepair.degradedDurability)
        }
    }

    func testReplaceAllPersistsCleanSnapshot() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

            try store.replaceAll(entries: [
                DictionaryEntry(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, phrase: "Cueboard"),
                DictionaryEntry(id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!, phrase: "MiGo Platform"),
            ])

            XCTAssertEqual(store.entries.map(\.phrase), ["Cueboard", "MiGo Platform"])
            XCTAssertEqual(
                store.entries.map(\.id.uuidString),
                [
                    "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
                    "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD",
                ]
            )

            let reloaded = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            XCTAssertEqual(reloaded.entries.map(\.phrase), ["Cueboard", "MiGo Platform"])
        }
    }

    func testReplaceAllRejectsLossySnapshot() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let store = DictionaryStore(fileManager: .default, baseDirectoryURL: base)

            do {
                try store.replaceAll(entries: [
                    DictionaryEntry(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, phrase: " Cueboard "),
                    DictionaryEntry(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, phrase: "cueboard"),
                    DictionaryEntry(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!, phrase: "  "),
                ])
                XCTFail("Expected lossy snapshot import failure")
            } catch let error as DictionaryStoreError {
                XCTAssertEqual(error, .invalidSnapshotImport)
            }

            XCTAssertTrue(store.entries.isEmpty)
        }
    }

    func testReplaceAllFailedSaveLeavesExistingEntriesUntouched() throws {
        try withTemporaryDirectory { root in
            let base = root.appendingPathComponent("KeyVox", isDirectory: true)
            let writer = DictionaryStore(fileManager: .default, baseDirectoryURL: base)
            try writer.add(phrase: "Dom Esposito")

            let failingManager = FailingDirectoryFileManager()
            let failingStore = DictionaryStore(fileManager: failingManager, baseDirectoryURL: base)
            failingManager.shouldFailCreateDirectory = true

            do {
                try failingStore.replaceAll(entries: [
                    DictionaryEntry(phrase: "Cueboard"),
                    DictionaryEntry(phrase: "MiGo Platform"),
                ])
                XCTFail("Expected replaceAll save failure")
            } catch let error as DictionaryStoreError {
                XCTAssertEqual(error, .saveFailed)
            }

            XCTAssertEqual(failingStore.entries.map(\.phrase), ["Dom Esposito"])
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
