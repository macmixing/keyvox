import Foundation

/// A typing language's `language.json`: the rules its keyboard follows that differ from one
/// language to another. Its identifier and letter layouts are read by `TypingLanguageLetterLayouts`.
struct TypingLanguageManifest: Decodable {
    struct QuotationMarks: Decodable {
        let openingSingle: String
        let closingSingle: String
        let openingDouble: String
        let closingDouble: String
        /// The space the quote key types inside its marks, after the opening mark and before the
        /// closing one; none when absent.
        let spaceInsideDouble: String?

        /// The opening double mark and the space the quote key types inside it, when it types one.
        var spacedOpeningMark: TypingTextRules.SpacedMark? {
            guard let space = spaceInsideDouble, space.count == 1, openingDouble.count == 1 else { return nil }
            return TypingTextRules.SpacedMark(mark: Character(openingDouble), space: Character(space))
        }
    }

    /// The key beside the letters that puts accents on them and types the apostrophe
    /// (`AccentKey`).
    struct AccentKey: Decodable {
        /// The character the letter layouts draw on the key.
        let character: String
        /// Each mark the key or its popup puts on letters, with its Unicode combining mark.
        let combiningMarks: [String: String]
        /// The marks the key itself shows, in the order a tie between them is settled.
        let keyMarks: [String]
        /// The mark the key shows after each lowercase letter when no mark makes a known word.
        let usualMarks: [String: String]
    }

    /// The letters single-letter edits of a typed word try, in the order they are tried.
    let editLetters: String
    /// The letters a short typed word needs one of to be taken as an attempt at a word.
    let vowels: String
    /// Words always written as listed, alone or before an apostrophe.
    let alwaysCapitalizedWords: [String]
    let quotationMarks: QuotationMarks
    /// The language's accent key, when its letter layouts have one it drives.
    let accentKey: AccentKey?
    /// The folder in `PredictiveData` whose dictionary, models, and swipe files a regional variant
    /// uses where its own folder has none; nil for a language that has all its own.
    let sharedDataFolder: String?
    /// Whether a period right after a digit writes an ordinal number rather than ending the
    /// sentence (`TypingTextRules.ordinalPeriods`); false when left out.
    let ordinalPeriods: Bool?
    /// The locale of Apple's keyboard for the language, whose web endings its keyboard adds to the
    /// region's (`WebEndings`).
    let webEndingsLocale: String
    /// The mark the keyboard writes for the apostrophe of a word it writes, such as a corrected
    /// contraction; the dictionary's straight apostrophe when left out.
    let writtenApostrophe: String?
}
