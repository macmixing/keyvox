import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The bundled swipe lexicon is exactly the one the bundled dictionary, swipe vocabulary, and swipe
/// model build (`KeyVoxTypingHarness swipe-lexicon`), so a change to any of them cannot leave it
/// behind.
final class SwipeLexiconTests: XCTestCase {
    func testTheBundledLexiconIsTheOneTheDictionaryAndSwipeVocabularyBuild() throws {
        let language = TypingLanguage.english
        let built = try SwipeLexiconBuilder.fileData(
            words: try SwipeVocabulary.lexiconWords(of: PredictiveEngine(language: language)),
            settings: try SwipeModelSettings.bundled(for: language)
        )
        XCTAssertEqual(try Data(contentsOf: language.resources.url(SwipeLexiconFormat.fileName)), built)
    }
}
