import XCTest
@testable import KeyVoxLinguistics

final class ExamplePhrasesTests: XCTestCase {
    private var phrases: ExamplePhrases!

    override func setUpWithError() throws {
        phrases = try ExamplePhrases()
    }

    func testFindsPhraseAtEndOfText() {
        XCTAssertTrue(phrases.endsWithPhrase("Bring snacks such as"))
        XCTAssertTrue(phrases.endsWithPhrase("We visited cities like"))
        XCTAssertTrue(phrases.endsWithPhrase("Some fruit, for instance"))
        XCTAssertTrue(phrases.endsWithPhrase("Pack a few things, e.g."))
    }

    func testIgnoresTextWithoutPhrase() {
        XCTAssertFalse(phrases.endsWithPhrase("Let's pick between"))
        XCTAssertFalse(phrases.endsWithPhrase("Like the others, we left"))
        XCTAssertFalse(phrases.endsWithPhrase("I unlike"))
        XCTAssertFalse(phrases.endsWithPhrase(""))
    }
}
