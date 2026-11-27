import Foundation

/// A prediction computer's swipe state: the language's swipe decoder, loaded the first time a
/// swipe needs it, and the lexicon of the user's own words, rebuilt when they change. Safe to
/// use from any thread.
final class SwipeDecoding: @unchecked Sendable {
    private let lock = NSLock()
    private var decoder: SwipeWordDecoder?
    private var personal: (words: [String], lexicon: SwipeLexicon?)?

    /// The decoder for `language`, loaded once.
    func decoder(for language: TypingLanguage) throws -> SwipeWordDecoder {
        lock.lock()
        defer { lock.unlock() }
        if let decoder { return decoder }
        let loaded = try SwipeWordDecoder(language: language)
        decoder = loaded
        return loaded
    }

    /// The lexicon of `words` for `decoder`, nil when none can be swiped; rebuilt only when the
    /// words change.
    func personalLexicon(_ words: [String], decoder: SwipeWordDecoder) throws -> SwipeLexicon? {
        lock.lock()
        defer { lock.unlock() }
        if let personal, personal.words == words { return personal.lexicon }
        let lexicon = words.isEmpty ? nil : try decoder.personalLexicon(words)
        personal = (words, lexicon)
        return lexicon
    }
}
