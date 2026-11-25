import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The bundled swipe lexicon is exactly the one the bundled dictionary and swipe model build
/// (`KeyVoxTypingHarness swipe-lexicon`), so a dictionary or model change cannot leave it behind.
final class SwipeLexiconTests: XCTestCase {
    func testTheBundledLexiconIsTheOneTheDictionaryBuilds() throws {
        let language = TypingLanguage.english
        let built = try SwipeLexiconBuilder.fileData(
            words: try PredictiveEngine(language: language).dictionaryWords(),
            settings: try SwipeModelSettings.bundled(for: language)
        )
        XCTAssertEqual(try Data(contentsOf: language.resources.url(SwipeLexiconFormat.fileName)), built)
    }
}
