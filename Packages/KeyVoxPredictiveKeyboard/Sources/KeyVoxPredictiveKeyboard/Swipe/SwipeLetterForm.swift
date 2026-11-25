import Foundation

/// What a swipe can spell of a written word, and the keys a swipe of it passes over, as the
/// swipe model was trained to read them.
///
/// A swipe draws letters only, so a word's swipe form drops everything that is not a letter
/// (apostrophes, hyphens, punctuation), folds case, and folds accents onto their base letter.
/// A word's key path is its form's letters on the model's keys, with a letter repeated right
/// after itself counted once unless the model keeps doubled letters.
public enum SwipeLetterForm {
    public static func form(of word: String) -> String {
        let folded = word.folding(options: .caseInsensitive, locale: nil)
            .decomposedStringWithCanonicalMapping
        var form = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars where isLetter(scalar) {
            form.append(scalar)
        }
        return String(form)
    }

    /// The model keys a swipe of `form` passes, or nil when one of its letters has no key.
    static func keyPath(
        of form: String,
        keyIndex: [Unicode.Scalar: Int],
        keepsDoubleLetters: Bool
    ) -> [Int]? {
        var path: [Int] = []
        for scalar in form.unicodeScalars {
            guard let key = keyIndex[scalar] else { return nil }
            if keepsDoubleLetters || path.last != key {
                path.append(key)
            }
        }
        return path
    }

    /// For each key of `form`'s key path with doubled letters counted once, whether `form` doubles
    /// that key's letter there; nil when one of its letters has no key.
    static func doubledKeys(of form: String, keyIndex: [Unicode.Scalar: Int]) -> [Bool]? {
        var path: [Int] = []
        var doubled: [Bool] = []
        for scalar in form.unicodeScalars {
            guard let key = keyIndex[scalar] else { return nil }
            if path.last == key {
                doubled[doubled.count - 1] = true
            } else {
                path.append(key)
                doubled.append(false)
            }
        }
        return doubled
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            return true
        default:
            return false
        }
    }
}
