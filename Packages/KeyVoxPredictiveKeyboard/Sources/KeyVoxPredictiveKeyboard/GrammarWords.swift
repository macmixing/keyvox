import Foundation

/// The grammar words every sentence repeats ("the", "and", "of"): the determiners, pronouns,
/// prepositions, conjunctions, and particles among the most common words. The list is written by
/// Tools/KeyVoxLanguageModel/write_grammar_words.py, one word per line.
public struct GrammarWords: Sendable {
    private let words: Set<String>

    public init(contentsOf url: URL) throws {
        words = Set(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init))
    }

    /// Whether `word` is a grammar word, compared the way personal words are.
    public func contains(_ word: String) -> Bool {
        words.contains(PersonalVocabulary.key(word))
    }
}
