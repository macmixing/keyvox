public enum TrailingSeparatorCompositionPolicy {
    public static func applyIfNeeded(
        to text: String,
        followingCharacter: Character?
    ) -> String {
        guard let followingCharacter,
              followingCharacter.isLetter
                || followingCharacter.isNumber
                || TextCompositionCharacterClassifier.isEmoji(followingCharacter),
              let incomingLastCharacter = text.last,
              incomingLastCharacter.isWhitespace == false else {
            return text
        }

        return text + " "
    }
}
