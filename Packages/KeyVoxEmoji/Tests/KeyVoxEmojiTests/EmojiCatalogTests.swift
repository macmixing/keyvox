import Foundation
import XCTest
@testable import KeyVoxEmoji

/// The bundled catalog holds every category in the system keyboard's order, each emoji once, and
/// skin-tone versions only under the emoji they vary.
final class EmojiCatalogTests: XCTestCase {
    func testBundledCatalogHasEveryCategoryInTheKeyboardsOrder() throws {
        let catalog = try EmojiCatalog.bundled()
        XCTAssertEqual(catalog.sections.map(\.category), EmojiKeyboardCategory.allCases.filter { $0 != .frequentlyUsed })
        for section in catalog.sections {
            XCTAssertFalse(section.emoji.isEmpty, "\(section.category) is empty")
        }
    }

    func testEveryEmojiAppearsOnceWithItsName() throws {
        let emoji = try EmojiCatalog.bundled().sections.flatMap(\.emoji)
        let texts = emoji.flatMap { [$0.text] + $0.skinToneVariants }
        XCTAssertEqual(Set(texts).count, texts.count)
        XCTAssertTrue(emoji.allSatisfy { $0.name.isEmpty == false })
    }

    func testOnlySkinToneVersionsCarryASkinTone() throws {
        for emoji in try EmojiCatalog.bundled().sections.flatMap(\.emoji) {
            XCTAssertFalse(Self.hasSkinTone(emoji.text), emoji.name)
            XCTAssertTrue([0, 5, 25].contains(emoji.skinToneVariants.count), emoji.name)
            XCTAssertTrue(emoji.skinToneVariants.allSatisfy(Self.hasSkinTone), emoji.name)
        }
    }

    func testCatalogWithAnUnknownCategoryIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try "@not-a-category\n".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try EmojiCatalog(contentsOf: url)) { error in
            XCTAssertEqual(error as? EmojiDataError, .invalidCatalog(line: 1))
        }
    }

    private static func hasSkinTone(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.isEmojiModifier }
    }
}
