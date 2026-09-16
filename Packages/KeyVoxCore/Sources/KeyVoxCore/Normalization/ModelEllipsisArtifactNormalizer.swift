import Foundation

struct ModelEllipsisArtifactNormalizer {
    private static let artifactRegex = try? NSRegularExpression(
        pattern: #"\.{3,}(?:[ \t]+\.)?"#
    )

    func removeArtifacts(from text: String) -> String {
        guard let regex = Self.artifactRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let previousCharacter = range.lowerBound > text.startIndex
                ? text[text.index(before: range.lowerBound)]
                : nil
            let nextCharacter = range.upperBound < text.endIndex
                ? text[range.upperBound]
                : nil
            let replacement = needsWordSeparator(
                between: previousCharacter,
                and: nextCharacter
            ) ? " " : ""

            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    private func needsWordSeparator(
        between previousCharacter: Character?,
        and nextCharacter: Character?
    ) -> Bool {
        guard let previousCharacter, let nextCharacter else { return false }
        return (previousCharacter.isLetter || previousCharacter.isNumber)
            && (nextCharacter.isLetter || nextCharacter.isNumber)
    }
}
