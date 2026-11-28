/// Whether a word is a dictionary word written without its apostrophe, as "dont" is.
enum MissingApostrophe {
    /// Whether putting one apostrophe between two of `key`'s letters, a lookup key without one,
    /// makes a word `isWord` knows.
    static func isMissing(from key: String, isWord: (String) throws -> Bool) rethrows -> Bool {
        let letters = Array(key)
        guard letters.count > 1, letters.contains("'") == false else { return false }
        for index in 1..<letters.count {
            if try isWord(String(letters[..<index]) + "'" + String(letters[index...])) {
                return true
            }
        }
        return false
    }
}
