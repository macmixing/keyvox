import Foundation
import KeyVoxEmoji

/// The bundled emoji search in the typing language, read off the main thread the first time the
/// search opens in that language and kept while the keyboard types in it, finding first for a word
/// what the suggestion bar offers for it (`KeyboardEmojiPredictionsIndex`); a change of language
/// lets it go before the new language's is read, so only one language's is ever held. Use from the
/// main thread.
final class KeyboardEmojiSearchIndex {
    static let shared = KeyboardEmojiSearchIndex()

    private var search: EmojiSearch?
    /// The language `search` is in, once read.
    private var loadedLanguage: String?
    /// The language the keyboard last asked for.
    private var language: String?
    /// The language being read, while one is.
    private var loadingLanguage: String?
    private var waiting: [() -> Void] = []

    /// Calls `completion` on the main thread once the search and the bar's emoji of `language`, a
    /// typing language's identifier, are read, at once when they already are.
    func load(language: String, _ completion: @escaping () -> Void) {
        // Asked for at once, so the search finds nothing in the language it held while the bar's
        // emoji of the new one are still being read.
        self.language = language
        KeyboardEmojiPredictionsIndex.shared.load(language: language) { [self] in
            loadSearch(language: language, completion)
        }
    }

    private func loadSearch(language: String, _ completion: @escaping () -> Void) {
        // A later request replaced this one while the bar's emoji were read; that one finishes it.
        guard language == self.language else { return }
        if loadedLanguage == language {
            completion()
            return
        }
        waiting.append(completion)
        loadRequestedLanguage()
    }

    private func loadRequestedLanguage() {
        guard loadingLanguage == nil, let language, language != loadedLanguage else { return }
        loadingLanguage = language
        search = nil
        loadedLanguage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let search = try? EmojiSearch.bundled(language: language)
            DispatchQueue.main.async { [self] in
                loadingLanguage = nil
                self.search = search
                loadedLanguage = language
                guard language == self.language else {
                    loadRequestedLanguage()
                    return
                }
                let waiting = self.waiting
                self.waiting = []
                waiting.forEach { $0() }
            }
        }
    }

    /// The emoji `text` finds, in order, the bar's emoji for it first, once the language last asked
    /// for is read; none before.
    func results(for text: String) -> [String] {
        guard loadedLanguage == language else { return [] }
        return search?.results(for: text, first: KeyboardEmojiPredictionsIndex.shared.wordEmoji(for: text)) ?? []
    }
}
