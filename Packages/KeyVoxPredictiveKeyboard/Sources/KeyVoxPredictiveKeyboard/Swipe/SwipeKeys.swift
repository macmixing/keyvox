import Foundation

/// Where a swipe model's letters lie on the letter layout the keyboard shows: each letter on the
/// layout's key for it or, where the layout has none, on the key of the letter it is written with
/// accents on, so a language whose default layout gives an accented letter a key of its own
/// swipes the same words on its other layouts, the accented letter over its base letter's key.
///
/// The model scores the layout's keys, each once; a letter on another letter's key takes that
/// key's score, and a key path that moves between two letters on one key stays on that key.
struct SwipeKeys: Sendable {
    /// The layout's keys the model's letters lie on, each once, in the order of the model letters
    /// first on them.
    let letters: [Character]
    /// Each model letter's key, an index into `letters`, in the model's letter order.
    let keyOfLetter: [Int]
    /// Each model letter's key, by letter.
    let keyIndex: [Unicode.Scalar: Int]

    /// Nil when the layout has no key for one of `modelLetters`, either its own or its base
    /// letter's.
    init?(modelLetters: String, layout: LetterKeyLayout) {
        let layoutLetters = Set(layout.defaultGeometry.map { Character($0.character.lowercased()) })
        var letters: [Character] = []
        var keyOfLetter: [Int] = []
        var keyIndex: [Unicode.Scalar: Int] = [:]
        for scalar in modelLetters.unicodeScalars {
            guard let key = Self.key(of: Character(scalar), among: layoutLetters) else { return nil }
            let index = letters.firstIndex(of: key) ?? {
                letters.append(key)
                return letters.count - 1
            }()
            keyOfLetter.append(index)
            keyIndex[scalar] = index
        }
        self.letters = letters
        self.keyOfLetter = keyOfLetter
        self.keyIndex = keyIndex
    }

    /// Whether every model letter has a key of its own.
    var isOneKeyPerLetter: Bool {
        letters.count == keyOfLetter.count
    }

    /// The key `letter` is swiped on: its own, or else its base letter's.
    private static func key(of letter: Character, among layoutLetters: Set<Character>) -> Character? {
        if layoutLetters.contains(letter) { return letter }
        let base = SwipeLetterForm.form(of: String(letter))
        guard base.count == 1, let key = base.first, layoutLetters.contains(key) else { return nil }
        return key
    }
}
