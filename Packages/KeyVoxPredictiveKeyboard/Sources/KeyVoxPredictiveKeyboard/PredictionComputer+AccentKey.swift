import Foundation

extension PredictionComputer {
    /// How many of the likeliest words beginning with an elided word the accent key looks
    /// through for one that is not a name.
    private static let accentKeyWordsChecked = 32

    /// What the typing language's accent key shows and types after `textBeforeCursor`
    /// (`AccentKey.mark(after:dictionary:)`), choosing by the words the dictionary knows; nil in a
    /// language without one.
    public func accentKeyMark(after textBeforeCursor: String?) -> String? {
        guard let accentKey = engine.language.accentKey else { return nil }
        let dictionary = AccentKey.Dictionary(
            wordProbability: { [engine] word in
                guard let analysis = try? engine.analyze(word: word), analysis.wordIsValid else { return nil }
                return analysis.unigramLogProbability
            },
            beginsWords: { [engine] prefix in
                let words = (try? engine.likeliestWords(startingWith: prefix, limit: Self.accentKeyWordsChecked)) ?? []
                return words.contains { engine.capitalizedSpellings.spelling(of: $0) == nil }
            }
        )
        return accentKey.mark(after: textBeforeCursor, dictionary: dictionary)
    }
}
