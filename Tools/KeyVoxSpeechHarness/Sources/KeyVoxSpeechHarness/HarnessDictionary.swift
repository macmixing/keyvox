import Foundation
import KeyVoxCore

/// Explicit diagnostic storage selection; the production store owns persistence.
@MainActor
enum HarnessDictionary {
    struct Snapshot: Encodable, Sendable {
        let entries: [DictionaryEntry]
        let loadWarning: String?
        let saveError: String?
        let degradedDurability: Bool
    }

    private struct MutationReport: Encodable {
        let before: Snapshot
        let after: Snapshot
    }

    static func load() -> Snapshot {
        guard let directory = ProcessInfo.processInfo.environment["KEYVOX_DICTIONARY_DIRECTORY"] else {
            return Snapshot(entries: [], loadWarning: nil, saveError: nil, degradedDurability: false)
        }
        return snapshot(DictionaryStore(baseDirectoryURL: URL(fileURLWithPath: directory, isDirectory: true)))
    }

    static func add(directory: String, phrasePath: String) throws {
        let store = DictionaryStore(baseDirectoryURL: URL(fileURLWithPath: directory, isDirectory: true))
        let before = snapshot(store)
        let phrase = try String(contentsOfFile: phrasePath, encoding: .utf8)
        do {
            try store.add(phrase: phrase)
        } catch {
            try emit(MutationReport(before: before, after: snapshot(store)))
            throw error
        }
        try emit(MutationReport(before: before, after: snapshot(store)))
    }

    private static func snapshot(_ store: DictionaryStore) -> Snapshot {
        Snapshot(entries: store.entries, loadWarning: store.loadWarningMessage,
                 saveError: store.saveErrorMessage, degradedDurability: store.degradedDurability)
    }

    private static func emit(_ report: MutationReport) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(report)
        data.append(0x0A)
        try FileHandle.standardOutput.write(contentsOf: data)
    }
}
