import Foundation
import KeyVoxEmoji

/// The bundled emoji the suggestion bar offers for a word, read once off the main thread the first
/// time a field that predicts opens and kept while the keyboard runs. The bar offers them only once
/// the user typed an emoji since the keyboard started, as the system keyboard was seen doing
/// (Tools/AppleKeyboardBaseline): not before, not for only opening the emoji page, and not again
/// after the keyboard restarts until an emoji is typed. Use from the main thread.
final class KeyboardEmojiPredictionsIndex {
    static let shared = KeyboardEmojiPredictionsIndex()

    private var predictions: EmojiPredictions?
    private var hasTypedEmoji = false
    private var waiting: [() -> Void] = []
    private var isLoading = false

    /// Calls `completion` on the main thread once the predictions are read, at once when they
    /// already are.
    func load(_ completion: @escaping () -> Void) {
        if predictions != nil {
            completion()
            return
        }
        waiting.append(completion)
        guard isLoading == false else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let predictions = try? EmojiPredictions.bundled()
            DispatchQueue.main.async { [self] in
                self.predictions = predictions
                isLoading = false
                let waiting = self.waiting
                self.waiting = []
                waiting.forEach { $0() }
            }
        }
    }

    /// The user typed an emoji, so the bar offers emoji from now on.
    func recordTypedEmoji() {
        hasTypedEmoji = true
    }

    /// The emoji for `word` this phone draws, in order, once read and once the user typed an emoji;
    /// none before.
    func emoji(for word: String) -> [String] {
        guard hasTypedEmoji else { return [] }
        return wordEmoji(for: word)
    }

    /// The emoji for `word` this phone draws, in order, once read, whether or not the bar offers
    /// them yet: what the emoji search finds first for that word.
    func wordEmoji(for word: String) -> [String] {
        (predictions?.emoji(for: word) ?? []).filter(KeyboardEmojiSupport.canDraw)
    }
}
