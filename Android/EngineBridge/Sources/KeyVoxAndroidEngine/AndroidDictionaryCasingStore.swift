import Foundation
import KeyVoxCore
import KeyVoxTextComposition

final class AndroidDictionaryCasingStore: @unchecked Sendable {
    static let shared = AndroidDictionaryCasingStore()

    private struct DictionaryPayload: Decodable {
        let entries: [Entry]
    }

    private struct Entry: Decodable {
        let phrase: String
    }

    private let lock = NSLock()
    private var fileURL: URL?
    private var cachedModificationDate: Date?
    private var cachedPhrases: [String] = []

    private init() {}

    func configure(directory: URL) {
        lock.withLock {
            fileURL = directory
                .appendingPathComponent("Dictionary", isDirectory: true)
                .appendingPathComponent("dictionary.json")
            cachedModificationDate = nil
            cachedPhrases = []
        }
    }

    func update(entries: [DictionaryEntry]) {
        lock.withLock {
            cachedPhrases = entries.map(\.phrase).filter { $0.isEmpty == false }
            cachedModificationDate = try? fileURL?.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
        }
    }

    func shouldPreserveLeadingCapitalization(in text: String) -> Bool {
        lock.withLock {
            DictionaryLeadingCapitalizationPolicy.shouldPreserve(
                text: text,
                dictionaryPhrases: loadPhrasesIfNeeded()
            )
        }
    }

    private func loadPhrasesIfNeeded() -> [String] {
        guard let fileURL else { return [] }
        let modificationDate = try? fileURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate
        if modificationDate == cachedModificationDate {
            return cachedPhrases
        }

        cachedModificationDate = modificationDate
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(DictionaryPayload.self, from: data) else {
            cachedPhrases = []
            return []
        }
        cachedPhrases = payload.entries.map(\.phrase).filter { $0.isEmpty == false }
        return cachedPhrases
    }
}
