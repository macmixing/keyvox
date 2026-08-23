enum TextCompositionCharacterClassifier {
    static func isClauseIntroductionBoundary(_ character: Character) -> Bool {
        character == ":"
    }

    static func isHyphenSeparator(_ character: Character) -> Bool {
        character == "-"
    }

    static func isEmoji(_ character: Character) -> Bool {
        let scalars = Array(character.unicodeScalars)
        guard let baseScalar = scalars.first else { return false }
        if baseScalar.properties.isEmojiPresentation {
            return true
        }

        return baseScalar.properties.isEmoji
            && scalars.dropFirst().first?.value == 0xFE0F
    }
}
