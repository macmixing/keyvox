import Foundation

/// Which of what the keyboard learned from the user's typing a reset in Keyboard settings forgets.
enum KeyboardTypingMemoryResetScope: Hashable {
    /// Every language's, as the only reset while the keyboard types in one language.
    case keyboard
    /// Every language's, picked among the keyboard's languages.
    case allLanguages
    /// One language's, by identifier.
    case language(String)
}
