import Foundation

struct CharacterSpamNormalizer {
    private static let repeatedCharacterSpamRegex = try? NSRegularExpression(
        pattern: #"([^\s])\1{15,}"#,
        options: []
    )

    func normalize(in text: String) -> String {
        guard let regex = Self.repeatedCharacterSpamRegex, !text.isEmpty else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let repeatedCharacterRange = match.range(at: 1)
            guard repeatedCharacterRange.location != NSNotFound else { continue }
            let repeatedCharacter = nsText.substring(with: repeatedCharacterRange)
            mutable.replaceCharacters(in: match.range, with: repeatedCharacter)
        }

        return mutable as String
    }
}
