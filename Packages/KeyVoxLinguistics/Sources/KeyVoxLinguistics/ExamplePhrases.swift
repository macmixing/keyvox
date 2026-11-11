import Foundation

/// Phrases that introduce examples, such as `for example` and `such as`: English Wiktionary's
/// `for example` entry and the synonyms it lists for its "as an example" sense. What a speaker
/// says right after one of these phrases is the example it introduces.
public struct ExamplePhrases: Sendable {
    public enum Failure: Error { case missingResource }

    private static let resourceName = "example_phrases"
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

    /// Whether `text` ends with a listed phrase.
    public func endsWithPhrase<S: StringProtocol>(_ text: S) -> Bool {
        let textWords = Self.words(in: text)
        return phrases.contains { textWords.reversed().starts(with: $0.reversed()) }
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
