import XCTest
@testable import KeyVoxKeyboardThemes

/// Each theme has its own palette on every platform, and every palette's key opacity is visible
/// without hiding the backdrop entirely.
final class KeyboardThemeCatalogTests: XCTestCase {
    func testEveryThemeHasItsOwnPaletteOnEveryPlatform() {
        for platform in KeyboardThemePlatform.allCases {
            let palettes = KeyboardThemeID.allCases.map { KeyboardThemeCatalog.palette(for: $0, on: platform) }
            for (index, palette) in palettes.enumerated() {
                for other in palettes[(index + 1)...] {
                    XCTAssertNotEqual(palette, other, "\(platform)")
                }
            }
        }
    }

    func testEveryPaletteKeyOpacityIsBetweenInvisibleAndSolid() {
        for platform in KeyboardThemePlatform.allCases {
            for theme in KeyboardThemeID.allCases {
                let opacity = KeyboardThemeCatalog.palette(for: theme, on: platform).keyFillOpacity
                for value in [opacity.light, opacity.dark] {
                    XCTAssertGreaterThan(value, 0, "\(platform) \(theme)")
                    XCTAssertLessThanOrEqual(value, 1, "\(platform) \(theme)")
                }
            }
        }
    }
}
