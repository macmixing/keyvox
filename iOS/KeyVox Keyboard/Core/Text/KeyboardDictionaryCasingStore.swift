import Foundation

final class KeyboardDictionaryCasingStore {
    private let phrasesProvider: () -> [String]

    init(phrasesProvider: @escaping () -> [String]) {
        self.phrasesProvider = phrasesProvider
    }

    func shouldPreserveLeadingCapitalization(in text: String) -> Bool {
        phrasesProvider().contains { phrase in
            text.hasPrefix(phrase) && nextCharacterAfterPhraseBoundaryIsSafe(phrase: phrase, in: text)
        }
    }

    private func nextCharacterAfterPhraseBoundaryIsSafe(phrase: String, in text: String) -> Bool {
        let boundaryIndex = text.index(text.startIndex, offsetBy: phrase.count)
        guard boundaryIndex < text.endIndex else { return true }

        let nextCharacter = text[boundaryIndex]
        return nextCharacter.isWhitespace || nextCharacter.isPunctuation
    }
}
