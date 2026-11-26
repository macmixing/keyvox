import CoreGraphics
import KeyVoxPredictiveKeyboard
import Testing
@testable import KeyVox_iOS

/// The letter page draws each of a language's letter layouts with its letters where the engine
/// aims touches at them, fills each row edge to edge, and draws shift and delete at the layout's
/// widths, across the padding beside them only where the layout says they fill it.
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
            for (layoutRow, row) in zip(layout.rows, letterRows.rows) {
                let sideKeys = row.keys.filter { $0.kind == .shift || $0.kind == .delete }.map(\.widthUnits)
                let expected = layoutRow.items.indices.compactMap { index -> CGFloat? in
                    switch layoutRow.items[index] {
                    case let .shift(width), let .delete(width):
                        guard layout.shiftAndDeleteFillPadding else { return CGFloat(width) }
                        let neighbors = [index - 1, index + 1].filter(layoutRow.items.indices.contains)
                        let padding = neighbors.reduce(0.0) { total, neighbor in
                            guard case let .padding(width) = layoutRow.items[neighbor] else { return total }
                            return total + width
                        }
                        return CGFloat(width + padding)
                    case .character, .padding:
                        return nil
                    }
                }
                #expect(sideKeys.count == expected.count, "\(layout.identifier)")
                for (drawn, apple) in zip(sideKeys, expected) {
                    #expect(abs(drawn - apple) < 0.000_001, "\(layout.identifier)")
                }
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
