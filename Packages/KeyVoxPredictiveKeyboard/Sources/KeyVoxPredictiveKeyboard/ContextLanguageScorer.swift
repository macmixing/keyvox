import Foundation

/// How likely a word is after the words before it, from the bundled n-gram counts.
///
/// Uses stupid backoff: an observed three-word sequence scores its own probability, an
/// observed pair scores its probability times the backoff factor, and otherwise the
/// word's overall frequency is used with the factor applied once per missing level. A
/// sequence the counts never saw therefore always scores below one they did see.
public struct ContextLanguageScorer: Sendable {
    public struct Score: Sendable, Equatable {
        public let logProbability: Double
        public let isDictionaryWord: Bool
    }

    private static let backoffLogFactor = log(0.4)

    private let analyze: @Sendable (String, [String]) throws -> WordLanguageAnalysis

    public init(engine: EnglishPredictiveEngine) {
        analyze = { word, previousWords in
            try engine.analyze(word: word, previousWords: previousWords)
        }
    }

    /// Scores through any analysis source, such as a cache in front of the engine.
    public init(analyze: @escaping @Sendable (String, [String]) throws -> WordLanguageAnalysis) {
        self.analyze = analyze
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
        return Score(logProbability: logProbability, isDictionaryWord: analysis.wordIsValid)
    }
}
