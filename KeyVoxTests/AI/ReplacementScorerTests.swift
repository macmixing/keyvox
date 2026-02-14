import Foundation
import Testing
@testable import KeyVox

struct ReplacementScorerTests {
    @Test
    func thresholdsMatchBalancedPolicy() {
        let scorer = ReplacementScorer.balanced
        #expect(scorer.threshold(for: 1) == 0.90)
        #expect(scorer.threshold(for: 2) == 0.80)
        #expect(scorer.threshold(for: 3) == 0.78)
        #expect(scorer.threshold(for: 4) == 0.78)
    }

    @Test
    func ambiguityMarginIsConfigured() {
        let scorer = ReplacementScorer.balanced
        #expect(scorer.ambiguityMargin == 0.05)
        #expect(scorer.commonWordOverrideThreshold == 0.94)
    }

    @Test
    func similarityReturnsOneForExactAndLessForNearMatch() {
        let scorer = ReplacementScorer.balanced
        #expect(scorer.similarity(lhs: "esposito", rhs: "esposito") == 1)
        #expect(scorer.similarity(lhs: "espicito", rhs: "esposito") < 1)
    }

    @Test
    func scoreBlendsTextPhoneticAndContext() {
        let scorer = ReplacementScorer.balanced
        let withContext = scorer.score(
            observedText: "dom espicito",
            observedPhonetic: "D N ESPST",
            candidateText: "dom esposito",
            candidatePhonetic: "D N ESPST",
            previousToken: "hi",
            nextToken: "today"
        )

        let withoutContext = scorer.score(
            observedText: "dom espicito",
            observedPhonetic: "D N ESPST",
            candidateText: "dom esposito",
            candidatePhonetic: "D N ESPST",
            previousToken: nil,
            nextToken: nil
        )

        #expect(withContext.final > withoutContext.final)
    }
}
