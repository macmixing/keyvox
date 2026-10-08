import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Reads a typed word as two words whose space was missed, each possibly mistyped
/// ("probalywroks" for "probably works").
///
/// The engine's search already proposes such readings, placing the missed space and
/// forgiving near misses on both sides of it together. Each reading is scored the way a
/// one-word correction is: how well the two words, typed with no space between them, fit
/// the touches, how likely the first word is in context, and how likely the second word is
/// after the first. The best reading replaces the typed word only when it clearly beats
/// every one-word candidate and fits nearly as well as the typed letters themselves; a
/// reading that also corrects letters gets more room the longer the typed word is.
struct MissingSpaceCorrector {
    struct Split: Equatable {
        let left: String
        let right: String
        let score: Double
    }

    private let parameters: NoisyChannelCorrector.Parameters
    private let language: ContextLanguageScorer
    private let touchScorer: TouchAlignmentScorer

    init(
        parameters: NoisyChannelCorrector.Parameters,
        keys: KeyCenterMap,
        language: ContextLanguageScorer
    ) {
        self.parameters = parameters
        self.language = language
        touchScorer = TouchAlignmentScorer(keys: keys, parameters: parameters.touch)
    }

    /// The two words the typed word was meant as, or nil to leave it to the one-word decision.
    /// - Parameters:
    ///   - readings: The engine's two-word suggestions for the typed letters, each "left right".
    ///   - touches: One touch per typed letter, or empty to aim at the typed keys' centers.
    ///   - previousWords: Earlier words in the sentence, newest first.
    ///   - decision: The one-word decision for the same typed word.
    func split(
        of readings: [String],
        touches: [CGPoint],
        previousWords: [String],
        decision: NoisyChannelCorrector.Decision
    ) throws -> Split? {
        let typed = decision.typed.word
        guard let best = try bestReading(
            of: readings,
            typed: typed,
            touches: touches,
            previousWords: previousWords
        ) else { return nil }
        let bestOneWordScore = decision.rankedAlternatives.first?.score ?? -.infinity
        let correctionMargin = best.left + best.right == typed
            ? parameters.missingSpaceCorrectionMargin
            : parameters.correctedMissingSpaceCorrectionMargin
                - parameters.correctedMissingSpaceMarginPerLetter * Double(typed.count)
        guard best.score - bestOneWordScore >= parameters.missingSpaceMargin,
              best.score - decision.typed.score >= correctionMargin else { return nil }
        return best
    }

    /// The best-scoring reading that is two dictionary words.
    private func bestReading(
        of readings: [String],
        typed: String,
        touches: [CGPoint],
        previousWords: [String]
    ) throws -> Split? {
        let aimedTouches = touches.count == typed.count
            ? touches
            : touchScorer.centerTouches(for: typed)
        var best: Split?
        for reading in readings {
            let words = reading.split(separator: " ").map(String.init)
            guard words.count == 2 else { continue }
            let (left, right) = (words[0], words[1])
            let leftScore = try language.score(of: left, previousWords: previousWords)
            let rightScore = try language.score(of: right, previousWords: [left] + previousWords)
            guard leftScore.isDictionaryWord, rightScore.isDictionaryWord else { continue }
            let score = parameters.languageWeight * (leftScore.logProbability + rightScore.logProbability)
                - touchScorer.cost(of: aimedTouches, typing: left + right)
            if score > best?.score ?? -.infinity {
                best = Split(left: left, right: right, score: score)
            }
        }
        return best
    }
}
