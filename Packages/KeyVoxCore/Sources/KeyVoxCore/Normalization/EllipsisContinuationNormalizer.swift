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

        let stylizedEntries = Set(
            dictionaryEntries
                .map(\.phrase)
                .filter(isStylizedSingleToken)
        )
        let mutable = NSMutableString(string: text)

        for match in matches.reversed() {
            let tokenRange = match.range(at: 1)
            let token = nsText.substring(with: tokenRange)
            guard token.first?.isUppercase == true,
                  token != "I",
                  !stylizedEntries.contains(token),
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

    private func isStylizedSingleToken(_ phrase: String) -> Bool {
        guard !phrase.contains(where: \.isWhitespace) else { return false }
        let scalars = Array(phrase.unicodeScalars)
        guard scalars.count > 1 else { return false }
        return scalars.dropFirst().contains { $0.properties.isUppercase }
    }
}
