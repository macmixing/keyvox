import XCTest
@testable import KeyVoxEmoji

/// The keyboard's sections keep only the emoji the system draws.
final class EmojiKeyboardSectionsTests: XCTestCase {
    func testEverythingDrawableKeepsTheCatalog() throws {
        let catalog = try EmojiCatalog.bundled()
        XCTAssertEqual(catalog.keyboardSections(isDrawable: { _ in true }), catalog.sections)
    }

    func testEmojiTheSystemCannotDrawAreLeftOut() throws {
        let catalog = try EmojiCatalog.bundled()
        let first = catalog.sections[0].emoji[0]
        let withVariants = try XCTUnwrap(catalog.sections.flatMap(\.emoji).first { $0.skinToneVariants.isEmpty == false })
        let undrawable: Set<String> = [first.text, withVariants.skinToneVariants[0]]

        let emoji = catalog.keyboardSections(isDrawable: { undrawable.contains($0) == false }).flatMap(\.emoji)

        XCTAssertFalse(emoji.contains { $0.text == first.text })
        let kept = try XCTUnwrap(emoji.first { $0.text == withVariants.text })
        XCTAssertEqual(kept.skinToneVariants, Array(withVariants.skinToneVariants.dropFirst()))
    }
}
