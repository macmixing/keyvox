/// How a typing language's text is read where languages write it differently: which mark joins
/// the parts of a word beside the straight and curly apostrophes, whether a period right after a
/// digit ends a sentence, and which marks open a sentence before its first word.
public struct TypingTextRules: Sendable, Equatable {
    /// The mark the apostrophe key types after a letter (the language's closing single quotation
    /// mark), which belongs inside a word as an apostrophe does.
    public let apostrophe: Character
    /// Whether a period right after a digit writes an ordinal number rather than ending the
    /// sentence. A run of periods, as an ellipsis is typed, still pauses rather than ends.
    public let ordinalPeriods: Bool
    /// The marks that open a sentence before its first word, such as Spanish "¿": typed where a
    /// sentence starts, the sentence still starts after them, and typed inside a sentence, it goes
    /// on.
    public let sentenceOpeningMarks: Set<Character>

    /// The rules of English, which the bundled English data was built with.
    public static let standard = TypingTextRules(apostrophe: "’", ordinalPeriods: false)

    public init(apostrophe: Character, ordinalPeriods: Bool, sentenceOpeningMarks: Set<Character> = []) {
        self.apostrophe = apostrophe
        self.ordinalPeriods = ordinalPeriods
        self.sentenceOpeningMarks = sentenceOpeningMarks
    }

    /// Whether `character` belongs inside a word: a letter or an apostrophe.
    public func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’" || character == apostrophe
    }

    /// `word` with its apostrophes written straight, as the dictionary and the word lists write them.
    public func straightApostrophes(in word: String) -> String {
        String(word.map { $0 == "’" || $0 == apostrophe ? "'" : $0 })
    }

    /// `word` with the language's apostrophe written as the typographic one, the apostrophe the
    /// learned words are kept with beside the straight one (`PersonalVocabulary.key`).
    public func typographicApostrophes(in word: String) -> String {
        String(word.map { $0 == apostrophe ? Character(SmartQuotes.apostrophe) : $0 })
    }
}
