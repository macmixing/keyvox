import Foundation

struct PasteDictionaryCasingStore {
    private let dictionaryFileURL: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(
        dictionaryFileURL: URL? = nil,
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.dictionaryFileURL = dictionaryFileURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/KeyVox/Dictionary/dictionary.json")
        self.fileManager = fileManager
        self.decoder = decoder
    }

    func shouldPreserveLeadingCapitalization(in text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }

        guard let data = try? Data(contentsOf: dictionaryFileURL),
              let payload = try? decoder.decode(DictionaryPayload.self, from: data) else {
            return false
        }

        return payload.entries.contains { entry in
            hasLeadingPhraseMatch(trimmedText, phrase: entry.phrase)
        }
    }

    private func hasLeadingPhraseMatch(_ text: String, phrase: String) -> Bool {
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { return false }
        guard text.hasPrefix(trimmedPhrase) else { return false }
        guard text.count > trimmedPhrase.count else { return true }

        let boundaryIndex = text.index(text.startIndex, offsetBy: trimmedPhrase.count)
        let boundaryCharacter = text[boundaryIndex]
        return boundaryCharacter.isWhitespace || boundaryCharacter.isPunctuation
    }
}

private struct DictionaryPayload: Decodable {
    let version: Int
    let entries: [DictionaryEntryRecord]
}

private struct DictionaryEntryRecord: Decodable {
    let id: UUID?
    let phrase: String
}
