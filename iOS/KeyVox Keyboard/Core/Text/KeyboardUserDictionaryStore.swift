import Foundation
import KeyVoxCore

final class KeyboardUserDictionaryStore {
    private struct DictionaryPayload: Decodable {
        let version: Int
        let entries: [DictionaryEntry]
    }

    private let fileManager: FileManager
    private let dictionaryFileURL: URL?
    private var cachedEntries: [DictionaryEntry] = []
    private var cachedModificationDate: Date?

    init(
        fileManager: FileManager = .default,
        appGroupID: String = KeyVoxIPCBridge.appGroupID
    ) {
        self.fileManager = fileManager
        dictionaryFileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("KeyVoxCore", isDirectory: true)
            .appendingPathComponent("Dictionary", isDirectory: true)
            .appendingPathComponent("dictionary.json")
    }

    func entries() -> [DictionaryEntry] {
        guard let dictionaryFileURL else {
            return DictionaryBuiltInEntries.entries
        }

        let modificationDate = dictionaryFileModificationDate(at: dictionaryFileURL)
        if modificationDate == cachedModificationDate {
            return DictionaryBuiltInEntries.effectiveEntries(merging: cachedEntries)
        }
        cachedModificationDate = modificationDate

        guard let data = try? Data(contentsOf: dictionaryFileURL),
              let payload = try? JSONDecoder().decode(DictionaryPayload.self, from: data) else {
            cachedEntries = []
            return DictionaryBuiltInEntries.entries
        }
        cachedEntries = payload.entries.filter { $0.phrase.isEmpty == false }
        return DictionaryBuiltInEntries.effectiveEntries(merging: cachedEntries)
    }

    func phrases() -> [String] {
        entries().map(\.phrase)
    }

    private func dictionaryFileModificationDate(at url: URL) -> Date? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }
}
