import XCTest
@testable import KeyVoxKeyboardThemes

/// Each theme has its own palette, and every palette's key opacity is visible without hiding the
/// backdrop entirely.
final class KeyboardThemeCatalogTests: XCTestCase {
    func testEveryThemeHasItsOwnPalette() {
        let palettes = KeyboardThemeID.allCases.map(KeyboardThemeCatalog.palette(for:))
        for (index, palette) in palettes.enumerated() {
            for other in palettes[(index + 1)...] {
                XCTAssertNotEqual(palette, other)
            }
        }
    }

    func testEveryPaletteKeyOpacityIsBetweenInvisibleAndSolid() {
        for theme in KeyboardThemeID.allCases {
            let opacity = KeyboardThemeCatalog.palette(for: theme).keyFillOpacity
            for value in [opacity.light, opacity.dark] {
                XCTAssertGreaterThan(value, 0, "\(theme)")
                XCTAssertLessThanOrEqual(value, 1, "\(theme)")
            }
        }
    }
}
