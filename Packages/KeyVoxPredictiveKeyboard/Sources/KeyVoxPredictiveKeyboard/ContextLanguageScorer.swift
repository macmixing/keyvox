import Foundation

/// How likely a word is after the words before it, from the bundled n-gram counts.
///
/// Uses stupid backoff: an observed three-word sequence scores its own probability, an
/// observed pair scores its probability times the backoff factor, and otherwise the
/// word's overall frequency is used with the factor applied once per missing level. A
/// sequence the counts never saw therefore always scores below one they did see.
///
/// The user's personal words count as dictionary words and score at least as likely as
/// an everyday word, since the bundled counts usually have never seen them. A personal
/// word right after the word it follows in one of the user's phrases scores as one of the
/// likeliest next words.
public struct ContextLanguageScorer: Sendable {
    public struct Score: Sendable, Equatable {
        public let logProbability: Double
        public let isDictionaryWord: Bool
    }

    private static let backoffLogFactor = log(0.4)
    /// About one occurrence in ten thousand words: the frequency of an everyday word.
    private static let personalWordLogProbability = log(1e-4)
    /// One in ten: above all but the most common word pairs.
    private static let personalContinuationLogProbability = log(0.1)

    private let analyze: @Sendable (String, [String]) throws -> WordLanguageAnalysis
    private let vocabulary: PersonalVocabulary

    public init(engine: EnglishPredictiveEngine, vocabulary: PersonalVocabulary = .empty) {
        analyze = { word, previousWords in
            try engine.analyze(word: word, previousWords: previousWords)
        }
        self.vocabulary = vocabulary
    }

    /// Scores through any analysis source, such as a cache in front of the engine.
    public init(
        analyze: @escaping @Sendable (String, [String]) throws -> WordLanguageAnalysis,
        vocabulary: PersonalVocabulary = .empty
    ) {
        self.analyze = analyze
        self.vocabulary = vocabulary
    }

    /// - Parameter previousWords: Earlier words in the sentence, newest first.
    public func score(of word: String, previousWords: [String]) throws -> Score {
        let analysis = try analyze(word.lowercased(), previousWords)
        let logProbability: Double
        if previousWords.count >= 2, analysis.precedingTrigramObserved {
            logProbability = analysis.precedingTrigramLogProbability
        } else if previousWords.isEmpty == false, analysis.precedingPairObserved {
            logProbability = analysis.precedingLogProbability
                + (previousWords.count >= 2 ? Self.backoffLogFactor : 0)
        } else {
            let missingLevels = Double(min(previousWords.count, 2))
            logProbability = analysis.unigramLogProbability + missingLevels * Self.backoffLogFactor
        }
        guard vocabulary.contains(word) else {
            return Score(logProbability: logProbability, isDictionaryWord: analysis.wordIsValid)
        }
        let continuesPhrase = previousWords.first.map { vocabulary.continues($0, with: word) } ?? false
        return Score(
            logProbability: max(
                logProbability,
                continuesPhrase ? Self.personalContinuationLogProbability : Self.personalWordLogProbability
            ),
            isDictionaryWord: true
        )
    }
}
