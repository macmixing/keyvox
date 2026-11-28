import KeyVoxEmoji
import Testing
@testable import KeyVox_iOS

/// The suggestion bar's emoji follow the typing language: the index offers the emoji of the
/// language asked for last, once read, and none of the language before.
@MainActor
struct KeyboardEmojiPredictionsIndexTests {
    @Test func offersTheEmojiOfTheLanguageAskedForLast() async throws {
        let words = try Self.words()
        let languages = ["en", "de"]
        let expected = try languages.map { language in
            let predictions = try EmojiPredictions.bundled(language: language)
            return words.map { predictions.emoji(for: $0).filter(KeyboardEmojiSupport.canDraw) }
        }
        // The languages' emoji differ for these words, so following the wrong one would show.
        #expect(expected[0] != expected[1])

        let index = KeyboardEmojiPredictionsIndex()
        for (language, emoji) in zip(languages + languages, expected + expected) {
            await Self.load(index, language: language)
            #expect(words.map(index.wordEmoji(for:)) == emoji, "\(language)")
        }
    }

    @Test func offersNoneUntilTheLanguageAskedForIsRead() async {
        let index = KeyboardEmojiPredictionsIndex()
        await Self.load(index, language: "en")
        index.load(language: "de") {}
        #expect((try? Self.words().allSatisfy { index.wordEmoji(for: $0).isEmpty }) == true)
    }

    /// The words of the first catalog emoji's names.
    private static func words() throws -> [String] {
        let emoji = try EmojiCatalog.bundled().sections.flatMap(\.emoji).prefix(200)
        return Array(Set(emoji.flatMap { $0.name.split(separator: " ").map(String.init) })).sorted()
    }

    private static func load(_ index: KeyboardEmojiPredictionsIndex, language: String) async {
        await withCheckedContinuation { continuation in
            index.load(language: language) { continuation.resume() }
        }
    }
}
