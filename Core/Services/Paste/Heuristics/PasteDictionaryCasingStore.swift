import Foundation

struct PasteDictionaryCasingStore {
    private let dictionaryFileURL: URL
    private let fileManager: FileManager

    init(
        dictionaryFileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.dictionaryFileURL = dictionaryFileURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/KeyVox/Dictionary/dictionary.json")
        self.fileManager = fileManager
    }

    func shouldPreserveLeadingCapitalization(in text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }

        let cacheKey = dictionaryFileURL.path
        reloadIfNeeded(cacheKey: cacheKey)
        let cachedEntries = Self.cachedEntriesByPath[cacheKey] ?? []

        return cachedEntries.contains { phrase in
            hasLeadingPhraseMatch(trimmedText, phrase: phrase)
        }
    }

    private func reloadIfNeeded(cacheKey: String) {
        let modificationDate = fileModificationDate()
        let hasLoadedEntries = Self.loadedPaths.contains(cacheKey)
        let cachedModificationDate = Self.cachedModificationDateByPath[cacheKey]
        guard !hasLoadedEntries || cachedModificationDate != modificationDate else {
            return
        }

        Self.loadedPaths.insert(cacheKey)
        Self.cachedModificationDateByPath[cacheKey] = modificationDate

        guard let data = try? Data(contentsOf: dictionaryFileURL) else {
            Self.cachedEntriesByPath[cacheKey] = []
            return
        }

        Self.cachedEntriesByPath[cacheKey] = extractPhrases(from: data)
    }

    private func fileModificationDate() -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: dictionaryFileURL.path) else {
            return nil
        }

        return attributes[.modificationDate] as? Date
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

    private func extractPhrases(from data: Data) -> [String] {
        guard let rootObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = rootObject["entries"] as? [[String: Any]] else {
            return []
        }

        return entries.compactMap { entry in
            guard let phrase = entry["phrase"] as? String else { return nil }
            return phrase
        }
    }

    private static var cachedEntriesByPath: [String: [String]] = [:]
    private static var cachedModificationDateByPath: [String: Date?] = [:]
    private static var loadedPaths: Set<String> = []
}
