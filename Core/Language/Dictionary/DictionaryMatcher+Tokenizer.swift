import Foundation

extension DictionaryMatcher {
    func tokenize(_ text: String) -> [Token] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        guard let regex = try? NSRegularExpression(pattern: "\\b[\\p{L}\\p{N}']+\\b") else {
            return []
        }

        return regex
            .matches(in: text, options: [], range: fullRange)
            .compactMap { match in
                let raw = nsText.substring(with: match.range)
                let normalized = DictionaryTextNormalization.normalizedToken(raw)
                guard !normalized.isEmpty else { return nil }

                return Token(
                    raw: raw,
                    normalized: normalized,
                    range: match.range,
                    phonetic: encoder.scoringSignature(for: normalized, lexicon: lexicon)
                )
            }
    }

    func combinedRange(from tokens: [Token]) -> NSRange {
        guard let first = tokens.first, let last = tokens.last else {
            return NSRange(location: 0, length: 0)
        }

        let start = first.range.location
        let end = last.range.location + last.range.length
        return NSRange(location: start, length: end - start)
    }
}
