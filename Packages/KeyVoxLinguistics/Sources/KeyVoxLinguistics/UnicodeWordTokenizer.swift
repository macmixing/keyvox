import Foundation

/// Foundation's ICU Unicode word boundaries retain coordinates in the source.
/// Punctuation remains available as model context, without being exposed as words.
enum UnicodeWordTokenizer {
    struct Token {
        let text: String
        let range: NSRange
        let isWord: Bool
    }

    private static let boundaries = try? NSRegularExpression(pattern: #"\b"#, options: .useUnicodeWordBoundaries)

    static func tokens(in text: String) -> [Token] {
        guard let boundaries else { return [] }
        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let offsets = Set([0, source.length] + boundaries.matches(in: text, range: fullRange).map(\.range.location)).sorted()
        return zip(offsets, offsets.dropFirst()).compactMap { start, end in
            let range = NSRange(location: start, length: end - start)
            let value = source.substring(with: range)
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let isWord = value.rangeOfCharacter(from: .letters.union(.decimalDigits)) != nil
            return Token(text: value, range: range, isWord: isWord)
        }
    }
}
