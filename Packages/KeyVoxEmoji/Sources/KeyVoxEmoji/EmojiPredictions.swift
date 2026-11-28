import Foundation

/// The emoji the suggestion bar offers for a word, at most three, in the order to show them, as
/// `Tools/KeyVoxEmojiData/write_emoji_predictions.py` writes them from the emoji search's data;
/// `EmojiSearch` finds them first for that word, so the bar and the search agree. Each typing
/// language has its own.
public struct EmojiPredictions: Sendable {
    private let emojiByWord: [String: [String]]

    /// The bundled emoji for the words of the typing language `language`, a language identifier
    /// such as the keyboard's typing languages have; a regional variant without its own takes its
    /// language's. Throws `EmojiDataError.missingData` for a language the package has none for.
    public static func bundled(language: String) throws -> EmojiPredictions {
        try EmojiPredictions(contentsOf: EmojiDataLocator().url(
            name: "emoji_predictions", extension: "txt", language: language))
    }

    /// Reads data of one line per word: the word and its emoji separated by spaces, split by a tab.
    public init(contentsOf url: URL) throws {
        var emojiByWord: [String: [String]] = [:]
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() where line.isEmpty == false {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2, fields[0].isEmpty == false, fields[1].isEmpty == false else {
                throw EmojiDataError.invalidPredictions(line: index + 1)
            }
            emojiByWord[String(fields[0])] = fields[1].split(separator: " ").map(String.init)
        }
        guard emojiByWord.isEmpty == false else {
            throw EmojiDataError.invalidPredictions(line: lines.count)
        }
        self.emojiByWord = emojiByWord
    }

    /// The emoji for `word`, compared without case or accents, as the search compares words; none
    /// for a word without any, or for text that is not one word.
    public func emoji(for word: String) -> [String] {
        let words = EmojiSearch.words(in: word)
        guard words.count == 1, let word = words.first else { return [] }
        return emojiByWord[word] ?? []
    }
}
