/// Carries the typed word's capitalization over to a suggested replacement.
public enum WordCasing {
    public static func apply(of typedWord: String, to suggestion: String) -> String {
        let letters = typedWord.filter(\.isLetter)
        guard letters.isEmpty == false else { return suggestion }
        if letters.count > 1, letters == letters.uppercased(), letters != letters.lowercased() {
            return suggestion.uppercased()
        }
        guard letters.first?.isUppercase == true, let first = suggestion.first else {
            return suggestion
        }
        return first.uppercased() + suggestion.dropFirst()
    }
}
