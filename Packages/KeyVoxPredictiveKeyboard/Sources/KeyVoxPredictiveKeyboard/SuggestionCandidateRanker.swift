import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Ranks words to offer while a word is still being typed.
///
/// Completions and corrections compete on one score: `languageWeight × log P(word |
/// context)` minus the cost of the touches so far as the start of the word. A completion
/// whose beginning matches the taps costs little; a correction pays for every tap it
/// disagrees with.
public struct SuggestionCandidateRanker: Sendable {
    public struct RankedWord: Sendable, Equatable {
        public let word: String
        public let score: Double
    }

    public let parameters: NoisyChannelCorrector.Parameters
    private let language: ContextLanguageScorer
    private let touchScorer: TouchAlignmentScorer

    public init(
        parameters: NoisyChannelCorrector.Parameters,
        keys: KeyCenterMap,
        language: ContextLanguageScorer
    ) {
        self.parameters = parameters
        self.language = language
        touchScorer = TouchAlignmentScorer(keys: keys, parameters: parameters.touch)
    }

    /// Every distinct candidate other than the typed letters, best first.
    public func rank(
        typedWord: String,
        touches: [CGPoint],
        previousWords: [String],
        candidates: [String]
    ) throws -> [RankedWord] {
        let typed = typedWord.lowercased()
        let aimedTouches = touches.count == typed.count
            ? touches
            : touchScorer.centerTouches(for: typed)
        var observed: Set<String> = [typed]
        var ranked: [RankedWord] = []
        for candidate in candidates {
            guard observed.insert(candidate.lowercased()).inserted else { continue }
            let languageScore = try language.score(of: candidate, previousWords: previousWords)
            guard languageScore.isDictionaryWord else { continue }
            let touchCost = touchScorer.prefixCost(of: aimedTouches, typing: candidate)
            ranked.append(RankedWord(
                word: candidate,
                score: parameters.languageWeight * languageScore.logProbability - touchCost
            ))
        }
        return ranked.sorted { $0.score > $1.score }
    }

    /// Next-word candidates ordered by context likelihood alone.
    public func rankNextWords(previousWords: [String], candidates: [String]) throws -> [RankedWord] {
        var observed: Set<String> = []
        var ranked: [RankedWord] = []
        for candidate in candidates where observed.insert(candidate.lowercased()).inserted {
            let languageScore = try language.score(of: candidate, previousWords: previousWords)
            ranked.append(RankedWord(word: candidate, score: languageScore.logProbability))
        }
        return ranked.sorted { $0.score > $1.score }
    }
}
