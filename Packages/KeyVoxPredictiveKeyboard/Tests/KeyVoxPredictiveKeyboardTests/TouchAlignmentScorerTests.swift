import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A letter with a key of its own on the layout is aimed at that key; any other letter at the key
/// of its letter without accents.
final class TouchAlignmentScorerTests: XCTestCase {
    func testALetterWithItsOwnKeyIsAimedAtThatKey() throws {
        let layout = TypingLanguage.spanish.letterLayout
        let keys = KeyCenterMap(geometry: layout.defaultGeometry)
        let scorer = TouchAlignmentScorer(keys: keys, parameters: NoisyChannelCorrector.standardParameters.touch)
        let ownKeys = layout.defaultGeometry.map(\.character).filter { letter in
            String(letter).folding(options: .diacriticInsensitive, locale: nil) != String(letter)
        }
        XCTAssertFalse(ownKeys.isEmpty)
        for letter in ownKeys {
            let folded = Character(String(letter).folding(options: .diacriticInsensitive, locale: nil))
            let touch = try XCTUnwrap(keys.center(of: letter))
            XCTAssertLessThan(
                scorer.cost(of: [touch], typing: String(letter)),
                scorer.cost(of: [touch], typing: String(folded)),
                "\(letter)"
            )
        }
    }

    func testALetterWithoutAKeyIsAimedAtItsPlainLettersKey() throws {
        let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        let scorer = TouchAlignmentScorer(keys: keys, parameters: NoisyChannelCorrector.standardParameters.touch)
        let accented = TypingLanguage.spanish.letterLayout.defaultGeometry.map(\.character).filter { letter in
            keys.center(of: letter) == nil
        }
        XCTAssertFalse(accented.isEmpty)
        for letter in accented {
            let folded = Character(String(letter).folding(options: .diacriticInsensitive, locale: nil))
            let touch = try XCTUnwrap(keys.center(of: folded))
            XCTAssertEqual(scorer.cost(of: [touch], typing: String(letter)), scorer.cost(of: [touch], typing: String(folded)), "\(letter)")
        }
    }
}
