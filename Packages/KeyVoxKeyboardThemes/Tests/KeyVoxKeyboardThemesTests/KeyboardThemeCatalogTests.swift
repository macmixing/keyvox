import XCTest
@testable import KeyVoxKeyboardThemes

/// Each theme has its own palette on every platform, every palette's key opacity is visible
/// without hiding the backdrop entirely, and every swipe trail can be drawn: it has a width,
/// tapers rather than grows, its glow is at least as wide as its stroke, and it fades.
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

    func testEverySwipeTrailCanBeDrawn() {
        for platform in KeyboardThemePlatform.allCases {
            for theme in KeyboardThemeID.allCases {
                let trail = KeyboardThemeCatalog.palette(for: theme, on: platform).swipeTrail
                XCTAssertGreaterThan(trail.width, 0, "\(platform) \(theme)")
                XCTAssertGreaterThan(trail.tailWidthScale, 0, "\(platform) \(theme)")
                XCTAssertLessThanOrEqual(trail.tailWidthScale, 1, "\(platform) \(theme)")
                XCTAssertGreaterThanOrEqual(trail.glowWidthScale, 1, "\(platform) \(theme)")
                XCTAssertGreaterThan(trail.fadeDuration, 0, "\(platform) \(theme)")
                XCTAssertGreaterThan(trail.liftFadeDuration, 0, "\(platform) \(theme)")
            }
        }
    }
}
