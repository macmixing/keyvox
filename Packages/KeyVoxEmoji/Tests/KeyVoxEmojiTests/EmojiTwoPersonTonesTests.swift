import XCTest
@testable import KeyVoxEmoji

/// A two-person emoji's versions by each person's tone, read from the skin-tone modifiers each
/// version carries rather than from where it sits in the list.
final class EmojiTwoPersonTonesTests: XCTestCase {
    func testEveryCatalogTwoPersonEmojiHasAVersionForEveryPairOfTones() throws {
        let twoPerson = try EmojiCatalog.bundled().sections.flatMap(\.emoji).filter { $0.skinToneVariants.count == 25 }
        XCTAssertFalse(twoPerson.isEmpty)
        for emoji in twoPerson {
            let tones = try XCTUnwrap(EmojiTwoPersonTones(emoji), emoji.name)
            for first in 0..<EmojiTwoPersonTones.toneCount {
                for second in 0..<EmojiTwoPersonTones.toneCount {
                    let version = try XCTUnwrap(tones.version(first: first, second: second), emoji.name)
                    XCTAssertEqual(tones.tones(of: version)?.first, first, emoji.name)
                    XCTAssertEqual(tones.tones(of: version)?.second, second, emoji.name)
                }
            }
        }
    }

    func testTheSameToneIsTheOneToneVersionAndDifferentTonesCarryBoth() throws {
        let handshake = try XCTUnwrap(try EmojiCatalog.bundled().sections.flatMap(\.emoji).first { $0.text == "🤝" })
        let tones = try XCTUnwrap(EmojiTwoPersonTones(handshake))
        XCTAssertEqual(tones.version(first: 1, second: 1), "🤝🏼")
        XCTAssertEqual(tones.version(first: 2, second: 4), "🫱🏽‍🫲🏿")
    }

    func testAOnePersonEmojiHasNoTwoPersonTones() {
        XCTAssertNil(EmojiTwoPersonTones(Emoji(text: "👍", name: "thumbs up", skinToneVariants: ["👍🏻", "👍🏼", "👍🏽", "👍🏾", "👍🏿"])))
    }
}
