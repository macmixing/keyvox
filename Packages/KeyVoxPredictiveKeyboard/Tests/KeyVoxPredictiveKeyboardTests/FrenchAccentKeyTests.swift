import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The AZERTY-French accent key as Apple's French (France) keyboard was measured driving it on
/// iOS 27.2: what tapping it types after each text, and what its popup's marks do.
final class FrenchAccentKeyTests: XCTestCase {
    private let accentKey = TypingLanguage.french.accentKey!

    func testWithNoLetterBeforeTheCursorTheKeyTypesItsOwnCharacter() {
        for text in [nil, "", "1", ".", "Et "] {
            XCTAssertEqual(accentKey.mark(after: text), "´", String(describing: text))
            XCTAssertNil(accentKey.edit(placing: "´", after: text), String(describing: text))
        }
    }

    func testAfterAVowelTheKeyPutsTheLettersUsualMarkOnIt() {
        // `e` → `é`, `a` → `à`, `i` → `î`, `o` → `ô`, `u` → `û`.
        for (text, mark, marked) in [("e", "´", "é"), ("a", "ˋ", "à"), ("i", "ˆ", "î"), ("o", "ˆ", "ô"), ("u", "ˆ", "û"), ("E", "´", "É")] {
            XCTAssertEqual(accentKey.mark(after: text), mark, text)
            XCTAssertEqual(accentKey.edit(placing: mark, after: text), TextEdit(deleteCount: 1, insertText: marked), text)
        }
    }

    func testAfterALetterNoMarkGoesOnTheKeyIsTheApostrophe() {
        for text in ["y", "l", "Et"] {
            XCTAssertEqual(accentKey.mark(after: text), SmartQuotes.apostrophe, text)
        }
    }

    func testThePopupsMarksGoOnTheLetterBeforeTheCursor() {
        // Held after `e`: `ë`, `ê`, `è`, `é`.
        for (mark, marked) in [("¨", "ë"), ("ˆ", "ê"), ("ˋ", "è"), ("´", "é")] {
            XCTAssertEqual(accentKey.edit(placing: mark, after: "e"), TextEdit(deleteCount: 1, insertText: marked), mark)
        }
    }

    func testTheKeyTypesWhatAppleTypedAfterEachText() throws {
        try Self.assertAccentKeyTypesWhatAppleTyped(in: .french)
    }

    /// What Apple's French (France) keyboard on AZERTY-French, and its French (Canada) keyboard on
    /// QWERTY-Accents, typed with the accent key after each text, measured the same on both.
    static func assertAccentKeyTypesWhatAppleTyped(in language: TypingLanguage) throws {
        let accentKey = try XCTUnwrap(language.accentKey)
        let computer = PredictionComputer(engine: try PredictiveEngine(language: language))
        let apostrophe = SmartQuotes.apostrophe
        let measured: [(text: String, typed: String)] = [
            ("", "´"), ("e", "é"), ("a", "à"), ("i", "î"), ("o", "ô"), ("u", "û"), ("y", "y’"), ("c", "c’"),
            ("n", "n’"), ("l", "l’"), ("d", "d’"), ("j", "j’"), ("m", "m’"), ("qu", "qu’"), ("s", "s’"),
            ("t", "t’"), ("b", "b’"), ("r", "r’"), ("et", "et’"), ("et e", "et é"), ("et a", "et à"),
            ("et l", "et l’"), ("cafe", "café"), ("aujourd", "aujourd’"), ("pere", "peré"), ("ou", "où"),
            ("du", "dû"), ("1", "1´"), (".", ".´"), ("E", "É"), ("A", "À"), ("L", "L’"),
        ]
        for (text, typed) in measured {
            let mark = try XCTUnwrap(computer.accentKeyMark(after: text), text)
            let result = mark == apostrophe
                ? text + mark
                : accentKey.edit(placing: mark, after: text).map { String(text.dropLast($0.deleteCount)) + $0.insertText }
                    ?? text + mark
            XCTAssertEqual(result, typed, text)
        }
    }

    func testAWordAfterTheKeyboardsApostropheIsLookedUpAsTheDictionaryWritesIt() throws {
        // The keyboard types the curly apostrophe inside words; the dictionary writes the straight one.
        let computer = PredictionComputer(engine: try PredictiveEngine(language: .french))
        for elided in ["d'ou", "jusqu'ou"] {
            let typed = elided.replacingOccurrences(of: "'", with: SmartQuotes.apostrophe)
            let mark = try XCTUnwrap(computer.accentKeyMark(after: elided), elided)
            XCTAssertNotEqual(accentKey.edit(placing: mark, after: elided), accentKey.edit(placing: accentKey.mark(after: elided), after: elided), elided)
            XCTAssertEqual(computer.accentKeyMark(after: typed), mark, typed)
        }
    }

    func testALanguageWithoutAnAccentKeyHasNone() throws {
        XCTAssertNil(TypingLanguage.english.accentKey)
        XCTAssertNil(PredictionComputer(engine: try PredictiveEngine(language: .english)).accentKeyMark(after: "ou"))
    }
}
