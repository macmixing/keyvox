import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Ranks what the user meant to type by combining where their fingers landed with how
/// likely each word is in context, and decides whether space should replace the typed
/// word.
///
/// A candidate's score is `languageWeight × log P(word | context) − touch cost`. The typed
/// word competes as itself. A typed word the dictionary does not know is replaced by the
/// best candidate, as the system keyboard replaces it, unless that candidate fits far worse
/// than the typed letters themselves; a dictionary word only when another word beats it by
/// the dictionary word margin, and a word known only from everyday use by the smaller
/// everyday word margin.
///
/// Once the next word is known, a word left as typed can be reconsidered: each candidate
/// then also scores how likely the next word is after it, and replaces the typed word only
/// by the revision margin.
public struct NoisyChannelCorrector: Sendable {
    public struct Parameters: Sendable, Equatable {
        public var touch: TouchAlignmentScorer.Parameters
        public var languageWeight: Double
        /// Extra log-probability penalty for a typed word the dictionary does not know.
        public var unknownWordPenalty: Double
        /// The margin a candidate needs over a typed word the dictionary does not know; below
        /// zero, so a somewhat worse fit still replaces it.
        public var correctionMargin: Double
        public var dictionaryWordCorrectionMargin: Double
        /// The margin over a typed word the dictionary lacks but the counts show in everyday
        /// use, such as "wtf", which common misspellings like "teh" also reach.
        public var everydayWordCorrectionMargin: Double
        /// The margin for restoring only an apostrophe ("im" to "i'm"), which applies even
        /// when the typed letters happen to spell a dictionary word ("ill", "were").
        public var apostropheRestorationMargin: Double
        /// The margin for replacing a finished word once the word after it is known.
        public var revisionMargin: Double

        public init(
            touch: TouchAlignmentScorer.Parameters,
            languageWeight: Double,
            unknownWordPenalty: Double,
            correctionMargin: Double,
            dictionaryWordCorrectionMargin: Double,
            everydayWordCorrectionMargin: Double,
            apostropheRestorationMargin: Double,
            revisionMargin: Double
        ) {
            self.touch = touch
            self.languageWeight = languageWeight
            self.unknownWordPenalty = unknownWordPenalty
            self.correctionMargin = correctionMargin
            self.dictionaryWordCorrectionMargin = dictionaryWordCorrectionMargin
            self.everydayWordCorrectionMargin = everydayWordCorrectionMargin
            self.apostropheRestorationMargin = apostropheRestorationMargin
            self.revisionMargin = revisionMargin
        }
    }

    public static let standardParameters = Parameters(
        touch: TouchAlignmentScorer.Parameters(
            touchStandardDeviation: 0.4,
            extraTouchCost: 6,
            skippedLetterCost: 4,
            skippedRepeatedLetterCost: 2,
            swappedLettersCost: 6
        ),
        languageWeight: 0.8,
        unknownWordPenalty: 0,
        correctionMargin: -10,
        dictionaryWordCorrectionMargin: 4,
        everydayWordCorrectionMargin: 2,
        apostropheRestorationMargin: 1,
        revisionMargin: 2
    )

    public struct ScoredCandidate: Sendable, Equatable {
        public let word: String
        public let touchCost: Double
        public let language: ContextLanguageScorer.Score
        public let score: Double
    }

    public struct Decision: Sendable, Equatable {
        /// What should replace the typed word, if anything.
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
    ///   - followingWord: The word typed after this one, when reconsidering a finished word.
    ///   - candidates: Words the engine proposed for the typed letters.
    public func decide(
        typedWord: String,
        touches: [CGPoint],
        previousWords: [String],
        followingWord: String? = nil,
        candidates: [String]
    ) throws -> Decision {
        let typed = typedWord.lowercased()
        let aimedTouches = touches.count == typed.count
            ? touches
            : touchScorer.centerTouches(for: typed)
        let typedCandidate = try scored(
            typed,
            touches: aimedTouches,
            previousWords: previousWords,
            followingWord: followingWord
        )

        var observed: Set<String> = [typed]
        var alternatives: [ScoredCandidate] = []
        for candidate in candidates {
            guard observed.insert(candidate.lowercased()).inserted else { continue }
            alternatives.append(try scored(
                candidate,
                touches: aimedTouches,
                previousWords: previousWords,
                followingWord: followingWord
            ))
        }
        alternatives.sort { $0.score > $1.score }

        let replacement = alternatives.first.flatMap { best in
            let margin = followingWord == nil
                ? margin(for: best, typed: typedCandidate)
                : parameters.revisionMargin
            return typed.count >= 2 && best.score - typedCandidate.score >= margin ? best.word : nil
        }
        return Decision(
            replacement: replacement,
            rankedAlternatives: alternatives,
            typed: typedCandidate
        )
    }

    private func margin(for best: ScoredCandidate, typed: ScoredCandidate) -> Double {
        if best.word.lowercased().replacingOccurrences(of: "'", with: "") == typed.word {
            return parameters.apostropheRestorationMargin
        }
        if typed.language.isEverydayWord {
            return parameters.everydayWordCorrectionMargin
        }
        return typed.language.isDictionaryWord
            ? parameters.dictionaryWordCorrectionMargin
            : parameters.correctionMargin
    }

    private func scored(
        _ word: String,
        touches: [CGPoint],
        previousWords: [String],
        followingWord: String?
    ) throws -> ScoredCandidate {
        let languageScore = try language.score(of: word, previousWords: previousWords)
        let followingLogProbability = try followingWord.map {
            try language.score(of: $0, previousWords: [word] + previousWords).logProbability
        } ?? 0
        let touchCost = touchScorer.cost(of: touches, typing: word)
        let penalty = languageScore.isDictionaryWord ? 0 : parameters.unknownWordPenalty
        let logProbability = languageScore.logProbability + followingLogProbability - penalty
        return ScoredCandidate(
            word: word,
            touchCost: touchCost,
            language: languageScore,
            score: parameters.languageWeight * logProbability - touchCost
        )
    }
}
