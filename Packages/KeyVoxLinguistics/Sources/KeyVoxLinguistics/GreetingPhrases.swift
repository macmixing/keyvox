import Foundation

/// Spoken greetings, farewells, and thanks, such as `hey`, `goodbye`, and `thank you`: the
/// phrases Wiktionary lists as English greetings, farewells, or expressions of gratitude that
/// Tatoeba's English sentences say right before a comma and a person's name, and that WordNet
/// 3.0, Wiktionary's phrasebook, or Apple's lexicon also marks as a greeting, farewell, thanks,
/// or interjection. A name spoken after a phrase that opens with one of these addresses a person.
public struct GreetingPhrases: Sendable {
    public enum Failure: Error { case missingResource }

    private static let resourceName = "greeting_phrases"
    private static let resourceExtension = "txt"

    /// Each listed phrase as its lowercase words.
    private let phrases: [[String]]

    /// The list bundled with this package, found through `KeyVoxLinguisticsResources`.
    public init() throws {
        guard let url = KeyVoxLinguisticsResources.bundle.url(
            forResource: Self.resourceName,
            withExtension: Self.resourceExtension
        ) else {
            throw Failure.missingResource
        }
        try self.init(contentsOf: url)
    }

    public init(contentsOf url: URL) throws {
        let contents = try String(contentsOf: url, encoding: .utf8)
        phrases = contents
            .split(whereSeparator: \.isNewline)
            .map { Self.words(in: $0) }
            .filter { !$0.isEmpty }
    }

    /// Whether `text` begins with a listed phrase.
    public func startsWithPhrase<S: StringProtocol>(_ text: S) -> Bool {
        let textWords = Self.words(in: text)
        return phrases.contains { textWords.starts(with: $0) }
    }

    /// The lowercase words of `text`, keeping the apostrophes and hyphens inside them and
    /// writing a typographic apostrophe plainly.
    private static func words<S: StringProtocol>(in text: S) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .split { !($0.isLetter || $0.isNumber || $0 == "'" || $0 == "-") }
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "'-")) }
            .filter { !$0.isEmpty }
    }
}
