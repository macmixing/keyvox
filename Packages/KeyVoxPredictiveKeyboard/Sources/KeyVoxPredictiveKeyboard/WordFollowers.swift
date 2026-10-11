import Foundation

/// The words that most often follow each common word, which the next-word bar draws on while the
/// user picks its words in a row: the bundled dictionary keeps only a few next words per word, so
/// always picking from the bar otherwise runs out of new words. The list is written by
/// Tools/KeyVoxLanguageModel/write_word_followers.py, which documents the file's lines.
public struct WordFollowers: Sendable {
    private let table: FollowerTable

    public init(contentsOf url: URL) throws {
        table = try FollowerTable(contentsOf: url)
    }

    /// The words that most often follow `word`, likeliest first.
    public func words(after word: String) -> [String] {
        table.followers(of: PersonalVocabulary.key(word)).map(\.word)
    }
}
