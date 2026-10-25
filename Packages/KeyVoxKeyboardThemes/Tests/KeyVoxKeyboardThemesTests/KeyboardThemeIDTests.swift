import XCTest
@testable import KeyVoxKeyboardThemes

/// A saved theme comes back as itself, and anything missing or unknown falls back to the default.
final class KeyboardThemeIDTests: XCTestCase {
    func testEverySavedThemeResolvesToItself() {
        for theme in KeyboardThemeID.allCases {
            XCTAssertEqual(KeyboardThemeID.resolved(rawValue: theme.rawValue), theme)
        }
    }

    func testMissingOrUnknownThemeResolvesToDefault() {
        XCTAssertEqual(KeyboardThemeID.resolved(rawValue: nil), .default)
        XCTAssertEqual(KeyboardThemeID.resolved(rawValue: ""), .default)
        XCTAssertEqual(KeyboardThemeID.resolved(rawValue: UUID().uuidString), .default)
    }
}
