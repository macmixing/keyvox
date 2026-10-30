import Foundation
import KeyVoxEmoji

/// The bundled emoji the suggestion bar offers for a word, read once off the main thread the first
/// time a field that predicts opens and kept while the keyboard runs. Use from the main thread.
final class KeyboardEmojiPredictionsIndex {
    static let shared = KeyboardEmojiPredictionsIndex()

    private var predictions: EmojiPredictions?
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

    /// The emoji for `word` this phone draws, in order, once read: what the bar offers and what
    /// the emoji search finds first for that word.
    func wordEmoji(for word: String) -> [String] {
        (predictions?.emoji(for: word) ?? []).filter(KeyboardEmojiSupport.canDraw)
    }
}
