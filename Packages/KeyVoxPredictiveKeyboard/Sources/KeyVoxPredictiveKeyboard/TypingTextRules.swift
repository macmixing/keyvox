/// How a typing language's text is read where languages write it differently: which mark joins
/// the parts of a word beside the straight and curly apostrophes, and whether a period right
/// after a digit ends a sentence.
public struct TypingTextRules: Sendable, Equatable {
    /// The mark the apostrophe key types after a letter (the language's closing single quotation
    /// mark), which belongs inside a word as an apostrophe does.
    public let apostrophe: Character
    /// Whether a period right after a digit writes an ordinal number rather than ending the
    /// sentence. A run of periods, as an ellipsis is typed, still pauses rather than ends.
    public let ordinalPeriods: Bool
    /// The opening double mark and the space the quote key types inside it, where the language's
    /// quote key types one (`SmartQuotes`): only together with that space does the mark keep a
    /// sentence start; typed without it, as from a held key's popup, the mark ends it.
    public let spacedOpeningMark: SpacedMark?

    /// A quotation mark and the space typed with it.
    public struct SpacedMark: Sendable, Equatable {
        public let mark: Character
        public let space: Character

        public init(mark: Character, space: Character) {
            self.mark = mark
            self.space = space
        }
    }

    /// The rules of English, which the bundled English data was built with.
    public static let standard = TypingTextRules(apostrophe: "’", ordinalPeriods: false)

    public init(apostrophe: Character, ordinalPeriods: Bool, spacedOpeningMark: SpacedMark? = nil) {
        self.apostrophe = apostrophe
        self.ordinalPeriods = ordinalPeriods
        self.spacedOpeningMark = spacedOpeningMark
    }

    /// Whether `character` belongs inside a word: a letter or an apostrophe.
    public func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’" || character == apostrophe
    }

    /// `word` with its apostrophes written straight, as the dictionary and the word lists write them.
    public func straightApostrophes(in word: String) -> String {
        String(word.map { $0 == "’" || $0 == apostrophe ? "'" : $0 })
    }
}
