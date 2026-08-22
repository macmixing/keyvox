import XCTest
@testable import KeyVoxTextComposition

final class TerminalPunctuationCompositionPolicyTests: XCTestCase {
    func testModelPeriodIsRemovedBeforeExistingPunctuation() {
        for existingPunctuation in [
            Character("."), Character("?"), Character("!"),
            Character(","), Character(";"), Character(":"),
            Character(")"), Character("—"), Character("…"),
        ] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "working.",
                followingCharacter: existingPunctuation
            )

            XCTAssertEqual(result.text, "working")
            XCTAssertFalse(result.shouldReplaceFollowingPunctuation)
        }
    }

    func testIncomingQuestionMarkReplacesDifferentExistingPunctuation() {
        for existingPunctuation in [
            Character("."), Character("!"), Character(","),
            Character(";"), Character(":"), Character(")"),
            Character("—"), Character("…"),
        ] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "working?",
                followingCharacter: existingPunctuation
            )

            XCTAssertEqual(result.text, "working?")
            XCTAssertTrue(result.shouldReplaceFollowingPunctuation)
        }
    }

    func testIncomingExclamationMarkReplacesDifferentExistingPunctuation() {
        for existingPunctuation in [
            Character("."), Character("?"), Character(","),
            Character(";"), Character(":"), Character(")"),
            Character("—"), Character("…"),
        ] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "working!",
                followingCharacter: existingPunctuation
            )

            XCTAssertEqual(result.text, "working!")
            XCTAssertTrue(result.shouldReplaceFollowingPunctuation)
        }
    }

    func testMatchingExplicitTerminalPunctuationUsesExistingCharacter() {
        for punctuation in [Character("?"), Character("!")] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "working\(punctuation)",
                followingCharacter: punctuation
            )

            XCTAssertEqual(result.text, "working")
            XCTAssertFalse(result.shouldReplaceFollowingPunctuation)
        }
    }

    func testLeavesIncomingPeriodBeforeQuotationMark() {
        for quotationMark in [
            Character("\""), Character("'"), Character("“"),
            Character("”"), Character("‘"), Character("’"),
        ] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "working.",
                followingCharacter: quotationMark
            )

            XCTAssertEqual(result.text, "working.")
            XCTAssertFalse(result.shouldReplaceFollowingPunctuation)
        }
    }

    func testLeavesTextUnchangedWithoutAdjacentTerminalPunctuation() {
        let result = TerminalPunctuationCompositionPolicy.resolve(
            text: "working.",
            followingCharacter: " "
        )

        XCTAssertEqual(result.text, "working.")
        XCTAssertFalse(result.shouldReplaceFollowingPunctuation)
    }
}
