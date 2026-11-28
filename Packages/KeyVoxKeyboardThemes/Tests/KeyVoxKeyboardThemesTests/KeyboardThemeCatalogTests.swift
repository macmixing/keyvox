import XCTest
@testable import KeyVoxKeyboardThemes

/// Each theme has its own palette on every platform, every palette's key opacity is visible
/// without hiding the backdrop entirely, and every swipe trail can be drawn: it has a width,
/// tapers rather than grows, its glow layers widen outward from the stroke while fading, its
/// tail and lift last, and its head blooms outward. The Classic theme's light trail is drawn in
/// the microphone's own color.
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
                let context = "\(platform) \(theme)"
                XCTAssertGreaterThan(min(trail.width.light, trail.width.dark), 0, context)
                XCTAssertGreaterThan(trail.tailWidthScale, 0, context)
                XCTAssertLessThanOrEqual(trail.tailWidthScale, 1, context)
                XCTAssertFalse(trail.glows.isEmpty, context)
                for (inner, outer) in zip(trail.glows, trail.glows.dropFirst()) {
                    XCTAssertGreaterThan(outer.widthScale, inner.widthScale, context)
                    XCTAssertLessThanOrEqual(outer.opacity.light, inner.opacity.light, context)
                    XCTAssertLessThanOrEqual(outer.opacity.dark, inner.opacity.dark, context)
                }
                XCTAssertGreaterThanOrEqual(trail.glows[0].widthScale, 1, context)
                XCTAssertGreaterThan(trail.tailDuration, 0, context)
                XCTAssertGreaterThan(trail.opacityFalloffExponent, 0, context)
                XCTAssertGreaterThanOrEqual(trail.headScale, 1, context)
                XCTAssertGreaterThan(trail.liftDuration, 0, context)
                XCTAssertGreaterThanOrEqual(trail.bandOverlap, 0, context)
                XCTAssertEqual(trail.liftTiming.count, 4, context)
                XCTAssertGreaterThanOrEqual(trail.bloomScale, 1, context)
                XCTAssertGreaterThan(trail.bloomDuration, 0, context)
                XCTAssertGreaterThan(trail.bloomFadeDuration, 0, context)
            }
        }
    }

    func testClassicLightSwipeTrailIsTheMicrophoneColor() {
        for platform in KeyboardThemePlatform.allCases {
            let palette = KeyboardThemeCatalog.palette(for: .classic, on: platform)
            let microphone = palette.microphoneForeground.light
            XCTAssertEqual(palette.swipeTrail.color.light, microphone, "\(platform)")
            XCTAssertEqual(palette.swipeTrail.headColor.light, microphone, "\(platform)")
            XCTAssertEqual(palette.swipeTrail.glowColor.light, microphone, "\(platform)")
        }
    }
}
