import Foundation

/// Words the bundled dictionary's word list spells only one way, with capitals, such as
/// names ("Jennifer") and brands ("iPhone"), built by `Tools/KeyVoxLanguageModel`. A word it
/// also spells in lowercase among its common words ("will", "bob"), as capitals in a row
/// ("NASA"), or that people mostly write in lowercase ("grey") is not here, so it is left as
/// written.
public struct CapitalizedSpellings: Sendable {
    public enum Failure: Error { case missingResource }

    private static let newline = UInt8(ascii: "\n")
    private static let tab = UInt8(ascii: "\t")
    private static let resourceName = "capitalized_spellings"
    private static let resourceExtension = "txt"

    /// Lines of a lowercase word, a tab, and its spelling, in byte order of the lowercase
    /// word, mapped rather than read so they take no memory of their own.
    private let list: Data

    /// The list bundled with this package.
    public init() throws {
        guard let url = Bundle.module.url(
            forResource: Self.resourceName,
            withExtension: Self.resourceExtension
        ) else {
            throw Failure.missingResource
        }
        try self.init(contentsOf: url)
    }

    public init(contentsOf url: URL) throws {
        list = try Data(contentsOf: url, options: .alwaysMapped)
    }

    /// The spelling of `word`, in any case, if it is spelled only with capitals.
    public func spelling(of word: String) -> String? {
        let key = Array(Self.key(word).utf8)
        return list.withUnsafeBytes { bytes -> String? in
            var low = 0
            var high = bytes.count
            while low < high {
                let middle = (low + high) / 2
                var start = middle
                while start > 0, bytes[start - 1] != Self.newline { start -= 1 }
                var end = middle
                while end < bytes.count, bytes[end] != Self.newline { end += 1 }
                let line = bytes[start..<end]
                let separator = line.firstIndex(of: Self.tab) ?? end
                let lineKey = bytes[start..<separator]
                if lineKey.elementsEqual(key) {
                    return String(decoding: bytes[min(separator + 1, end)..<end], as: UTF8.self)
                }
                if lineKey.lexicographicallyPrecedes(key) {
                    low = end + 1
                } else {
                    high = start
                }
            }
            return nil
        }
    }

    /// `word` spelled with its capitals when it is written in lowercase and spelled only with
    /// capitals; otherwise `word` as it is.
    public func written(_ word: String) -> String {
        guard word == word.lowercased(), let spelling = spelling(of: word) else { return word }
        return spelling
    }

    /// The list's lookup form of `word`: lowercase, with a typographic apostrophe written plainly.
    private static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'")
    }
}
