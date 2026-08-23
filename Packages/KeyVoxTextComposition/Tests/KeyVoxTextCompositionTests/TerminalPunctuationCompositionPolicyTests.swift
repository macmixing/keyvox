import XCTest
@testable import KeyVoxTextComposition

final class TerminalPunctuationCompositionPolicyTests: XCTestCase {
    func testModelPeriodIsRemovedBeforeFollowingLowercaseLetter() {
        for testCase in [
            (followingCharacter: Character("a"), followingNonWhitespaceCharacter: Character("a")),
            (followingCharacter: Character(" "), followingNonWhitespaceCharacter: Character("m")),
            (followingCharacter: Character("\t"), followingNonWhitespaceCharacter: Character("é")),
        ] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "still working.",
                followingCharacter: testCase.followingCharacter,
                followingNonWhitespaceCharacter: testCase.followingNonWhitespaceCharacter
            )

            XCTAssertEqual(result.text, "still working")
            XCTAssertFalse(result.shouldReplaceFollowingPunctuation)
        }
    }

    func testModelPeriodIsPreservedBeforeNonLowercaseContent() {
        for followingCharacter in [Character("A"), Character("2"), Character("😎")] {
            let result = TerminalPunctuationCompositionPolicy.resolve(
                text: "still working.",
                followingCharacter: followingCharacter
            )

            XCTAssertEqual(result.text, "still working.")
            XCTAssertFalse(result.shouldReplaceFollowingPunctuation)
        }
    }

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
