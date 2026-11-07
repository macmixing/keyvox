import XCTest
@testable import KeyVoxLinguistics

final class GreetingPhrasesTests: XCTestCase {
    private var phrases: GreetingPhrases!

    override func setUpWithError() throws {
        phrases = try GreetingPhrases()
    }

    func testFindsPhraseAtStartOfText() {
        XCTAssertTrue(phrases.startsWithPhrase("Good morning everyone"))
        XCTAssertTrue(phrases.startsWithPhrase("Thank you so much for the help"))
        XCTAssertTrue(phrases.startsWithPhrase("Hey"))
        XCTAssertTrue(phrases.startsWithPhrase("See you tomorrow"))
    }

    func testIgnoresTextWithoutPhrase() {
        XCTAssertFalse(phrases.startsWithPhrase("As far as that's concerned"))
        XCTAssertFalse(phrases.startsWithPhrase("Highway traffic was slow"))
        XCTAssertFalse(phrases.startsWithPhrase("Okay, see you"))
    }
}
