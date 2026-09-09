public enum DictionaryLeadingCapitalizationPolicy {
    public static func shouldPreserve(
        text: String,
        dictionaryPhrases: some Sequence<String>
    ) -> Bool {
        dictionaryPhrases.contains { phrase in
            guard phrase.isEmpty == false, text.hasPrefix(phrase) else { return false }
            let boundary = text.index(text.startIndex, offsetBy: phrase.count)
            guard boundary < text.endIndex else { return true }
            let nextCharacter = text[boundary]
            return nextCharacter.isWhitespace || nextCharacter.isPunctuation
        }
    }
}
