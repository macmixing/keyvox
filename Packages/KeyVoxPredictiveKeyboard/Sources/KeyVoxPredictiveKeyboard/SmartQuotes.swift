/// The marks the apostrophe key and the quote key type, as the system keyboard types them with
/// smart quotes on, as in Messages: an opening mark where a quotation can begin (at the start
/// of the text, or after a space, a line break, an opening bracket, a dash, or another opening
/// quote mark), and a closing mark everywhere else, such as inside or after a word, a number,
/// or closing punctuation, and right after its own opening mark, which it closes. Which marks
/// those are is the typing language's.
public struct SmartQuotes: Sendable {
    /// What the apostrophe key shows and types as its key value.
    public static let apostrophe = "’"
    /// What the quote key types as its key value.
    static let doubleQuote = "\""

    /// The marks the apostrophe key types.
    let single: (opening: String, closing: String)
    /// The marks the quote key types.
    let double: (opening: String, closing: String)

    init(marks: TypingLanguageManifest.QuotationMarks) {
        single = (marks.openingSingle, marks.closingSingle)
        double = (marks.openingDouble, marks.closingDouble)
    }

    /// The text a key typing `value` inserts after `textBeforeCursor`.
    public func text(for value: String, after textBeforeCursor: String?) -> String {
        let marks: (opening: String, closing: String)
        switch value {
        case Self.apostrophe:
            marks = single
        case Self.doubleQuote:
            marks = double
        default:
            return value
        }
        guard let previous = textBeforeCursor?.last else { return marks.opening }
        return Self.opensQuotation(after: previous, opening: marks.opening) ? marks.opening : marks.closing
    }

    private static func opensQuotation(after character: Character, opening: String) -> Bool {
        guard String(character) != opening else { return false }
        guard character.isWhitespace == false, let scalar = character.unicodeScalars.first else { return true }
        switch scalar.properties.generalCategory {
        case .openPunctuation, .dashPunctuation, .initialPunctuation:
            return true
        default:
            return false
        }
    }
}
