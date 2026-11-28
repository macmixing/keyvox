import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// French (Canada)'s rules, as Apple's French (Canada) keyboard was measured typing them on
/// iOS 27.2 (`~/KeyVoxLanguageData/apple-languages`), with France's dictionary and models.
final class FrenchCanadaTypingLanguageTests: XCTestCase {
    private let language = TypingLanguage.frenchCanada

    func testFrenchCanadaShowsQwertyAccentsAndOffersApplesOtherLayoutsInOrder() throws {
        XCTAssertEqual(language.identifier, "fr-CA")
        XCTAssertEqual(language.letterLayout.identifier, "QWERTY-Accents")
        XCTAssertEqual(language.alternativeLetterLayouts, ["QWERTY", "AZERTY", "QWERTZ"])
        for identifier in language.alternativeLetterLayouts {
            XCTAssertEqual(try LetterKeyLayout.bundled(identifier: identifier).identifier, identifier)
        }
    }

    func testItTypesWithFrancesDictionaryAndModelsAndItsOwnRules() throws {
        XCTAssertEqual(try language.resources.dataIdentifier(ofDirectory: "dictionary"), "fr")
        XCTAssertEqual(
            try language.resources.dataURL("context_model.bin"),
            try TypingLanguage.french.resources.dataURL("context_model.bin")
        )
        XCTAssertEqual(try language.resources.url("held_key_characters.txt").deletingLastPathComponent().lastPathComponent, "fr-CA")
        let computer = PredictionComputer(engine: try PredictiveEngine(language: language))
        let session = PredictiveTypingSession(language: language)
        let result = try computer.compute(session.request(textBeforeCursor: "Bonjou"))
        XCTAssertTrue(result.bar.items.contains { $0.text == "Bonjour" })
    }

    func testAPickedWordLosesItsSpaceBeforeTheMarksAppleTypesAgainstIt() {
        // `Bonj`, the bar's `Bonjour`, then `?` → `Bonjour?`, where France keeps `Bonjour ?`.
        for (separator, deleteCount) in [("?", 1), ("!", 1), (":", 1), (";", 1), ("-", 1), ("/", 1), (".", 1), (",", 1)] {
            XCTAssertEqual(pickedWordEdit(in: language, separator: separator), deleteCount, separator)
        }
        XCTAssertEqual(pickedWordEdit(in: .french, separator: "?"), 0)
    }

    func testTheAccentKeyTypesWhatAppleTypedAfterEachText() throws {
        try FrenchAccentKeyTests.assertAccentKeyTypesWhatAppleTyped(in: language)
    }

    func testTheAccentKeysPopupDrawsAsApplesFrenchCanadaKeyboardDrewIt() throws {
        // The key at the end of QWERTY-Accents' second row on a 440-point-wide iPhone.
        let offer = try XCTUnwrap(try HeldKeyCharacters.bundled(for: language).offer(forKey: "´"))
        let layout = HeldKeyPopupLayout(
            offer: offer,
            keyFrame: CGRect(x: 394.33, y: 63, width: 43.33, height: 56),
            bounds: CGRect(x: 0, y: 0, width: 440, height: 245),
            metrics: HeldKeyPopupLayout.Metrics(cellWidth: 41.23, cellHeight: 47, padding: 10.2, gapAboveKey: 4.4, closingDistance: 87.8)
        )
        XCTAssertEqual(layout.rows.flatMap { $0.map(\.character) }.joined(separator: " "), "¨ ˆ ˋ ´")
    }

    func testTheWebEndingKeyOffersApplesFrenchCanadaEndingsInAUSRegion() throws {
        let offer = try XCTUnwrap(try WebEndings.bundled().offer(region: "US", preferredLanguages: ["en-US"], languages: [language]))
        XCTAssertEqual(offer.ending, ".com")
        XCTAssertEqual(offer.held.characters, [".ca", ".us", ".edu", ".com", ".net", ".org"])
    }

    /// How many characters the separator's edit deletes after `Bonj` and the bar's `Bonjour`.
    private func pickedWordEdit(in language: TypingLanguage, separator: String) -> Int {
        let session = PredictiveTypingSession(language: language)
        let typed = "Bonj"
        let edit = session.choiceEdit(SuggestionBar.Item(text: "Bonjour", kind: .suggestion), textBeforeCursor: typed)
        let text = String(typed.dropLast(edit.deleteCount)) + edit.insertText
        return session.wordBoundaryEdit(separator: separator, textBeforeCursor: text, result: nil).deleteCount
    }
}
