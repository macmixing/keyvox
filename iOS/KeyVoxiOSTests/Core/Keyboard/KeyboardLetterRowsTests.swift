import CoreGraphics
import KeyVoxPredictiveKeyboard
import Testing
@testable import KeyVox_iOS

/// The letter page draws each of a language's letter layouts with its letters where the engine
/// aims touches at them, and fills each row edge to edge.
struct KeyboardLetterRowsTests {
    @Test func everyLayoutTheLanguageOffersDrawsItsLettersWhereTheEngineAims() throws {
        let language = KeyboardTypingLanguage.current
        let layouts = try [language.letterLayout]
            + language.alternativeLetterLayouts.map { try LetterKeyLayout.bundled(identifier: $0) }
        for layout in layouts {
            let letterRows = KeyboardLetterRows(layout: layout)
            #expect(letterRows.rows.count == layout.rows.count, "\(layout.identifier)")
            var drawn: [Character: CGPoint] = [:]
            for (rowIndex, row) in letterRows.rows.enumerated() {
                var x = row.leadingInset
                for (key, extraSpacing) in zip(row.keys, row.extraSpacing) {
                    if case let .character(text) = key.kind, let character = text.first, character.isLetter {
                        drawn[character] = CGPoint(x: x * 100, y: CGFloat(rowIndex) * 100)
                    }
                    x += key.widthUnits + extraSpacing
                }
                #expect(abs(x + row.trailingInset - letterRows.width) < 0.000_001, "\(layout.identifier) row \(rowIndex)")
            }
            let aimed = Dictionary(uniqueKeysWithValues: layout.defaultGeometry.map { ($0.character, $0.frame.origin) })
            #expect(drawn.count == aimed.count, "\(layout.identifier)")
            for (character, origin) in aimed {
                let drawnOrigin = try #require(drawn[character], "\(layout.identifier) \(character)")
                #expect(abs(drawnOrigin.x - origin.x) < 0.000_1, "\(layout.identifier) \(character)")
                #expect(drawnOrigin.y == origin.y, "\(layout.identifier) \(character)")
            }
        }
    }
}
