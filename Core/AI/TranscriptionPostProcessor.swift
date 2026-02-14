import Foundation

@MainActor
final class TranscriptionPostProcessor {
    private let vocabularyNormalizer = CustomVocabularyNormalizer()

    func process(_ text: String, dictionaryEntries: [DictionaryEntry]) -> String {
        guard !text.isEmpty else { return "" }

        let normalized = vocabularyNormalizer.normalize(text, with: dictionaryEntries)
        return normalized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
