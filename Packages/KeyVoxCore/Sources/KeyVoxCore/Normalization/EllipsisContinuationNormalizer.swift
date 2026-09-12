import Foundation

struct EllipsisContinuationNormalizer {
    private static let continuationRegex = try? NSRegularExpression(
        pattern: #"(?:\.{3,}|…+)[\"'”’\)\]\}]*[ \t]*[\"'“”‘’\(\[\{]*([\p{L}][\p{L}\p{M}\p{N}_'’-]*)"#
    )

    func normalize(in text: String, dictionaryEntries: [DictionaryEntry]) -> String {
        guard let regex = Self.continuationRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)

        for match in matches.reversed() {
            let tokenRange = match.range(at: 1)
            let token = nsText.substring(with: tokenRange)
            guard token.first?.isUppercase == true,
                  !shouldPreserveCasing(
                      of: token,
                      at: tokenRange,
                      in: text,
                      dictionaryEntries: dictionaryEntries
                  ),
                  let firstScalar = token.unicodeScalars.first else {
                continue
            }

            mutable.replaceCharacters(
                in: NSRange(location: tokenRange.location, length: String(firstScalar).utf16.count),
                with: String(firstScalar).lowercased()
            )
        }

        return mutable as String
    }

    private func shouldPreserveCasing(
        of token: String,
        at tokenRange: NSRange,
        in text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        token == "I"
            || token.unicodeScalars.dropFirst().contains { $0.properties.isUppercase }
            || isDottedAcronym(startingAt: tokenRange, in: text)
            || beginsDictionaryEntry(at: tokenRange, in: text, dictionaryEntries: dictionaryEntries)
    }

    private func isDottedAcronym(startingAt tokenRange: NSRange, in text: String) -> Bool {
        guard let tokenStringRange = Range(tokenRange, in: text) else { return false }
        return text[tokenStringRange.lowerBound...].range(
            of: #"^(?:\p{Lu}\.){2,}"#,
            options: .regularExpression
        ) != nil
    }

    private func beginsDictionaryEntry(
        at tokenRange: NSRange,
        in text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        guard let tokenStringRange = Range(tokenRange, in: text) else { return false }
        let suffix = text[tokenStringRange.lowerBound...]

        for entry in dictionaryEntries {
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty,
                  let match = suffix.range(
                      of: phrase,
                      options: [.anchored, .caseInsensitive, .diacriticInsensitive]
                  ) else {
                continue
            }

            guard match.upperBound < suffix.endIndex else { return true }
            let nextCharacter = suffix[match.upperBound]
            if !nextCharacter.isLetter, !nextCharacter.isNumber, nextCharacter != "_" {
                return true
            }
        }

        return false
    }
}
