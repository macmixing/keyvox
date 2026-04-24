import Foundation

public struct DictionaryBuiltInEntry: Equatable {
    public let id: UUID
    public let phrase: String
    public let aliases: [String]

    public init(id: UUID, phrase: String, aliases: [String] = []) {
        self.id = id
        self.phrase = phrase
        self.aliases = aliases
    }
}

public enum DictionaryBuiltInEntries {
    public static let builtIns: [DictionaryBuiltInEntry] = [
        DictionaryBuiltInEntry(
            id: UUID(uuidString: "6D904F89-4B45-4E85-9F77-29E7E87BA0F8")!,
            phrase: "KeyVox",
            aliases: [
                "Kivok",
                "Kivox",
                "Keyvox",
            ]
        ),
        DictionaryBuiltInEntry(
            id: UUID(uuidString: "71E8F273-336C-4BD4-9F80-59926F0D9529")!,
            phrase: "KeyVox Speak",
            aliases: [
                "Kivok Speak",
                "Kivox Speak",
                "Keyvox Speak",
            ]
        ),
    ]

    public static let entries: [DictionaryEntry] = builtIns.map {
        DictionaryEntry(id: $0.id, phrase: $0.phrase)
    }

    public static func effectiveEntries(merging userEntries: [DictionaryEntry]) -> [DictionaryEntry] {
        let builtInPhrases = Set(entries.map { DictionaryTextNormalization.normalizedPhrase($0.phrase) })
        let filteredUserEntries = userEntries.filter { entry in
            let normalizedPhrase = DictionaryTextNormalization.normalizedPhrase(entry.phrase)
            return !builtInPhrases.contains(normalizedPhrase)
        }
        return filteredUserEntries + entries
    }
    /// Built-ins intentionally count as effective entries so app/product naming
    /// can use prompt hinting even when the user dictionary is empty.
    public static func hasEffectiveEntries(merging userEntries: [DictionaryEntry]) -> Bool {
        !effectiveEntries(merging: userEntries).isEmpty
    }

    static func aliases(for entry: DictionaryEntry) -> [String] {
        guard let builtIn = builtIns.first(where: { $0.id == entry.id }) else {
            return []
        }
        return builtIn.aliases
    }
}
