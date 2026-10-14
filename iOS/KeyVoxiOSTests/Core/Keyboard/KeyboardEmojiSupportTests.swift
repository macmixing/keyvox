import KeyVoxEmoji
import Testing
@testable import KeyVox_iOS

/// The system's emoji font draws emoji it knows as one picture and nothing else.
struct KeyboardEmojiSupportTests {
    @Test func drawsTheCatalogsFirstEmoji() throws {
        let first = try #require(try EmojiCatalog.bundled().sections.first?.emoji.first)
        #expect(KeyboardEmojiSupport.canDraw(first.text))
    }

    @Test func doesNotDrawEmojiJoinedIntoNoKnownEmoji() throws {
        let emoji = try EmojiCatalog.bundled().sections[0].emoji
        #expect(KeyboardEmojiSupport.canDraw(emoji[0].text + "\u{200D}" + emoji[1].text) == false)
    }

    @Test func doesNotDrawText() {
        #expect(KeyboardEmojiSupport.canDraw("a") == false)
    }
}
