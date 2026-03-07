import Foundation
import XCTest
@testable import KeyVoxCore

final class ReplacementScorerTests: XCTestCase {
    func testThresholdsMatchBalancedPolicy() {
        let scorer = ReplacementScorer.balanced
        XCTAssertTrue(scorer.threshold(for: 1) == 0.90)
        XCTAssertTrue(scorer.threshold(for: 2) == 0.80)
        XCTAssertTrue(scorer.threshold(for: 3) == 0.78)
        XCTAssertTrue(scorer.threshold(for: 4) == 0.78)
    }

    func testAmbiguityMarginIsConfigured() {
        let scorer = ReplacementScorer.balanced
        XCTAssertTrue(scorer.ambiguityMargin == 0.05)
        XCTAssertTrue(scorer.commonWordOverrideThreshold == 0.94)
    }

    func testSimilarityReturnsOneForExactAndLessForNearMatch() {
        let scorer = ReplacementScorer.balanced
        XCTAssertTrue(scorer.similarity(lhs: "esposito", rhs: "esposito") == 1)
        XCTAssertTrue(scorer.similarity(lhs: "espicito", rhs: "esposito") < 1)
    }

    func testScoreBlendsTextPhoneticAndContext() {
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

        XCTAssertTrue(withContext.final > withoutContext.final)
    }
}
