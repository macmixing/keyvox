import Foundation

/// A typing language's `language.json`: the rules its keyboard follows that differ from one
/// language to another. Its identifier and letter layouts are read by `TypingLanguageLetterLayouts`.
struct TypingLanguageManifest: Decodable {
    struct QuotationMarks: Decodable {
        let openingSingle: String
        let closingSingle: String
        let openingDouble: String
        let closingDouble: String
    }

    /// The letters single-letter edits of a typed word try, in the order they are tried.
    let editLetters: String
    /// The letters a short typed word needs one of to be taken as an attempt at a word.
    let vowels: String
    /// Words always written as listed, alone or before an apostrophe.
    let alwaysCapitalizedWords: [String]
    let quotationMarks: QuotationMarks
    /// The marks that open a sentence before its first word: typed where a sentence starts, the
    /// sentence still starts after them (`TypingTextRules.sentenceOpeningMarks`). None when absent.
    let sentenceOpeningMarks: String?
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
