import Foundation

/// A typing language's `language.json`: the rules its keyboard follows that differ from one
/// language to another.
struct TypingLanguageManifest: Decodable {
    struct LetterRow: Decodable {
        /// The row's letter keys, left to right.
        let letters: String
        /// How far the row's first key sits from the left edge, in key widths.
        let offset: Double
    }

    struct QuotationMarks: Decodable {
        let openingSingle: String
        let closingSingle: String
        let openingDouble: String
        let closingDouble: String
    }

    let identifier: String
    let letterRows: [LetterRow]
    /// The letters single-letter edits of a typed word try, in the order they are tried.
    let editLetters: String
    /// The letters a short typed word needs one of to be taken as an attempt at a word.
    let vowels: String
    /// Words always written as listed, alone or before an apostrophe.
    let alwaysCapitalizedWords: [String]
    let quotationMarks: QuotationMarks
}
