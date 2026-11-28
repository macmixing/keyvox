import Foundation
import KeyVoxEmoji

/// The bundled emoji the suggestion bar offers for a word in the typing language, read off the main
/// thread the first time a field that predicts opens in that language and kept while the keyboard
/// types in it; a change of language lets them go before the new language's are read, so only one
/// language's are ever held. Use from the main thread.
final class KeyboardEmojiPredictionsIndex {
    static let shared = KeyboardEmojiPredictionsIndex()

    private var predictions: EmojiPredictions?
    /// The language `predictions` are of, once read.
    private var loadedLanguage: String?
    /// The language the keyboard last asked for.
    private var language: String?
    /// The language being read, while one is.
    private var loadingLanguage: String?
    private var waiting: [() -> Void] = []

    /// Calls `completion` on the main thread once the predictions of `language`, a typing language's
    /// identifier, are read, at once when they already are.
    func load(language: String, _ completion: @escaping () -> Void) {
        self.language = language
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
        predictions = nil
        loadedLanguage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let predictions = try? EmojiPredictions.bundled(language: language)
            DispatchQueue.main.async { [self] in
                loadingLanguage = nil
                self.predictions = predictions
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

    /// The emoji for `word` this phone draws, in order, once the language last asked for is read:
    /// what the bar offers and what the emoji search finds first for that word.
    func wordEmoji(for word: String) -> [String] {
        guard loadedLanguage == language else { return [] }
        return (predictions?.emoji(for: word) ?? []).filter(KeyboardEmojiSupport.canDraw)
    }
}
