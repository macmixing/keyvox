/// The capitals the keyboard's shift state gives a swiped word, as it would give the letters of
/// a typed one.
public enum SwipeWordCase: Sendable, Equatable {
    /// Shift off: the word as it is spelled.
    case asSpelled
    /// Shift on for one letter, as at the start of a sentence: a capital first letter.
    case capitalized
    /// Caps lock: all capitals.
    case allCapitals

    /// `spelling` as a word typed in this case would read.
    func typed(_ spelling: String) -> String {
        switch self {
        case .asSpelled: spelling
        case .capitalized: WordCasing.startingSentence(spelling)
        case .allCapitals: spelling.uppercased()
        }
    }
}
