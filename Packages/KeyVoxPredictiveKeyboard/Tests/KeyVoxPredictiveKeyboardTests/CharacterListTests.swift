import XCTest
@testable import KeyVoxPredictiveKeyboard

final class CharacterListTests: XCTestCase {
    private let lettersAndDigits = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".map(String.init)

    func testLettersDigitsAndTheApostropheCarryTheWordOn() throws {
        let list = try CharacterList.wordEnding()
        for character in lettersAndDigits + [SmartQuotes.apostrophe] {
            XCTAssertFalse(list.contains(character), character)
        }
    }

    func testLettersAndDigitsFollowAPickedWordsSpace() throws {
        let list = try CharacterList.takingPickedWordSpace()
        for character in lettersAndDigits {
            XCTAssertFalse(list.contains(character), character)
        }
        XCTAssertTrue(list.contains(SmartQuotes.apostrophe))
    }
}
