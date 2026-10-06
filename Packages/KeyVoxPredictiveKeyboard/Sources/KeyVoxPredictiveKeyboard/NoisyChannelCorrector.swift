import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Ranks what the user meant to type by combining where their fingers landed with how
/// likely each word is in context, and decides whether space should replace the typed
/// word.
///
/// A candidate's score is `languageWeight × log P(word | context) − touch cost`. The typed
/// word competes as itself; space replaces it only when another word beats it by the
/// correction margin (a larger margin when the typed word is itself a dictionary word).
public struct NoisyChannelCorrector: Sendable {
    public struct Parameters: Sendable, Equatable {
        public var touch: TouchAlignmentScorer.Parameters
        public var languageWeight: Double
        /// Extra log-probability penalty for a typed word the dictionary does not know.
        public var unknownWordPenalty: Double
        public var correctionMargin: Double
        public var dictionaryWordCorrectionMargin: Double

        public init(
            touch: TouchAlignmentScorer.Parameters,
            languageWeight: Double,
            unknownWordPenalty: Double,
            correctionMargin: Double,
            dictionaryWordCorrectionMargin: Double
        ) {
            self.touch = touch
            self.languageWeight = languageWeight
            self.unknownWordPenalty = unknownWordPenalty
            self.correctionMargin = correctionMargin
            self.dictionaryWordCorrectionMargin = dictionaryWordCorrectionMargin
        }
    }

    public static let standardParameters = Parameters(
        touch: TouchAlignmentScorer.Parameters(
            touchStandardDeviation: 0.4,
            extraTouchCost: 4,
            skippedLetterCost: 4,
            skippedRepeatedLetterCost: 1.5,
            swappedLettersCost: 3
        ),
        languageWeight: 1,
        unknownWordPenalty: 3,
        correctionMargin: 1,
        dictionaryWordCorrectionMargin: 8
    )

    public struct ScoredCandidate: Sendable, Equatable {
        public let word: String
        public let touchCost: Double
        public let language: ContextLanguageScorer.Score
        public let score: Double
    }

    public struct Decision: Sendable, Equatable {
        /// What space should insert instead of the typed word, if anything.
        public let replacement: String?
        /// Every candidate other than the typed word, best first.
        public let rankedAlternatives: [ScoredCandidate]
        public let typed: ScoredCandidate
    }

    public let parameters: Parameters
    private let language: ContextLanguageScorer
    private let touchScorer: TouchAlignmentScorer

    public init(parameters: Parameters, keys: KeyCenterMap, language: ContextLanguageScorer) {
        self.parameters = parameters
        self.language = language
        touchScorer = TouchAlignmentScorer(keys: keys, parameters: parameters.touch)
    }

    /// - Parameters:
    ///   - touches: One touch per typed letter, or empty to aim at the typed keys' centers.
    ///   - previousWords: Earlier words in the sentence, newest first.
    ///   - candidates: Words the engine proposed for the typed letters.
    public func decide(
        typedWord: String,
        touches: [CGPoint],
        previousWords: [String],
        candidates: [String]
    ) throws -> Decision {
        let typed = typedWord.lowercased()
        let aimedTouches = touches.count == typed.count
            ? touches
            : touchScorer.centerTouches(for: typed)
        let typedCandidate = try scored(typed, touches: aimedTouches, previousWords: previousWords)

        var observed: Set<String> = [typed]
        var alternatives: [ScoredCandidate] = []
        for candidate in candidates {
            guard observed.insert(candidate.lowercased()).inserted else { continue }
            alternatives.append(try scored(candidate, touches: aimedTouches, previousWords: previousWords))
        }
        alternatives.sort { $0.score > $1.score }

        let margin = typedCandidate.language.isDictionaryWord
            ? parameters.dictionaryWordCorrectionMargin
            : parameters.correctionMargin
        let replacement = alternatives.first.flatMap { best in
            typed.count >= 2 && best.score - typedCandidate.score >= margin ? best.word : nil
        }
        return Decision(
            replacement: replacement,
            rankedAlternatives: alternatives,
            typed: typedCandidate
        )
    }

    private func scored(
        _ word: String,
        touches: [CGPoint],
        previousWords: [String]
    ) throws -> ScoredCandidate {
        let languageScore = try language.score(of: word, previousWords: previousWords)
        let touchCost = touchScorer.cost(of: touches, typing: word)
        let penalty = languageScore.isDictionaryWord ? 0 : parameters.unknownWordPenalty
        return ScoredCandidate(
            word: word,
            touchCost: touchCost,
            language: languageScore,
            score: parameters.languageWeight * (languageScore.logProbability - penalty) - touchCost
        )
    }
}
