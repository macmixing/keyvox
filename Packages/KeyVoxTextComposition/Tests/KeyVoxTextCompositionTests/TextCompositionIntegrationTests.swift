import XCTest
@testable import KeyVoxTextComposition

final class TextCompositionIntegrationTests: XCTestCase {
    func testCompositionJoinsBothEditorBoundaries() {
        let result = TextCompositionPolicy.composeForInsertion(
            text: "Middle",
            precedingContext: TextCompositionContext(precedingText: "left"),
            followingText: "right",
            preserveLeadingCapitalization: false
        )

        XCTAssertEqual(result.text, " middle ")
        XCTAssertFalse(result.shouldDeleteFollowingCodePoint)
    }

    func testCompositionRequestsDifferentFollowingPunctuationReplacement() {
        let result = TextCompositionPolicy.composeForInsertion(
            text: "Question?",
            precedingContext: TextCompositionContext(precedingText: "left"),
            followingText: ".right",
            preserveLeadingCapitalization: false
        )

        XCTAssertEqual(result.text, " question?")
        XCTAssertTrue(result.shouldDeleteFollowingCodePoint)
    }

    func testUnavailablePrecedingContextDoesNotGuessCapitalizationOrSpacing() {
        let result = TextCompositionPolicy.composeForInsertion(
            text: "Unchanged.",
            precedingContext: nil,
            followingText: nil,
            preserveLeadingCapitalization: false
        )

        XCTAssertEqual(result.text, "Unchanged.")
    }

    func testTruncatedWhitespaceContextIsNotDocumentStart() {
        let context = TextCompositionContext(
            precedingText: "   ",
            isAtDocumentStart: false
        )

        XCTAssertFalse(context.isAtDocumentStart)
        XCTAssertEqual(
            TextCompositionPolicy.composeForInsertion(
                text: "Continuation.",
                precedingContext: context,
                followingText: nil,
                preserveLeadingCapitalization: false
            ).text,
            "continuation."
        )
    }

    func testDictionaryPhrasePreservesLeadingCapitalizationAtSafeBoundary() {
        let phrases = ["KeyVox"]

        XCTAssertTrue(DictionaryLeadingCapitalizationPolicy.shouldPreserve(
            text: "KeyVox works.",
            dictionaryPhrases: phrases
        ))
        XCTAssertFalse(DictionaryLeadingCapitalizationPolicy.shouldPreserve(
            text: "KeyVoxian",
            dictionaryPhrases: phrases
        ))
    }
}
