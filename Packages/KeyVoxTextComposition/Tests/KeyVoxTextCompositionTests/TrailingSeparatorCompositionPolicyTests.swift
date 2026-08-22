import XCTest
@testable import KeyVoxTextComposition

final class TrailingSeparatorCompositionPolicyTests: XCTestCase {
    func testAddsSeparatorBeforeFollowingWordNumberOrEmoji() {
        for testCase in [
            (text: "What's up?", followingCharacter: Character("T"), expected: "What's up? "),
            (text: "That's awesome.", followingCharacter: Character("Y"), expected: "That's awesome. "),
            (text: "definitely", followingCharacter: Character("a"), expected: "definitely "),
            (text: "Version", followingCharacter: Character("2"), expected: "Version "),
            (text: "Nice", followingCharacter: Character("😎"), expected: "Nice "),
            (text: "Great", followingCharacter: Character("❤️"), expected: "Great "),
        ] {
            XCTAssertEqual(
                TrailingSeparatorCompositionPolicy.applyIfNeeded(
                    to: testCase.text,
                    followingCharacter: testCase.followingCharacter
                ),
                testCase.expected
            )
        }
    }

    func testDoesNotAddSeparatorBeforeFollowingPunctuation() {
        for punctuation in [
            Character("."), Character(","), Character("?"), Character("!"),
            Character(":"), Character(";"), Character(")"), Character("—"),
            Character("…"), Character("\""), Character("”"),
        ] {
            XCTAssertEqual(
                TrailingSeparatorCompositionPolicy.applyIfNeeded(
                    to: "word",
                    followingCharacter: punctuation
                ),
                "word"
            )
        }
    }

    func testDoesNotAddSeparatorWhenWhitespaceOrNoTextFollows() {
        for followingCharacter in [Character(" "), Character("\n"), Character("\t")] {
            XCTAssertEqual(
                TrailingSeparatorCompositionPolicy.applyIfNeeded(
                    to: "word",
                    followingCharacter: followingCharacter
                ),
                "word"
            )
        }

        XCTAssertEqual(
            TrailingSeparatorCompositionPolicy.applyIfNeeded(
                to: "word",
                followingCharacter: nil
            ),
            "word"
        )
    }

    func testDoesNotDuplicateExistingTrailingWhitespace() {
        XCTAssertEqual(
            TrailingSeparatorCompositionPolicy.applyIfNeeded(
                to: "word ",
                followingCharacter: "f"
            ),
            "word "
        )
    }
}
