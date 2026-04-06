import Foundation

final class KeyboardDictionaryCasingStore {
    private struct DictionaryPayload: Decodable {
        let version: Int
        let entries: [Entry]
    }

    private struct Entry: Decodable {
        let phrase: String
    }

    private let fileManager: FileManager
    private let dictionaryFileURL: URL?

    private var cachedPhrases: [String] = []
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

    func shouldPreserveLeadingCapitalization(in text: String) -> Bool {
        loadPhrasesIfNeeded().contains { phrase in
            text.hasPrefix(phrase) && nextCharacterAfterPhraseBoundaryIsSafe(phrase: phrase, in: text)
        }
    }

    private func loadPhrasesIfNeeded() -> [String] {
        guard let dictionaryFileURL else { return [] }

        let modificationDate = dictionaryFileModificationDate(at: dictionaryFileURL)
        if modificationDate == cachedModificationDate {
            return cachedPhrases
        }

        cachedModificationDate = modificationDate

        guard let data = try? Data(contentsOf: dictionaryFileURL),
              let payload = try? JSONDecoder().decode(DictionaryPayload.self, from: data) else {
            cachedPhrases = []
            return []
        }

        cachedPhrases = payload.entries
            .map(\.phrase)
            .filter { !$0.isEmpty }

        return cachedPhrases
    }

    private func dictionaryFileModificationDate(at url: URL) -> Date? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private func nextCharacterAfterPhraseBoundaryIsSafe(phrase: String, in text: String) -> Bool {
        let boundaryIndex = text.index(text.startIndex, offsetBy: phrase.count)
        guard boundaryIndex < text.endIndex else { return true }

        let nextCharacter = text[boundaryIndex]
        return nextCharacter.isWhitespace || nextCharacter.isPunctuation
    }
}
