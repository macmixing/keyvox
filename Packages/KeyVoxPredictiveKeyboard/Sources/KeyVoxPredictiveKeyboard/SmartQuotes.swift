/// The marks the apostrophe key and the quote key type, as the system keyboard types them with
/// smart quotes on, as in Messages: an opening mark where a quotation can begin (at the start
/// of the text, or after a space, a line break, an opening bracket, a dash, or another opening
/// quote mark), and a closing mark everywhere else, such as inside or after a word, a number,
/// or closing punctuation, and right after its own opening mark, which it closes. The closing
/// single mark is the apostrophe.
public enum SmartQuotes {
    /// What the apostrophe key shows and, after a word, types.
    public static let apostrophe = "’"
    static let openingQuote = "‘"
    static let doubleQuote = "\""
    static let openingDoubleQuote = "“"
    static let closingDoubleQuote = "”"

    /// The text a key typing `value` inserts after `textBeforeCursor`.
    public static func text(for value: String, after textBeforeCursor: String?) -> String {
        let marks: (opening: String, closing: String)
        switch value {
        case apostrophe:
            marks = (openingQuote, apostrophe)
        case doubleQuote:
            marks = (openingDoubleQuote, closingDoubleQuote)
        default:
            return value
        }
        guard let previous = textBeforeCursor?.last else { return marks.opening }
        return opensQuotation(after: previous, opening: marks.opening) ? marks.opening : marks.closing
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
