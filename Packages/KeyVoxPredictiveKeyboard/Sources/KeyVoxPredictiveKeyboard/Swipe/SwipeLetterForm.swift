import Foundation

/// What a swipe can spell of a written word, and the keys a swipe of it passes over, as the
/// swipe model was trained to read them.
///
/// A swipe draws letters only, so a word's swipe form drops everything that is not a letter
/// (apostrophes, hyphens, punctuation), folds case, and folds accents onto their base letter,
/// except on a letter the model has a key of its own for, which keeps its accents, and a letter
/// the model spells with other keys' letters, which is written so (`Letters`). A word's key path
/// is its form's letters on the model's keys, with a letter repeated right after itself counted
/// once unless the model keeps doubled letters.
public enum SwipeLetterForm {
    /// How a swipe model reads letters beyond the plain ones.
    public struct Letters: Sendable, Equatable {
        /// The letters the model has keys of their own for, which keep their accents.
        public let keys: Set<Unicode.Scalar>
        /// Letters with no key that a swipe spells with other letters, each with those letters.
        public let spellings: [Unicode.Scalar: String]

        public init(keys: Set<Unicode.Scalar>, spellings: [Unicode.Scalar: String] = [:]) {
            self.keys = keys
            self.spellings = spellings
        }

        /// Every accent folded, and no letter spelled otherwise.
        public static let plain = Letters(keys: [])
    }

    /// `word`'s form with every accent folded.
    public static func form(of word: String) -> String {
        form(of: word, letters: .plain)
    }

    public static func form(of word: String, letters: Letters) -> String {
        let folded = word.folding(options: .caseInsensitive, locale: nil)
            .precomposedStringWithCanonicalMapping
        var form = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if letters.keys.contains(scalar) || (scalar.isASCII && isLetter(scalar)) {
                form.append(scalar)
                continue
            }
            if let spelling = letters.spellings[scalar] {
                form.append(contentsOf: spelling.unicodeScalars)
                continue
            }
            for letter in String(scalar).decomposedStringWithCanonicalMapping.unicodeScalars where isLetter(letter) {
                form.append(letter)
            }
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
