import Foundation

struct KeyboardSupplementaryLexicon: Sendable {
    static let empty = KeyboardSupplementaryLexicon(entries: [])

    struct Entry: Sendable {
        let userInput: String
        let documentText: String
    }

    private let replacementByInput: [String: String]
    private let protectedWords: Set<String>

    init(entries: [Entry]) {
        var replacements: [String: String] = [:]
        var protectedWords: Set<String> = []

        for entry in entries {
            let normalizedInput = Self.normalized(entry.userInput)
            guard normalizedInput.isEmpty == false,
                  entry.documentText.isEmpty == false else {
                continue
            }
            let normalizedDocumentText = Self.normalized(entry.documentText)
            if normalizedInput != normalizedDocumentText
                || Self.hasDistinctiveCasing(entry.documentText) {
                replacements[normalizedInput] = entry.documentText
            }

            if Self.isSingleWord(entry.userInput) {
                protectedWords.insert(normalizedInput)
            }
            if Self.isSingleWord(entry.documentText) {
                protectedWords.insert(Self.normalized(entry.documentText))
            }
        }

        replacementByInput = replacements
        self.protectedWords = protectedWords
    }

    func replacement(for typedWord: String) -> String? {
        replacementByInput[Self.normalized(typedWord)]
    }

    func contains(_ word: String) -> Bool {
        protectedWords.contains(Self.normalized(word))
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    private static func isSingleWord(_ value: String) -> Bool {
        value.isEmpty == false && value.allSatisfy { character in
            character.isLetter || character == "'" || character == "’"
        }
    }

    private static func hasDistinctiveCasing(_ value: String) -> Bool {
        let letters = value.filter(\.isLetter)
        guard letters.isEmpty == false else { return false }
        if letters.count > 1, letters == letters.uppercased() {
            return true
        }
        return letters.dropFirst().contains(where: \.isUppercase)
    }

}
